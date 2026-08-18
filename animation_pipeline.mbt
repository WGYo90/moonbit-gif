///|
/// Timeline-wide canvas transform.
pub(all) enum AnimationTransform {
  Identity
  Grayscale
  Invert
  FlipHorizontal
  FlipVertical
} derive(Eq, Debug)

///|
fn transform_canvas(canvas : Canvas, transform : AnimationTransform) -> Canvas {
  match transform {
    Identity => canvas.copy()
    Grayscale => canvas.grayscale()
    Invert => canvas.invert()
    FlipHorizontal => canvas.flip_horizontal()
    FlipVertical => canvas.flip_vertical()
  }
}

///|
/// Apply the same canvas transform to every frame.
pub fn Animation::map_transform(
  self : Animation,
  transform : AnimationTransform,
) -> Animation {
  let frames : Array[Frame] = []
  for frame in self.frames {
    frames.push({ ..frame, canvas: transform_canvas(frame.canvas, transform) })
  }
  Animation::{ ..self, frames, }
}

///|
pub fn Animation::grayscale(self : Animation) -> Animation {
  self.map_transform(Grayscale)
}

///|
pub fn Animation::invert(self : Animation) -> Animation {
  self.map_transform(Invert)
}

///|
pub fn Animation::flip_horizontal(self : Animation) -> Animation {
  self.map_transform(FlipHorizontal)
}

///|
pub fn Animation::flip_vertical(self : Animation) -> Animation {
  self.map_transform(FlipVertical)
}

///|
/// Resize every frame and update the logical screen dimensions.
pub fn Animation::resize_nearest(
  self : Animation,
  width~ : Int,
  height~ : Int,
) -> Animation {
  let frames : Array[Frame] = []
  for frame in self.frames {
    frames.push({
      ..frame,
      canvas: frame.canvas.resize_nearest(width~, height~),
      left: 0,
      top: 0,
    })
  }
  Animation::{ ..self, width, height, frames }
}

///|
/// Crop every frame to the same logical rectangle.
pub fn Animation::crop(
  self : Animation,
  x~ : Int,
  y~ : Int,
  width~ : Int,
  height~ : Int,
) -> Animation {
  let frames : Array[Frame] = []
  for frame in self.frames {
    frames.push({
      ..frame,
      canvas: frame.canvas.crop(x~, y~, width~, height~),
      left: 0,
      top: 0,
    })
  }
  Animation::{ ..self, width, height, frames }
}

///|
/// Add a constant delay to every frame, clamping to GIF's practical range.
pub fn Animation::delay_all(self : Animation, delay_cs : Int) -> Animation {
  let safe_delay = if delay_cs < 0 {
    0
  } else if delay_cs > 65535 {
    65535
  } else {
    delay_cs
  }
  let frames : Array[Frame] = []
  for frame in self.frames {
    frames.push(frame.with_delay(delay_cs=frame.delay_cs + safe_delay))
  }
  Animation::{ ..self, frames, }
}

///|
/// Set every frame to one delay value.
pub fn Animation::with_delay(self : Animation, delay_cs : Int) -> Animation {
  let safe_delay = if delay_cs < 0 {
    0
  } else if delay_cs > 65535 {
    65535
  } else {
    delay_cs
  }
  let frames : Array[Frame] = []
  for frame in self.frames {
    frames.push(frame.with_delay(delay_cs=safe_delay))
  }
  Animation::{ ..self, frames, }
}

///|
/// Concatenate two animations with identical logical dimensions.
pub fn Animation::append(self : Animation, other : Animation) -> Animation {
  if self.width != other.width || self.height != other.height {
    panic()
  }
  let frames : Array[Frame] = []
  for frame in self.frames {
    frames.push(frame)
  }
  for frame in other.frames {
    frames.push(frame)
  }
  Animation::{ ..self, frames, }
}

///|
/// Generate a cross-fade animation from the last frame of `left` to the first
/// frame of `right`. `steps` is the number of intervals, so `steps=1` emits
/// the two endpoint frames.
pub fn crossfade(
  left : Animation,
  right : Animation,
  steps : Int,
  delay_cs? : Int = 5,
) -> Animation {
  if left.width != right.width ||
    left.height != right.height ||
    left.frames.length() == 0 ||
    right.frames.length() == 0 {
    panic()
  }
  let count = if steps < 1 { 1 } else { steps }
  let start = left.frames[left.frames.length() - 1]
  let finish = right.frames[0]
  let frames : Array[Frame] = []
  for i in 0..<(count + 1) {
    let canvas = start.canvas.fade_to(finish.canvas, i, count)
    frames.push(Frame::new(canvas~, delay_cs~))
  }
  Animation::{
    width: left.width,
    height: left.height,
    frames,
    loop_count: left.loop_count,
    background: left.background,
  }
}

///|
/// Insert a hold after each frame, keeping the original delay on the first copy.
pub fn Animation::hold(self : Animation, copies : Int) -> Animation {
  let result : Array[Frame] = []
  let count = if copies < 1 { 1 } else { copies }
  for frame in self.frames {
    for i in 0..<count {
      result.push(if i == 0 { frame } else { frame.with_delay(delay_cs=0) })
    }
  }
  Animation::{ ..self, frames: result }
}

///|
/// Normalize all frames to the logical screen and reset their offsets.
pub fn Animation::flatten_frames(self : Animation) -> Animation {
  let snapshots = compose(self)
  let frames : Array[Frame] = []
  for i, canvas in snapshots {
    frames.push({ ..self.frames[i], canvas, left: 0, top: 0 })
  }
  Animation::{ ..self, frames, }
}

///|
/// Remove disposal history by flattening and making each frame persistent.
pub fn Animation::persistent(self : Animation) -> Animation {
  let flattened = self.flatten_frames()
  let frames : Array[Frame] = []
  for frame in flattened.frames {
    frames.push({ ..frame, disposal: Keep })
  }
  Animation::{ ..flattened, frames, }
}

///|
/// Return the first frame's canvas, if present.
pub fn Animation::first_canvas(self : Animation) -> Canvas? {
  if self.frames.length() == 0 {
    None
  } else {
    Some(self.frames[0].canvas)
  }
}

///|
/// Return the last frame's canvas, if present.
pub fn Animation::last_canvas(self : Animation) -> Canvas? {
  if self.frames.length() == 0 {
    None
  } else {
    Some(self.frames[self.frames.length() - 1].canvas)
  }
}
