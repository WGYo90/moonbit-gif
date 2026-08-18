///|
test "median cut creates a bounded palette" {
  let canvas = Canvas::new(width=32, height=1, fill=rgb(0, 0, 0))
  for x in 0..<32 {
    ignore(
      canvas.set(
        x~,
        y=0,
        color=rgb((x * 8).to_byte(), (255 - x * 8).to_byte(), (x * 3).to_byte()),
      ),
    )
  }
  let quantized = quantize(canvas, max_colors=4)
  assert_true(quantized.palette().len() <= 4)
  assert_eq(quantized.indices().length(), 32)
  for index in quantized.indices() {
    assert_true(index.to_int() < quantized.palette().len())
  }
}

///|
test "median cut preserves transparent pixels" {
  let transparent = rgba(8, 9, 10, 0)
  let canvas = Canvas::new(width=3, height=1, fill=transparent)
  ignore(canvas.set(x=1, y=0, color=rgb(255, 0, 0)))
  let quantized = quantize(canvas, max_colors=4, transparent~)
  assert_true(quantized.palette().transparent_index() is Some(_))
  assert_eq(quantized.indices()[0], quantized.indices()[2])
  assert_true(quantized.indices()[1] != quantized.indices()[0])
}
