///|
/// Summary values useful for timeline UIs and encoder diagnostics.
pub(all) struct AnimationStats {
  frame_count : Int
  duration_cs : Int
  transparent_frames : Int
  changed_pixels : Int
} derive(Debug)

///|
pub fn AnimationStats::frame_count(self : AnimationStats) -> Int {
  self.frame_count
}

///|
pub fn AnimationStats::duration_cs(self : AnimationStats) -> Int {
  self.duration_cs
}

///|
pub fn AnimationStats::transparent_frames(self : AnimationStats) -> Int {
  self.transparent_frames
}

///|
pub fn AnimationStats::changed_pixels(self : AnimationStats) -> Int {
  self.changed_pixels
}

///|
pub fn Frame::with_delay(self : Frame, delay_cs~ : Int) -> Frame {
  { ..self, delay_cs: if delay_cs < 0 { 0 } else { delay_cs } }
}

///|
/// Sum frame delays in GIF centiseconds.
pub fn Animation::duration_cs(self : Animation) -> Int {
  let mut duration = 0
  for frame in self.frames {
    duration += frame.delay_cs
  }
  duration
}

///|
/// Build a timeline from canvases with one delay value.
pub fn animation_from_canvases(
  canvases : ArrayView[Canvas],
  delay_cs~ : Int,
  loop_count? : Int,
) -> Animation {
  if canvases.length() == 0 {
    Animation::new(width=0, height=0)
  } else {
    let first = canvases[0]
    let mut animation = Animation::new(width=first.width, height=first.height)
    match loop_count {
      None => ()
      Some(value) =>
        animation = animation.with_loop_count(loop_count=Some(value))
    }
    for canvas in canvases {
      if canvas.width != first.width || canvas.height != first.height {
        panic()
      }
      animation = animation.add_frame(Frame::new(canvas~, delay_cs~))
    }
    animation
  }
}

///|
/// Return a timeline with frames in reverse display order.
pub fn Animation::reverse(self : Animation) -> Animation {
  let reversed : Array[Frame] = []
  let mut i = self.frames.length() - 1
  while i >= 0 {
    reversed.push(self.frames[i])
    i -= 1
  }
  Animation::{ ..self, frames: reversed }
}

///|
/// Repeat the timeline `times` times. A zero or negative count returns no frames.
pub fn Animation::repeat(self : Animation, times : Int) -> Animation {
  let result : Array[Frame] = []
  if times > 0 {
    for _ in 0..<times {
      for frame in self.frames {
        result.push(frame)
      }
    }
  }
  Animation::{ ..self, frames: result }
}

///|
/// Select a half-open range of frames.
pub fn Animation::slice(
  self : Animation,
  start~ : Int,
  end~ : Int,
) -> Animation {
  let safe_start = if start < 0 {
    0
  } else if start > self.frames.length() {
    self.frames.length()
  } else {
    start
  }
  let safe_end = if end < safe_start {
    safe_start
  } else if end > self.frames.length() {
    self.frames.length()
  } else {
    end
  }
  let result : Array[Frame] = []
  for i in safe_start..<safe_end {
    result.push(self.frames[i])
  }
  Animation::{ ..self, frames: result }
}

///|
/// Calculate how many pixels changed between two full-size frames.
pub fn frame_difference(left : Frame, right : Frame) -> Int {
  pixel_difference(left.canvas, right.canvas)
}

///|
/// Return the smallest rectangle containing changed pixels, or `None` when equal.
pub fn changed_bounds(left : Canvas, right : Canvas) -> (Int, Int, Int, Int)? {
  if left.width != right.width || left.height != right.height {
    Some(
      (
        0,
        0,
        if right.width > left.width {
          right.width
        } else {
          left.width
        },
        if right.height > left.height {
          right.height
        } else {
          left.height
        },
      ),
    )
  } else {
    let mut min_x = left.width
    let mut min_y = left.height
    let mut max_x = -1
    let mut max_y = -1
    for y in 0..<left.height {
      for x in 0..<left.width {
        if left.pixels[x + y * left.width] != right.pixels[x + y * right.width] {
          if x < min_x {
            min_x = x
          }
          if y < min_y {
            min_y = y
          }
          if x > max_x {
            max_x = x
          }
          if y > max_y {
            max_y = y
          }
        }
      }
    }
    if max_x < 0 {
      None
    } else {
      Some((min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
    }
  }
}

///|
/// Compute statistics without encoding the animation.
pub fn Animation::stats(self : Animation) -> AnimationStats {
  let mut transparent_frames = 0
  let mut changed_pixels = 0
  let mut previous : Canvas? = None
  for frame in self.frames {
    if frame.transparent is Some(_) || !frame.canvas.is_opaque() {
      transparent_frames += 1
    }
    match previous {
      None => changed_pixels += frame.canvas.width * frame.canvas.height
      Some(canvas) => changed_pixels += pixel_difference(canvas, frame.canvas)
    }
    previous = Some(frame.canvas)
  }
  AnimationStats::{
    frame_count: self.frames.length(),
    duration_cs: self.duration_cs(),
    transparent_frames,
    changed_pixels,
  }
}

///|
/// Mutable-style builder that keeps construction readable in CLI tools.
pub(all) struct AnimationBuilder {
  animation : Animation
} derive(Debug)

///|
pub fn AnimationBuilder::new(width~ : Int, height~ : Int) -> AnimationBuilder {
  { animation: Animation::new(width~, height~) }
}

///|
pub fn AnimationBuilder::background(
  self : AnimationBuilder,
  color : Rgba,
) -> AnimationBuilder {
  { animation: self.animation.with_background(background=color) }
}

///|
pub fn AnimationBuilder::loop_count(
  self : AnimationBuilder,
  value : Int?,
) -> AnimationBuilder {
  { animation: self.animation.with_loop_count(loop_count=value) }
}

///|
pub fn AnimationBuilder::frame(
  self : AnimationBuilder,
  frame : Frame,
) -> AnimationBuilder {
  { animation: self.animation.add_frame(frame) }
}

///|
pub fn AnimationBuilder::solid_frame(
  self : AnimationBuilder,
  color~ : Rgba,
  delay_cs~ : Int,
) -> AnimationBuilder {
  let canvas = Canvas::new(
    width=self.animation.width,
    height=self.animation.height,
    fill=color,
  )
  self.frame(Frame::new(canvas~, delay_cs~))
}

///|
pub fn AnimationBuilder::build(self : AnimationBuilder) -> Animation {
  self.animation
}
