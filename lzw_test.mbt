///|
test "lzw round trip keeps repeated runs" {
  let source : Array[Byte] = [
    0, 1, 2, 3, 2, 1, 0, 0, 1, 2, 3, 2, 1, 0, 0, 0, 1, 1, 2, 2, 3, 3, 2, 2, 1, 1,
  ]
  let encoded = lzw_encode(source[:], 2)
  let decoded = lzw_decode(encoded, 2, source.length()) catch {
    InvalidLzw(context=message) => fail(message)
    _ => fail("unexpected error")
  }
  assert_eq(decoded, source)
  assert_true(encoded.length() < source.length())
}

///|
test "lzw accepts clear codes and grows code width" {
  let source : Array[Byte] = []
  for i in 0..<900 {
    source.push((i % 16).to_byte())
  }
  let encoded = lzw_encode(source[:], 4)
  let decoded = lzw_decode(encoded, 4, source.length())
  assert_eq(decoded, source)
}

///|
test "lzw rejects an invalid minimum code size" {
  try lzw_encode([0, 1], 1) catch {
    InvalidLzw(context=message) => assert_true(message.contains("minimum"))
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected an invalid LZW error")
  }
}

///|
test "lzw handles a checkerboard image stream" {
  let source : Array[Byte] = []
  for y in 0..<8 {
    for x in 0..<8 {
      source.push(if x == y || x + y == 7 { 1 } else { 0 })
    }
  }
  let encoded = lzw_encode(source[:], 2)
  let decoded = lzw_decode(encoded, 2, source.length())
  assert_eq(decoded.length(), source.length())
  for i in 0..<source.length() {
    assert_eq(decoded[i], source[i])
  }
}
