///|
/// Split a payload into GIF data sub-blocks. The returned bytes include the
/// length byte for every block and the final zero terminator.
pub fn pack_sub_blocks(payload : Bytes, block_size? : Int = 255) -> Bytes {
  let safe_size = if block_size < 1 {
    1
  } else if block_size > 255 {
    255
  } else {
    block_size
  }
  let bytes : Array[Byte] = []
  let mut offset = 0
  while offset < payload.length() {
    let remaining = payload.length() - offset
    let size = if remaining > safe_size { safe_size } else { remaining }
    bytes.push(size.to_byte())
    for i in 0..<size {
      bytes.push(payload[offset + i])
    }
    offset += size
  }
  bytes.push(0)
  Bytes::from_array(bytes[:])
}

///|
/// Unpack a complete GIF sub-block sequence.
pub fn unpack_sub_blocks(data : Bytes) -> Bytes raise GifError {
  let cursor = GifCursor::new(data)
  let payload : Array[Byte] = []
  let mut terminated = false
  while cursor.remaining() > 0 && !terminated {
    let size = cursor.byte(context="sub-block size").to_int()
    if size == 0 {
      terminated = true
    } else {
      for _ in 0..<size {
        payload.push(cursor.byte(context="sub-block payload"))
      }
    }
  }
  if !terminated || cursor.remaining() != 0 {
    raise InvalidBlock(context="unterminated or trailing GIF sub-block data")
  }
  Bytes::from_array(payload[:])
}

///|
/// Encode LZW data and immediately apply GIF sub-block framing.
pub fn lzw_encode_sub_blocks(
  indices : ArrayView[Byte],
  min_code_size : Int,
) -> Bytes raise GifError {
  pack_sub_blocks(lzw_encode(indices, min_code_size))
}

///|
/// Decode a complete GIF sub-block sequence containing an LZW payload.
pub fn lzw_decode_sub_blocks(
  data : Bytes,
  min_code_size : Int,
  expected_len : Int,
) -> Array[Byte] raise GifError {
  lzw_decode(unpack_sub_blocks(data), min_code_size, expected_len)
}

///|
/// Compression metrics for an index stream.
pub(all) struct LzwStats {
  input_bytes : Int
  compressed_bytes : Int
  minimum_code_size : Int
} derive(Debug)

///|
pub fn LzwStats::input_bytes(self : LzwStats) -> Int {
  self.input_bytes
}

///|
pub fn LzwStats::compressed_bytes(self : LzwStats) -> Int {
  self.compressed_bytes
}

///|
pub fn LzwStats::minimum_code_size(self : LzwStats) -> Int {
  self.minimum_code_size
}

///|
pub fn LzwStats::saving_per_mille(self : LzwStats) -> Int {
  if self.input_bytes <= 0 {
    0
  } else {
    (self.input_bytes - self.compressed_bytes) * 1000 / self.input_bytes
  }
}

///|
pub fn analyze_lzw(
  indices : ArrayView[Byte],
  min_code_size : Int,
) -> LzwStats raise GifError {
  let compressed = lzw_encode(indices, min_code_size)
  LzwStats::{
    input_bytes: indices.length(),
    compressed_bytes: compressed.length(),
    minimum_code_size: min_code_size,
  }
}

///|
/// A conservative encoded-size estimate for a single frame.
pub(all) struct FrameEstimate {
  width : Int
  height : Int
  palette_bytes : Int
  lzw_bytes : Int
  total_bytes : Int
} derive(Debug)

///|
pub fn FrameEstimate::width(self : FrameEstimate) -> Int {
  self.width
}

///|
pub fn FrameEstimate::height(self : FrameEstimate) -> Int {
  self.height
}

///|
pub fn FrameEstimate::palette_bytes(self : FrameEstimate) -> Int {
  self.palette_bytes
}

///|
pub fn FrameEstimate::lzw_bytes(self : FrameEstimate) -> Int {
  self.lzw_bytes
}

///|
pub fn FrameEstimate::total_bytes(self : FrameEstimate) -> Int {
  self.total_bytes
}

///|
fn estimate_frame(
  frame : Frame,
  max_colors : Int,
) -> FrameEstimate raise GifError {
  let quantized = match frame.transparent {
    None => quantize(frame.canvas, max_colors~)
    Some(color) => quantize(frame.canvas, max_colors~, transparent=color)
  }
  let palette = quantized.palette()
  let (table_size, table_bits) = palette_table_size(palette)
  let min_code_size = min_lzw_code_size(table_bits)
  let compressed = lzw_encode(quantized.indices(), min_code_size)
  let total = 19 +
    table_size * 3 +
    compressed.length() +
    compressed.length() / 255 +
    1
  FrameEstimate::{
    width: frame.canvas.width,
    height: frame.canvas.height,
    palette_bytes: table_size * 3,
    lzw_bytes: compressed.length(),
    total_bytes: total,
  }
}

///|
/// Estimate frame sizes using the same quantizer and LZW encoder as `encode`.
pub fn estimate_frames(
  animation : Animation,
  max_colors? : Int = 256,
) -> Array[FrameEstimate] raise GifError {
  let estimates : Array[FrameEstimate] = []
  for frame in animation.frames {
    estimates.push(estimate_frame(frame, max_colors))
  }
  estimates
}

///|
/// Return an estimate for the whole encoded stream.
pub fn estimate_size(
  animation : Animation,
  max_colors? : Int = 256,
) -> Int raise GifError {
  let estimates = estimate_frames(animation, max_colors~)
  let mut total = 13
  for estimate in estimates {
    total += estimate.total_bytes
  }
  let loop_bytes = match animation.loop_count {
    Some(_) => 19
    None => 0
  }
  total + loop_bytes
}
