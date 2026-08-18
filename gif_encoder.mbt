///|
fn disposal_bits(disposal : Disposal) -> Int {
  match disposal {
    Keep => 1
    Background => 2
    Previous => 3
  }
}

///|
fn min_lzw_code_size(bits : Int) -> Int {
  if bits < 2 {
    2
  } else {
    bits
  }
}

///|
fn validate_frame(animation : Animation, frame : Frame) -> Unit raise GifError {
  let canvas = frame.canvas
  let (left, top) = frame.offset()
  if canvas.width <= 0 ||
    canvas.height <= 0 ||
    left < 0 ||
    top < 0 ||
    left + canvas.width > animation.width ||
    top + canvas.height > animation.height {
    raise InvalidDimensions
  }
}

///|
fn write_graphic_control_extension(
  writer : GifWriter,
  frame : Frame,
  palette : Palette,
) -> Unit {
  let transparent_index = palette.transparent_index()
  let transparent_bit = match transparent_index {
    None => 0
    Some(_) => 1
  }
  let packed = (disposal_bits(frame.disposal) << 2) | transparent_bit
  writer.bytes([0x21, 0xf9, 0x04])
  writer.byte(packed)
  writer.u16(frame.delay_cs)
  let transparent_byte = match transparent_index {
    None => 0
    Some(index) => index
  }
  writer.byte(transparent_byte)
  writer.byte(0)
}

///|
fn write_image(
  writer : GifWriter,
  frame : Frame,
  quantized : QuantizedFrame,
  local_table : Bool,
) -> Unit raise GifError {
  let palette = quantized.palette()
  let (table_size, table_bits) = palette_table_size(palette)
  let (left, top) = frame.offset()
  let canvas = frame.canvas
  let packed = if local_table { 0x80 | (table_bits - 1) } else { 0 }
  writer.byte(0x2c)
  writer.u16(left)
  writer.u16(top)
  writer.u16(canvas.width)
  writer.u16(canvas.height)
  writer.byte(packed)
  if local_table {
    write_palette(writer, palette, table_size)
  }
  let payload = lzw_encode(quantized.indices(), min_lzw_code_size(table_bits))
  writer.byte(min_lzw_code_size(table_bits))
  write_sub_blocks(writer, payload)
}

///|
/// Encode an animation as a standards-compliant GIF89a byte sequence.
///
/// Each frame receives a local palette except the first frame, whose palette
/// becomes the logical screen's global table. This keeps frame-local colors
/// independent while retaining a valid global screen descriptor.
pub fn encode_with_options(
  animation : Animation,
  options : EncodeOptions,
) -> Bytes raise GifError {
  if animation.width <= 0 ||
    animation.height <= 0 ||
    animation.width > 65535 ||
    animation.height > 65535 ||
    animation.frames.length() == 0 {
    raise InvalidDimensions
  }
  let quantized : Array[QuantizedFrame] = []
  for frame in animation.frames {
    validate_frame(animation, frame)
    match frame.transparent {
      None =>
        quantized.push(quantize(frame.canvas, max_colors=options.max_colors))
      Some(color) =>
        quantized.push(
          quantize(
            frame.canvas,
            max_colors=options.max_colors,
            transparent=color,
          ),
        )
    }
  }
  let first_palette = quantized[0].palette()
  let (global_size, global_bits) = palette_table_size(first_palette)
  let writer = GifWriter::new()
  writer.bytes([b'G', b'I', b'F', b'8', b'9', b'a'])
  writer.u16(animation.width)
  writer.u16(animation.height)
  writer.byte(0x80 | (7 << 4) | (global_bits - 1))
  writer.byte(0)
  writer.byte(0)
  write_palette(writer, first_palette, global_size)
  if options.emit_loop_extension {
    match animation.loop_count {
      None => ()
      Some(loop_count) => {
        writer.bytes([0x21, 0xff, 0x0b])
        writer.bytes([
          b'N', b'E', b'T', b'S', b'C', b'A', b'P', b'E', b'2', b'.', b'0',
        ])
        writer.byte(3)
        writer.byte(1)
        writer.u16(
          if loop_count < 0 {
            0
          } else if loop_count > 65535 {
            65535
          } else {
            loop_count
          },
        )
        writer.byte(0)
      }
    }
  }
  for i, frame in animation.frames {
    let frame_palette = quantized[i].palette()
    let frame_for_encoding = if frame.delay_cs == 0 &&
      options.default_delay_cs > 0 {
      frame.with_delay(delay_cs=options.default_delay_cs)
    } else {
      frame
    }
    write_graphic_control_extension(writer, frame_for_encoding, frame_palette)
    write_image(writer, frame_for_encoding, quantized[i], i != 0)
  }
  writer.byte(0x3b)
  writer.finish()
}

///|
/// Encode with the standard 256-color palette budget and loop metadata.
pub fn encode(animation : Animation) -> Bytes raise GifError {
  encode_with_options(animation, EncodeOptions::default())
}
