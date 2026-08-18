///|
/// A tiny, deterministic example used by the README and CI.
fn main raise {
  let canvas = @gif.Canvas::new(width=8, height=8, fill=@gif.rgb(20, 24, 32))
  for y in 0..<8 {
    for x in 0..<8 {
      if x == y || x + y == 7 {
        ignore(canvas.set(x~, y~, color=@gif.rgb(240, 180, 40)))
      }
    }
  }
  let frame = @gif.Frame::new(canvas~, delay_cs=8)
  let animation = @gif.Animation::new(width=8, height=8).add_frame(frame)
  let encoded = @gif.encode(animation)
  let decoded = @gif.decode(encoded)
  println(
    "moonbit-gif: \{encoded.length()} bytes, \{decoded.frame_count()} frame",
  )
}
