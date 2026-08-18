///|
test "geometry keeps pixel order" {
  let canvas = Canvas::new(width=2, height=3, fill=rgba(0, 0, 0, 255))
  ignore(canvas.set(x=0, y=0, color=rgb(1, 0, 0)))
  ignore(canvas.set(x=1, y=0, color=rgb(2, 0, 0)))
  ignore(canvas.set(x=0, y=2, color=rgb(3, 0, 0)))
  let rotated = canvas.rotate90()
  assert_eq(rotated.width(), 3)
  assert_eq(rotated.height(), 2)
  assert_eq(rotated.get(x=2, y=0), Some(rgb(1, 0, 0)))
  assert_eq(rotated.get(x=0, y=0), Some(rgb(3, 0, 0)))
  assert_eq(canvas.rotate180().get(x=1, y=2), Some(rgb(1, 0, 0)))
}

///|
test "transparent bounds and alpha mask" {
  let canvas = Canvas::new(width=5, height=4, fill=rgba(0, 0, 0, 0))
  ignore(canvas.set(x=2, y=1, color=rgba(10, 20, 30, 200)))
  let bounds = canvas.opaque_bounds()
  assert_eq(bounds, Some(GifRect::new(left=2, top=1, width=1, height=1)))
  assert_eq(canvas.trim_transparent().width(), 1)
  assert_eq(canvas.alpha_mask().get(x=2, y=1), Some(rgba(255, 255, 255, 200)))
}

///|
test "patches reconstruct changed frames" {
  let base = Canvas::new(width=4, height=4, fill=rgb(0, 0, 0))
  let next = base.copy()
  ignore(next.set(x=2, y=1, color=rgb(255, 0, 0)))
  let patch = next.diff_patch(base)
  assert_true(patch is Some(_))
  let rebuilt = base.copy()
  match patch {
    None => assert_true(false)
    Some(value) => {
      ignore(rebuilt.write_patch(value))
      assert_eq(rebuilt.width(), next.width())
      assert_eq(rebuilt.height(), next.height())
      assert_eq(rebuilt.pixels(), next.pixels())
    }
  }
}

///|
test "timeline positions and normalization" {
  let first = Canvas::new(width=2, height=2, fill=rgb(1, 2, 3))
  let second = Canvas::new(width=2, height=2, fill=rgb(4, 5, 6))
  let animation = Animation::new(width=2, height=2)
    .add_frame(Frame::new(canvas=first, delay_cs=3))
    .add_frame(Frame::new(canvas=second, delay_cs=0))
  assert_eq(animation.duration_cs(), 3)
  let position = animation.position_at(2)
  assert_true(position is Some(_))
  assert_eq(
    animation.frame_at(0).unwrap().canvas().pixels(),
    animation.frames()[0].canvas().pixels(),
  )
  assert_eq(animation.normalize_delays().frames()[1].delay_cs(), 1)
  assert_eq(animation.timeline_starts(), [0, 3])
}

///|
test "sampling and packed colors" {
  let canvas = Canvas::new(width=2, height=2, fill=rgb(20, 30, 40))
  let thumbnail = canvas.thumbnail(4)
  assert_eq(thumbnail.width(), 4)
  assert_eq(thumbnail.height(), 4)
  assert_eq(canvas.average_color(), rgb(20, 30, 40))
  let packed = rgb(1, 2, 3).packed_rgb()
  assert_eq(rgb_from_packed(packed), rgb(1, 2, 3))
}
