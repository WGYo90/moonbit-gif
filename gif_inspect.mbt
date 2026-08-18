///|
/// Header-level information collected without expanding image pixels.
pub(all) struct GifInfo {
  version : String
  width : Int
  height : Int
  frame_count : Int
  has_global_palette : Bool
  uses_local_palettes : Bool
  uses_transparency : Bool
  loop_count : Int?
  compressed_bytes : Int
} derive(Debug)

///|
pub fn GifInfo::version(self : GifInfo) -> String {
  self.version
}

///|
pub fn GifInfo::width(self : GifInfo) -> Int {
  self.width
}

///|
pub fn GifInfo::height(self : GifInfo) -> Int {
  self.height
}

///|
pub fn GifInfo::frame_count(self : GifInfo) -> Int {
  self.frame_count
}

///|
pub fn GifInfo::has_global_palette(self : GifInfo) -> Bool {
  self.has_global_palette
}

///|
pub fn GifInfo::uses_local_palettes(self : GifInfo) -> Bool {
  self.uses_local_palettes
}

///|
pub fn GifInfo::uses_transparency(self : GifInfo) -> Bool {
  self.uses_transparency
}

///|
pub fn GifInfo::loop_count(self : GifInfo) -> Int? {
  self.loop_count
}

///|
pub fn GifInfo::compressed_bytes(self : GifInfo) -> Int {
  self.compressed_bytes
}

///|
fn inspect_extension(
  cursor : GifCursor,
  label : Int,
  loop_count : Ref[Int?],
) -> (Bool, Bool, Int) raise GifError {
  match label {
    0xf9 => {
      let size = cursor.byte(context="graphic control extension size").to_int()
      if size != 4 {
        raise InvalidBlock(context="graphic control extension")
      }
      let packed = cursor.byte(context="graphic control extension").to_int()
      ignore(cursor.skip(2, context="graphic control extension delay"))
      ignore(cursor.byte(context="graphic control extension transparent index"))
      if cursor.byte(context="graphic control extension terminator") != 0 {
        raise InvalidBlock(context="graphic control extension terminator")
      }
      ((packed & 1) != 0, false, 0)
    }
    0xff => {
      let size = cursor
        .byte(context="application extension identifier size")
        .to_int()
      let identifier = cursor.take(
        size,
        context="application extension identifier",
      )
      let payload = read_sub_blocks(
        cursor,
        context="application extension data",
      )
      if is_bytes(identifier, [
          b'N', b'E', b'T', b'S', b'C', b'A', b'P', b'E', b'2', b'.', b'0',
        ]) &&
        payload.length() >= 3 &&
        payload[0] == 1 {
        loop_count.val = Some(payload[1].to_int() | (payload[2].to_int() << 8))
      }
      (false, false, payload.length())
    }
    0x01 | 0xfe => {
      let size = cursor.byte(context="extension block size").to_int()
      cursor.skip(size, context="extension block")
      let payload = read_sub_blocks(cursor, context="extension sub-blocks")
      (false, false, payload.length())
    }
    _ => {
      let payload = read_sub_blocks(cursor, context="extension sub-blocks")
      (false, false, payload.length())
    }
  }
}

///|
/// Inspect GIF structure while leaving compressed image data untouched.
pub fn inspect(data : Bytes) -> GifInfo raise GifError {
  if data.length() < 13 {
    raise UnexpectedEnd(context="GIF header")
  }
  let is_87a = data[3] == b'8' && data[4] == b'7' && data[5] == b'a'
  let is_89a = data[3] == b'8' && data[4] == b'9' && data[5] == b'a'
  if !(data[0] == b'G' &&
    data[1] == b'I' &&
    data[2] == b'F' &&
    (is_87a || is_89a)) {
    raise InvalidSignature
  }
  let cursor = GifCursor::new(data)
  ignore(cursor.take(6, context="GIF signature"))
  let version = if is_87a { "GIF87a" } else { "GIF89a" }
  let screen = parse_logical_screen(cursor)
  let loop_count : Ref[Int?] = Ref(None)
  let mut frame_count = 0
  let mut uses_local = false
  let mut uses_transparency = false
  let mut compressed_bytes = 0
  let mut done = false
  while !done && cursor.remaining() > 0 {
    let marker = cursor.byte(context="GIF block marker").to_int()
    match marker {
      0x3b => done = true
      0x21 => {
        let label = cursor.byte(context="extension label").to_int()
        let (transparent, _, _) = inspect_extension(cursor, label, loop_count)
        if transparent {
          uses_transparency = true
        }
      }
      0x2c => {
        ignore(cursor.u16(context="image left"))
        ignore(cursor.u16(context="image top"))
        let width = cursor.u16(context="image width")
        let height = cursor.u16(context="image height")
        if width <= 0 || height <= 0 {
          raise InvalidDimensions
        }
        let packed = cursor.byte(context="image descriptor").to_int()
        if (packed & 0x80) != 0 {
          uses_local = true
          ignore(read_palette(cursor, packed_table_size(packed)))
        } else if screen.global_palette is None {
          raise InvalidPalette(context="image has no color table")
        }
        ignore(cursor.byte(context="image LZW minimum code size"))
        let payload = read_sub_blocks(cursor, context="image data sub-blocks")
        compressed_bytes += payload.length()
        frame_count += 1
      }
      _ => raise InvalidBlock(context="unknown GIF block marker")
    }
  }
  if !done || frame_count == 0 {
    raise InvalidBlock(context="GIF has no complete image frames")
  }
  GifInfo::{
    version,
    width: screen.width,
    height: screen.height,
    frame_count,
    has_global_palette: screen.global_palette is Some(_),
    uses_local_palettes: uses_local,
    uses_transparency,
    loop_count: loop_count.val,
    compressed_bytes,
  }
}

///|
/// Return false instead of raising for callers that only need a quick probe.
pub fn is_valid(data : Bytes) -> Bool {
  try inspect(data) catch {
    _ => false
  } noraise {
    _ => false
  }
}
