///|
priv struct BitWriter {
  bytes : Array[Byte]
  mut buffer : Int
  mut bit_count : Int
}

///|
fn BitWriter::new() -> BitWriter {
  { bytes: [], buffer: 0, bit_count: 0 }
}

///|
fn BitWriter::write(self : BitWriter, code : Int, width : Int) -> Unit {
  self.buffer = self.buffer | (code << self.bit_count)
  self.bit_count += width
  while self.bit_count >= 8 {
    self.bytes.push((self.buffer & 0xff).to_byte())
    self.buffer = self.buffer >> 8
    self.bit_count -= 8
  }
}

///|
fn BitWriter::finish(self : BitWriter) -> Bytes {
  if self.bit_count > 0 {
    self.bytes.push((self.buffer & 0xff).to_byte())
    self.buffer = 0
    self.bit_count = 0
  }
  Bytes::from_array(self.bytes[:])
}

///|
priv struct BitReader {
  data : Bytes
  mut position : Int
  mut buffer : Int
  mut bit_count : Int
}

///|
fn BitReader::new(data : Bytes) -> BitReader {
  { data, position: 0, buffer: 0, bit_count: 0 }
}

///|
fn BitReader::read(self : BitReader, width : Int) -> Int? {
  while self.bit_count < width && self.position < self.data.length() {
    self.buffer = self.buffer |
      (self.data[self.position].to_int() << self.bit_count)
    self.position += 1
    self.bit_count += 8
  }
  if self.bit_count < width {
    None
  } else {
    let mask = (1 << width) - 1
    let result = self.buffer & mask
    self.buffer = self.buffer >> width
    self.bit_count -= width
    Some(result)
  }
}

///|
fn valid_min_code_size(value : Int) -> Bool {
  value >= 2 && value <= 8
}

///|
fn lzw_clear_dictionary(dictionary : Map[Int, Int]) -> Unit {
  dictionary.clear()
}

///|
/// Encode palette indices into the GIF LZW bit stream.
///
/// The returned bytes are the payload before GIF sub-block framing.
pub fn lzw_encode(
  indices : ArrayView[Byte],
  min_code_size : Int,
) -> Bytes raise GifError {
  if !valid_min_code_size(min_code_size) {
    raise InvalidLzw(context="minimum code size must be between 2 and 8")
  }
  let clear_code = 1 << min_code_size
  let end_code = clear_code + 1
  let mut next_code = end_code + 1
  let mut code_width = min_code_size + 1
  let mut width_limit = 1 << code_width
  let dictionary : Map[Int, Int] = Map([])
  let writer = BitWriter::new()
  writer.write(clear_code, code_width)
  if indices.length() == 0 {
    writer.write(end_code, code_width)
    return writer.finish()
  }
  let mut prefix = indices[0].to_int()
  for i in 1..<indices.length() {
    let value = indices[i].to_int()
    let key = prefix * 256 + value
    match dictionary.get(key) {
      Some(code) => prefix = code
      None => {
        writer.write(prefix, code_width)
        if next_code < 4096 {
          dictionary[key] = next_code
          next_code += 1
          if next_code > width_limit && code_width < 12 {
            code_width += 1
            width_limit = 1 << code_width
          }
        } else {
          writer.write(clear_code, code_width)
          lzw_clear_dictionary(dictionary)
          next_code = end_code + 1
          code_width = min_code_size + 1
          width_limit = 1 << code_width
        }
        prefix = value
      }
    }
  }
  writer.write(prefix, code_width)
  writer.write(end_code, code_width)
  writer.finish()
}

///|
/// Decode a GIF LZW payload into palette indices.
///
/// `expected_len` is checked when it is non-negative; the decoder rejects both
/// truncated data and streams that expand beyond the declared image size.
pub fn lzw_decode(
  data : Bytes,
  min_code_size : Int,
  expected_len : Int,
) -> Array[Byte] raise GifError {
  if !valid_min_code_size(min_code_size) {
    raise InvalidLzw(context="minimum code size must be between 2 and 8")
  }
  let clear_code = 1 << min_code_size
  let end_code = clear_code + 1
  let table : FixedArray[Array[Byte]] = FixedArray::makei(4096, _ => [])
  for i in 0..<clear_code {
    table[i] = [i.to_byte()]
  }
  let reader = BitReader::new(data)
  let output : Array[Byte] = []
  let mut next_code = end_code + 1
  let mut code_width = min_code_size + 1
  let mut width_limit = 1 << code_width
  let mut previous : Int? = None
  let mut first_char = 0
  let mut saw_end = false
  while !saw_end {
    let code = match reader.read(code_width) {
      None => raise InvalidLzw(context="truncated bit stream")
      Some(value) => value
    }
    if code == clear_code {
      for i in 0..<clear_code {
        table[i] = [i.to_byte()]
      }
      next_code = end_code + 1
      code_width = min_code_size + 1
      width_limit = 1 << code_width
      previous = None
      continue
    }
    if code == end_code {
      saw_end = true
      continue
    }
    if code > 4095 {
      raise InvalidLzw(context="code is larger than the 12-bit GIF limit")
    }
    match previous {
      None => {
        if code >= clear_code {
          raise InvalidLzw(context="first code after clear is not a literal")
        }
        output.push(code.to_byte())
        first_char = code
        previous = Some(code)
      }
      Some(old_code) => {
        let in_code = code
        let sequence : Array[Byte] = []
        if code == next_code {
          for value in table[old_code] {
            sequence.push(value)
          }
          sequence.push(first_char.to_byte())
        } else {
          if code >= next_code {
            raise InvalidLzw(
              context="forward reference code=\{code} next=\{next_code} width=\{code_width}",
            )
          }
          for value in table[code] {
            sequence.push(value)
          }
        }
        guard sequence.length() > 0 else {
          raise InvalidLzw(context="empty decoded sequence")
        }
        first_char = sequence[0].to_int()
        for value in sequence {
          output.push(value)
        }
        if next_code < 4096 {
          let entry : Array[Byte] = []
          for value in table[old_code] {
            entry.push(value)
          }
          entry.push(first_char.to_byte())
          table[next_code] = entry
          next_code += 1
          if next_code >= width_limit && code_width < 12 {
            code_width += 1
            width_limit = 1 << code_width
          }
        }
        previous = Some(in_code)
      }
    }
    if expected_len >= 0 && output.length() > expected_len {
      raise InvalidLzw(context="decoded output is larger than the image")
    }
  }
  if !saw_end {
    raise InvalidLzw(context="missing end code")
  }
  if expected_len >= 0 && output.length() != expected_len {
    raise InvalidLzw(context="decoded output does not match the image size")
  }
  output
}
