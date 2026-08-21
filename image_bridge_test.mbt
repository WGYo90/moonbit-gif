///|
test "mizchi image data round trips through the animation bridge" {
  let data = @image.ImageData::{
    width: 2,
    height: 1,
    data: Bytes::from_array([255, 0, 0, 255, 0, 0, 255, 255]),
  }
  let canvas = canvas_from_image_data(data)
  assert_eq(canvas.width(), 2)
  assert_eq(canvas.height(), 1)
  assert_eq(canvas.get(x=1, y=0), Some(rgb(0, 0, 255)))
  let encoded = encode_image_sequence([data, data], delay_cs=4)
  let decoded = decode_first_image_data(encoded)
  assert_eq(decoded.width, 2)
  assert_eq(decoded.height, 1)
  assert_eq(decoded.data, data.data)
}

///|
test "image bridge rejects mixed dimensions" {
  let first = @image.ImageData::{
    width: 1,
    height: 1,
    data: Bytes::from_array([0, 0, 0, 255]),
  }
  let second = @image.ImageData::{
    width: 2,
    height: 1,
    data: Bytes::from_array([0, 0, 0, 255, 0, 0, 0, 255]),
  }
  try animation_from_image_data([first, second]) catch {
    InvalidDimensions => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected mixed dimensions to be rejected")
  }
}
