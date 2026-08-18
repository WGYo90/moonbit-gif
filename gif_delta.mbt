///|
/// A clipped rectangle in logical-screen coordinates.
pub(all) struct GifRect {
  left : Int
  top : Int
  width : Int
  height : Int
} derive(Eq, Debug)

///|
pub fn GifRect::new(
  left~ : Int,
  top~ : Int,
  width~ : Int,
  height~ : Int,
) -> GifRect {
  { left, top, width, height }
}

///|
pub fn GifRect::left(self : GifRect) -> Int {
  self.left
}

///|
pub fn GifRect::top(self : GifRect) -> Int {
  self.top
}

///|
pub fn GifRect::width(self : GifRect) -> Int {
  self.width
}

///|
pub fn GifRect::height(self : GifRect) -> Int {
  self.height
}

///|
pub fn GifRect::area(self : GifRect) -> Int {
  self.width * self.height
}

///|
pub fn GifRect::right(self : GifRect) -> Int {
  self.left + self.width
}

///|
pub fn GifRect::bottom(self : GifRect) -> Int {
  self.top + self.height
}

///|
/// Find changed pixels using a squared RGBA distance threshold.
pub fn changed_rect(left : Canvas, right : Canvas, threshold : Int) -> GifRect? {
  if left.width != right.width || left.height != right.height {
    Some(GifRect::{ left: 0, top: 0, width: right.width, height: right.height })
  } else {
    let limit = if threshold < 0 { 0 } else { threshold }
    let mut min_x = left.width
    let mut min_y = left.height
    let mut max_x = -1
    let mut max_y = -1
    for y in 0..<left.height {
      for x in 0..<left.width {
        let a = left.pixels[x + y * left.width]
        let b = right.pixels[x + y * right.width]
        let alpha_difference = a.alpha().to_int() - b.alpha().to_int()
        let distance = a.distance(b) + alpha_difference * alpha_difference
        if distance > limit {
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
      Some(GifRect::{
        left: min_x,
        top: min_y,
        width: max_x - min_x + 1,
        height: max_y - min_y + 1,
      })
    }
  }
}

///|
pub(all) struct DeltaStats {
  frame_count : Int
  full_pixels : Int
  delta_pixels : Int
  changed_frames : Int
} derive(Debug)

///|
pub fn DeltaStats::frame_count(self : DeltaStats) -> Int {
  self.frame_count
}

///|
pub fn DeltaStats::full_pixels(self : DeltaStats) -> Int {
  self.full_pixels
}

///|
pub fn DeltaStats::delta_pixels(self : DeltaStats) -> Int {
  self.delta_pixels
}

///|
pub fn DeltaStats::changed_frames(self : DeltaStats) -> Int {
  self.changed_frames
}

///|
pub fn DeltaStats::saving_per_mille(self : DeltaStats) -> Int {
  if self.full_pixels <= 0 {
    0
  } else {
    (self.full_pixels - self.delta_pixels) * 1000 / self.full_pixels
  }
}

///|
/// Estimate the amount of pixel data saved by frame differencing.
pub fn Animation::delta_stats(
  self : Animation,
  threshold? : Int = 0,
) -> DeltaStats {
  let full_pixels = self.width * self.height * self.frames.length()
  if self.frames.length() == 0 {
    DeltaStats::{
      frame_count: 0,
      full_pixels,
      delta_pixels: 0,
      changed_frames: 0,
    }
  } else {
    let mut previous = self.background_canvas()
    let mut delta_pixels = 0
    let mut changed_frames = 0
    for frame in self.frames {
      match changed_rect(previous, frame.canvas, threshold) {
        None => delta_pixels += 1
        Some(rect) => {
          delta_pixels += rect.area()
          changed_frames += 1
        }
      }
      previous = frame.canvas
    }
    DeltaStats::{
      frame_count: self.frames.length(),
      full_pixels,
      delta_pixels,
      changed_frames,
    }
  }
}

///|
fn Animation::background_canvas(self : Animation) -> Canvas {
  Canvas::new(width=self.width, height=self.height, fill=self.background)
}

///|
/// Encode unchanged frames as transparent 1x1 frames and crop changed frames
/// to their bounding rectangles. This is an optimization pass; it preserves
/// timing and keeps the logical screen size unchanged.
pub fn Animation::delta_encode(
  self : Animation,
  threshold? : Int = 0,
) -> Animation {
  if self.frames.length() == 0 {
    self
  } else {
    let transparent = rgba(0, 0, 0, 0)
    let frames : Array[Frame] = []
    let mut previous = self.background_canvas()
    for frame in self.frames {
      match changed_rect(previous, frame.canvas, threshold) {
        None => {
          let empty = Canvas::new(width=1, height=1, fill=transparent)
          frames.push(
            Frame::new(canvas=empty, delay_cs=frame.delay_cs).with_transparent(
              color=transparent,
            ),
          )
        }
        Some(rect) => {
          let cropped = frame.canvas.crop(
            x=rect.left,
            y=rect.top,
            width=rect.width,
            height=rect.height,
          )
          let optimized = Frame::new(canvas=cropped, delay_cs=frame.delay_cs)
            .with_offset(left=rect.left, top=rect.top)
            .with_disposal(disposal=frame.disposal)
          let final_frame = match frame.transparent {
            None => optimized
            Some(color) => optimized.with_transparent(color~)
          }
          frames.push(final_frame)
        }
      }
      previous = frame.canvas
    }
    Animation::{ ..self, frames, }
  }
}

///|
/// Alias emphasizing that the pass is safe to apply before encoding.
pub fn Animation::optimize_frames(self : Animation) -> Animation {
  self.delta_encode()
}
