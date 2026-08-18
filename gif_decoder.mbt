///|
priv struct GceState {
  delay_cs : Int
  disposal : Disposal
  transparent_index : Int?
}

///|
fn default_gce() -> GceState {
  { delay_cs: 0, disposal: Keep, transparent_index: None }
}

///|
priv struct LogicalScreen {
  width : Int
  height : Int
  background : Rgba
  global_palette : Array[Rgba]?
}

///|
fn parse_logical_screen(cursor : GifCursor) -> LogicalScreen raise GifError {
  let width = cursor.u16(context="logical screen width")
  let height = cursor.u16(context="logical screen height")
  if width <= 0 || height <= 0 {
    raise InvalidDimensions
  }
  let packed = cursor.byte(context="logical screen descriptor").to_int()
  let background_index = cursor.byte(context="background color index").to_int()
  ignore(cursor.byte(context="pixel aspect ratio"))
  let global_palette = if (packed & 0x80) != 0 {
    Some(read_palette(cursor, packed_table_size(packed)))
  } else {
    None
  }
  let background = match global_palette {
    None => rgb(0, 0, 0)
    Some(colors) =>
      if background_index < colors.length() {
        colors[background_index]
      } else {
        rgb(0, 0, 0)
      }
  }
  LogicalScreen::{ width, height, background, global_palette }
}

///|
fn parse_gce(cursor : GifCursor) -> GceState raise GifError {
  let size = cursor.byte(context="graphic control extension size").to_int()
  if size != 4 {
    raise InvalidBlock(context="graphic control extension")
  }
  let packed = cursor.byte(context="graphic control extension").to_int()
  let delay_cs = cursor.u16(context="graphic control extension delay")
  let transparent_index = cursor
    .byte(context="graphic control extension")
    .to_int()
  let terminator = cursor.byte(context="graphic control extension terminator")
  if terminator != 0 {
    raise InvalidBlock(context="graphic control extension terminator")
  }
  let disposal = match (packed >> 2) & 0x07 {
    2 => Background
    3 => Previous
    _ => Keep
  }
  {
    delay_cs,
    disposal,
    transparent_index: if (packed & 1) != 0 {
      Some(transparent_index)
    } else {
      None
    },
  }
}

///|
fn parse_application_extension(
  cursor : GifCursor,
  loop_count : Ref[Int?],
) -> Unit raise GifError {
  let size = cursor
    .byte(context="application extension identifier size")
    .to_int()
  let identifier = cursor.take(size, context="application extension identifier")
  let payload = read_sub_blocks(cursor, context="application extension data")
  if is_bytes(identifier, [
      b'N', b'E', b'T', b'S', b'C', b'A', b'P', b'E', b'2', b'.', b'0',
    ]) &&
    payload.length() >= 3 &&
    payload[0] == 1 {
    loop_count.val = Some(payload[1].to_int() | (payload[2].to_int() << 8))
  }
}

///|
fn parse_image(
  cursor : GifCursor,
  screen : LogicalScreen,
  gce : GceState,
) -> Frame raise GifError {
  let left = cursor.u16(context="image left")
  let top = cursor.u16(context="image top")
  let width = cursor.u16(context="image width")
  let height = cursor.u16(context="image height")
  if width <= 0 ||
    height <= 0 ||
    left + width > screen.width ||
    top + height > screen.height {
    raise InvalidDimensions
  }
  let packed = cursor.byte(context="image descriptor").to_int()
  let palette = if (packed & 0x80) != 0 {
    read_palette(cursor, packed_table_size(packed))
  } else {
    match screen.global_palette {
      None =>
        raise InvalidPalette(context="image has no global or local color table")
      Some(colors) => colors
    }
  }
  let min_code_size = cursor
    .byte(context="image LZW minimum code size")
    .to_int()
  let compressed = read_sub_blocks(cursor, context="image data sub-blocks")
  let indices = lzw_decode(compressed, min_code_size, width * height)
  let canvas = Canvas::new(
    width=screen.width,
    height=screen.height,
    fill=screen.background,
  )
  let transparent_color = match gce.transparent_index {
    None => None
    Some(index) =>
      if index < palette.length() {
        let color = palette[index]
        Some(rgba(color.red(), color.green(), color.blue(), 0))
      } else {
        None
      }
  }
  for y in 0..<height {
    for x in 0..<width {
      let index = indices[x + y * width].to_int()
      let target_x = left + x
      let target_y = top + y
      if gce.transparent_index is Some(t) && index == t {
        ignore(
          canvas.set(
            x=target_x,
            y=target_y,
            color=match transparent_color {
              Some(c) => c
              None => rgba(0, 0, 0, 0)
            },
          ),
        )
      } else {
        if index >= palette.length() {
          raise InvalidPalette(context="image index is outside its color table")
        }
        ignore(canvas.set(x=target_x, y=target_y, color=palette[index]))
      }
    }
  }
  let frame = Frame::new(canvas~, delay_cs=gce.delay_cs)
    .with_disposal(disposal=gce.disposal)
    .with_offset(left=0, top=0)
  match transparent_color {
    None => frame
    Some(color) => frame.with_transparent(color~)
  }
}

///|
/// Decode a GIF87a/GIF89a stream into an animation.
pub fn decode(data : Bytes) -> Animation raise GifError {
  if data.length() < 13 {
    raise UnexpectedEnd(context="GIF header")
  }
  if !(data[0] == b'G' &&
    data[1] == b'I' &&
    data[2] == b'F' &&
    data[3] == b'8' &&
    (data[4] == b'7' || data[4] == b'9') &&
    data[5] == b'a') {
    raise InvalidSignature
  }
  let cursor = GifCursor::new(data)
  ignore(cursor.take(6, context="GIF signature"))
  let screen = parse_logical_screen(cursor)
  let loop_count : Ref[Int?] = Ref(None)
  let mut animation = Animation::new(width=screen.width, height=screen.height).with_background(
    background=screen.background,
  )
  let mut current_gce = default_gce()
  let mut done = false
  while !done && cursor.remaining() > 0 {
    let marker = cursor.byte(context="GIF block marker").to_int()
    match marker {
      0x3b => done = true
      0x21 => {
        let label = cursor.byte(context="extension label").to_int()
        match label {
          0xf9 => current_gce = parse_gce(cursor)
          0xff => parse_application_extension(cursor, loop_count)
          0x01 | 0xfe => {
            let size = cursor.byte(context="extension block size").to_int()
            cursor.skip(size, context="extension block")
            ignore(read_sub_blocks(cursor, context="extension sub-blocks"))
          }
          _ => ignore(read_sub_blocks(cursor, context="extension sub-blocks"))
        }
      }
      0x2c => {
        let frame = parse_image(cursor, screen, current_gce)
        animation = animation.add_frame(frame)
        current_gce = default_gce()
      }
      _ => raise InvalidBlock(context="unknown GIF block marker")
    }
  }
  if !done || animation.frames.length() == 0 {
    raise InvalidBlock(context="GIF has no complete image frames")
  }
  animation.with_loop_count(loop_count=loop_count.val)
}
