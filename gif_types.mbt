///|
/// An RGBA color stored in the byte order used by GIF compositing.
pub(all) struct Rgba {
  r : Byte
  g : Byte
  b : Byte
  a : Byte
} derive(Eq, Debug)

///|
/// Construct an opaque RGB color.
pub fn rgb(r : Byte, g : Byte, b : Byte) -> Rgba {
  { r, g, b, a: 0xff }
}

///|
/// Construct an RGBA color.
pub fn rgba(r : Byte, g : Byte, b : Byte, a : Byte) -> Rgba {
  { r, g, b, a }
}

///|
pub fn Rgba::red(self : Rgba) -> Byte {
  self.r
}

///|
pub fn Rgba::green(self : Rgba) -> Byte {
  self.g
}

///|
pub fn Rgba::blue(self : Rgba) -> Byte {
  self.b
}

///|
pub fn Rgba::alpha(self : Rgba) -> Byte {
  self.a
}

///|
/// An image plane with one RGBA pixel for each coordinate.
///
/// Pixels are stored in row-major order: `x + y * width`.
pub(all) struct Canvas {
  width : Int
  height : Int
  pixels : Array[Rgba]
} derive(Debug)

///|
pub fn Canvas::new(width~ : Int, height~ : Int, fill~ : Rgba) -> Canvas {
  if width < 0 || height < 0 {
    panic()
  }
  { width, height, pixels: Array::make(width * height, fill) }
}

///|
pub fn Canvas::width(self : Canvas) -> Int {
  self.width
}

///|
pub fn Canvas::height(self : Canvas) -> Int {
  self.height
}

///|
pub fn Canvas::len(self : Canvas) -> Int {
  self.pixels.length()
}

///|
pub fn Canvas::get(self : Canvas, x~ : Int, y~ : Int) -> Rgba? {
  if x < 0 || y < 0 || x >= self.width || y >= self.height {
    None
  } else {
    Some(self.pixels[x + y * self.width])
  }
}

///|
pub fn Canvas::set(self : Canvas, x~ : Int, y~ : Int, color~ : Rgba) -> Bool {
  if x < 0 || y < 0 || x >= self.width || y >= self.height {
    false
  } else {
    self.pixels[x + y * self.width] = color
    true
  }
}

///|
pub fn Canvas::pixels(self : Canvas) -> ArrayView[Rgba] {
  self.pixels[:]
}

///|
/// A decoded or to-be-encoded animation frame.
pub(all) struct Frame {
  canvas : Canvas
  delay_cs : Int
  disposal : Disposal
  transparent : Rgba?
  left : Int
  top : Int
} derive(Debug)

///|
pub(all) enum Disposal {
  Keep
  Background
  Previous
} derive(Eq, Debug)

///|
pub fn Frame::new(canvas~ : Canvas, delay_cs~ : Int) -> Frame {
  {
    canvas,
    delay_cs: if delay_cs < 0 {
      0
    } else {
      delay_cs
    },
    disposal: Keep,
    transparent: None,
    left: 0,
    top: 0,
  }
}

///|
pub fn Frame::canvas(self : Frame) -> Canvas {
  self.canvas
}

///|
pub fn Frame::delay_cs(self : Frame) -> Int {
  self.delay_cs
}

///|
pub fn Frame::disposal(self : Frame) -> Disposal {
  self.disposal
}

///|
pub fn Frame::with_disposal(self : Frame, disposal~ : Disposal) -> Frame {
  { ..self, disposal, }
}

///|
pub fn Frame::with_transparent(self : Frame, color~ : Rgba) -> Frame {
  { ..self, transparent: Some(color) }
}

///|
pub fn Frame::with_offset(self : Frame, left~ : Int, top~ : Int) -> Frame {
  { ..self, left, top }
}

///|
pub fn Frame::offset(self : Frame) -> (Int, Int) {
  (self.left, self.top)
}

///|
/// A GIF animation. The encoder writes GIF89a when the animation has more than one frame.
pub(all) struct Animation {
  width : Int
  height : Int
  frames : Array[Frame]
  loop_count : Int?
  background : Rgba
} derive(Debug)

///|
pub fn Animation::new(width~ : Int, height~ : Int) -> Animation {
  if width < 0 || height < 0 {
    panic()
  }
  { width, height, frames: [], loop_count: Some(0), background: rgb(0, 0, 0) }
}

///|
pub fn Animation::width(self : Animation) -> Int {
  self.width
}

///|
pub fn Animation::height(self : Animation) -> Int {
  self.height
}

///|
pub fn Animation::frames(self : Animation) -> ArrayView[Frame] {
  self.frames[:]
}

///|
pub fn Animation::frame_count(self : Animation) -> Int {
  self.frames.length()
}

///|
pub fn Animation::loop_count(self : Animation) -> Int? {
  self.loop_count
}

///|
pub fn Animation::with_loop_count(
  self : Animation,
  loop_count~ : Int?,
) -> Animation {
  { ..self, loop_count, }
}

///|
pub fn Animation::with_background(
  self : Animation,
  background~ : Rgba,
) -> Animation {
  { ..self, background, }
}

///|
pub fn Animation::add_frame(self : Animation, frame : Frame) -> Animation {
  self.frames.push(frame)
  self
}

///|
pub fn Animation::with_frame(
  self : Animation,
  index~ : Int,
  frame : Frame,
) -> Animation {
  if index < 0 || index >= self.frames.length() {
    panic()
  }
  self.frames[index] = frame
  self
}

///|
pub(all) suberror GifError {
  InvalidSignature
  UnexpectedEnd(context~ : String)
  InvalidDimensions
  InvalidBlock(context~ : String)
  UnsupportedFeature(feature~ : String)
  InvalidLzw(context~ : String)
  InvalidPalette(context~ : String)
} derive(Eq, Debug)
