///|
fn test_canvas() -> Canvas {
  let canvas = Canvas::new(width=4, height=3, fill=rgb(0, 0, 0))
  for y in 0..<3 {
    for x in 0..<4 {
      if (x + y) % 2 == 0 {
        ignore(canvas.set(x~, y~, color=rgb(255, 32, 16)))
      } else {
        ignore(canvas.set(x~, y~, color=rgb(16, 64, 220)))
      }
    }
  }
  canvas
}

///|
test "gif89a single frame round trip" {
  let frame = Frame::new(canvas=test_canvas(), delay_cs=7)
  let animation = Animation::new(width=4, height=3).add_frame(frame)
  let encoded = encode(animation)
  assert_true(encoded.length() > 30)
  assert_eq(encoded[0], b'G')
  assert_eq(encoded[3], b'8')
  assert_eq(encoded[4], b'9')
  let decoded = decode(encoded)
  assert_eq(decoded.width(), 4)
  assert_eq(decoded.height(), 3)
  assert_eq(decoded.frame_count(), 1)
  assert_eq(decoded.frames()[0].delay_cs(), 7)
  assert_eq(decoded.frames()[0].canvas().get(x=0, y=0), Some(rgb(255, 32, 16)))
}

///|
test "gif animation writes loop extension and composes disposal" {
  let background = rgb(0, 0, 0)
  let first_canvas = Canvas::new(width=2, height=2, fill=rgb(0, 0, 0))
  ignore(first_canvas.set(x=0, y=0, color=rgb(255, 0, 0)))
  let second_canvas = Canvas::new(width=1, height=1, fill=rgb(0, 0, 0))
  ignore(second_canvas.set(x=0, y=0, color=rgb(0, 255, 0)))
  let first = Frame::new(canvas=first_canvas, delay_cs=4)
  let second = Frame::new(canvas=second_canvas, delay_cs=5)
    .with_offset(left=1, top=1)
    .with_disposal(disposal=Background)
  let animation = Animation::new(width=2, height=2)
    .with_background(background~)
    .add_frame(first)
    .add_frame(second)
  let encoded = encode(animation)
  let decoded = decode(encoded)
  assert_eq(decoded.frame_count(), 2)
  assert_eq(decoded.loop_count(), Some(0))
  let rendered = compose(animation)
  assert_eq(rendered.length(), 2)
  assert_eq(rendered[0].get(x=0, y=0), Some(rgb(255, 0, 0)))
  assert_eq(rendered[1].get(x=1, y=1), Some(rgb(0, 255, 0)))
}

///|
test "gif decoder rejects a bad signature" {
  try decode(b"not-a-gif-1234") catch {
    InvalidSignature => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected an invalid signature")
  }
}
