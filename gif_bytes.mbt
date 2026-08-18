///|
priv struct GifWriter {
  bytes : Array[Byte]
}

///|
fn GifWriter::new() -> GifWriter {
  { bytes: [] }
}

///|
fn GifWriter::byte(self : GifWriter, value : Int) -> Unit {
  self.bytes.push(value.to_byte())
}

///|
fn GifWriter::u16(self : GifWriter, value : Int) -> Unit {
  self.byte(value & 0xff)
  self.byte((value >> 8) & 0xff)
}

///|
fn GifWriter::bytes(self : GifWriter, values : ArrayView[Byte]) -> Unit {
  for value in values {
    self.bytes.push(value)
  }
}

///|
fn GifWriter::finish(self : GifWriter) -> Bytes {
  Bytes::from_array(self.bytes[:])
}

///|
priv struct GifCursor {
  data : Bytes
  mut position : Int
}

///|
fn GifCursor::new(data : Bytes) -> GifCursor {
  { data, position: 0 }
}

///|
fn GifCursor::remaining(self : GifCursor) -> Int {
  self.data.length() - self.position
}

///|
fn GifCursor::byte(self : GifCursor, context~ : String) -> Byte raise GifError {
  if self.position >= self.data.length() {
    raise UnexpectedEnd(context~)
  }
  let value = self.data[self.position]
  self.position += 1
  value
}

///|
fn GifCursor::u16(self : GifCursor, context~ : String) -> Int raise GifError {
  let low = self.byte(context~).to_int()
  let high = self.byte(context~).to_int()
  low | (high << 8)
}

///|
fn GifCursor::take(
  self : GifCursor,
  length : Int,
  context~ : String,
) -> Bytes raise GifError {
  if length < 0 || self.position + length > self.data.length() {
    raise UnexpectedEnd(context~)
  }
  let result : Array[Byte] = []
  for i in 0..<length {
    result.push(self.data[self.position + i])
  }
  self.position += length
  Bytes::from_array(result[:])
}

///|
fn GifCursor::skip(
  self : GifCursor,
  length : Int,
  context~ : String,
) -> Unit raise GifError {
  if length < 0 || self.position + length > self.data.length() {
    raise UnexpectedEnd(context~)
  }
  self.position += length
}

///|
fn read_sub_blocks(
  cursor : GifCursor,
  context~ : String,
) -> Bytes raise GifError {
  let payload : Array[Byte] = []
  let mut done = false
  while !done {
    let size = cursor.byte(context~).to_int()
    if size == 0 {
      done = true
    } else {
      if size > 255 {
        raise InvalidBlock(context~)
      }
      for _ in 0..<size {
        payload.push(cursor.byte(context~))
      }
    }
  }
  Bytes::from_array(payload[:])
}

///|
fn write_sub_blocks(writer : GifWriter, payload : Bytes) -> Unit {
  let mut offset = 0
  while offset < payload.length() {
    let remaining = payload.length() - offset
    let size = if remaining > 255 { 255 } else { remaining }
    writer.byte(size)
    for i in 0..<size {
      writer.byte(payload[offset + i].to_int())
    }
    offset += size
  }
  writer.byte(0)
}

///|
fn palette_table_size(palette : Palette) -> (Int, Int) {
  let mut bits = 1
  let mut size = 2
  while size < palette.len() && bits < 8 {
    bits += 1
    size = size << 1
  }
  (size, bits)
}

///|
fn write_palette(
  writer : GifWriter,
  palette : Palette,
  table_size : Int,
) -> Unit {
  for i in 0..<table_size {
    match palette.color(i) {
      None => writer.bytes([0, 0, 0])
      Some(color) => writer.bytes([color.red(), color.green(), color.blue()])
    }
  }
}

///|
fn read_palette(
  cursor : GifCursor,
  table_size : Int,
) -> Array[Rgba] raise GifError {
  let colors : Array[Rgba] = []
  for _ in 0..<table_size {
    let r = cursor.byte(context="color table").to_int()
    let g = cursor.byte(context="color table").to_int()
    let b = cursor.byte(context="color table").to_int()
    colors.push(rgb(r.to_byte(), g.to_byte(), b.to_byte()))
  }
  colors
}

///|
fn packed_table_size(packed : Int) -> Int {
  1 << ((packed & 0x07) + 1)
}

///|
fn is_bytes(values : Bytes, expected : Array[Byte]) -> Bool {
  if values.length() != expected.length() {
    false
  } else {
    let mut same = true
    for i in 0..<expected.length() {
      if values[i] != expected[i] {
        same = false
      }
    }
    same
  }
}
