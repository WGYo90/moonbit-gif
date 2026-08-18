///|
/// A perceptual-ish luminance value in the 0..255 range.
pub fn Rgba::luma(self : Rgba) -> Byte {
  ((
    self.red().to_int() * 77 +
    self.green().to_int() * 150 +
    self.blue().to_int() * 29
  ) /
  256).to_byte()
}

///|
pub fn Rgba::with_alpha(self : Rgba, alpha : Byte) -> Rgba {
  rgba(self.red(), self.green(), self.blue(), alpha)
}

///|
pub fn Rgba::grayscale(self : Rgba) -> Rgba {
  let value = self.luma()
  rgba(value, value, value, self.alpha())
}

///|
pub fn Rgba::invert(self : Rgba) -> Rgba {
  rgba(255 - self.red(), 255 - self.green(), 255 - self.blue(), self.alpha())
}

///|
pub fn Rgba::distance(self : Rgba, other : Rgba) -> Int {
  let r = self.red().to_int() - other.red().to_int()
  let g = self.green().to_int() - other.green().to_int()
  let b = self.blue().to_int() - other.blue().to_int()
  r * r + g * g + b * b
}

///|
/// Linear interpolation in byte space.
pub fn mix_color(
  left : Rgba,
  right : Rgba,
  numerator : Int,
  denominator : Int,
) -> Rgba {
  if denominator <= 0 {
    right
  } else {
    let amount = if numerator < 0 {
      0
    } else if numerator > denominator {
      denominator
    } else {
      numerator
    }
    rgba(
      ((
        left.red().to_int() * (denominator - amount) +
        right.red().to_int() * amount
      ) /
      denominator).to_byte(),
      ((
        left.green().to_int() * (denominator - amount) +
        right.green().to_int() * amount
      ) /
      denominator).to_byte(),
      ((
        left.blue().to_int() * (denominator - amount) +
        right.blue().to_int() * amount
      ) /
      denominator).to_byte(),
      ((
        left.alpha().to_int() * (denominator - amount) +
        right.alpha().to_int() * amount
      ) /
      denominator).to_byte(),
    )
  }
}

///|
/// Pixel summary used to choose quantization and preview settings.
pub(all) struct CanvasStats {
  pixel_count : Int
  opaque_count : Int
  transparent_count : Int
  minimum_luma : Byte
  maximum_luma : Byte
  average_luma : Int
} derive(Debug)

///|
pub fn CanvasStats::pixel_count(self : CanvasStats) -> Int {
  self.pixel_count
}

///|
pub fn CanvasStats::opaque_count(self : CanvasStats) -> Int {
  self.opaque_count
}

///|
pub fn CanvasStats::transparent_count(self : CanvasStats) -> Int {
  self.transparent_count
}

///|
pub fn CanvasStats::minimum_luma(self : CanvasStats) -> Byte {
  self.minimum_luma
}

///|
pub fn CanvasStats::maximum_luma(self : CanvasStats) -> Byte {
  self.maximum_luma
}

///|
pub fn CanvasStats::average_luma(self : CanvasStats) -> Int {
  self.average_luma
}

///|
pub fn Canvas::stats(self : Canvas) -> CanvasStats {
  if self.pixels.length() == 0 {
    CanvasStats::{
      pixel_count: 0,
      opaque_count: 0,
      transparent_count: 0,
      minimum_luma: 0,
      maximum_luma: 0,
      average_luma: 0,
    }
  } else {
    let mut opaque_pixels = 0
    let mut transparent = 0
    let mut minimum = 255
    let mut maximum = 0
    let mut total = 0
    for color in self.pixels {
      if color.alpha() == 255 {
        opaque_pixels += 1
      }
      if color.alpha() == 0 {
        transparent += 1
      }
      let luma = color.luma().to_int()
      if luma < minimum {
        minimum = luma
      }
      if luma > maximum {
        maximum = luma
      }
      total += luma
    }
    CanvasStats::{
      pixel_count: self.pixels.length(),
      opaque_count: opaque_pixels,
      transparent_count: transparent,
      minimum_luma: minimum.to_byte(),
      maximum_luma: maximum.to_byte(),
      average_luma: total / self.pixels.length(),
    }
  }
}

///|
/// Apply a deterministic color transform selected by a small enum.
pub(all) enum ColorTransform {
  Identity
  Grayscale
  Invert
  Opaque
  Transparent
} derive(Eq, Debug)

///|
fn apply_color_transform(color : Rgba, transform : ColorTransform) -> Rgba {
  match transform {
    Identity => color
    Grayscale => color.grayscale()
    Invert => color.invert()
    Opaque => color.with_alpha(255)
    Transparent => color.with_alpha(0)
  }
}

///|
pub fn Canvas::map_colors(self : Canvas, transform : ColorTransform) -> Canvas {
  let result = self.copy()
  for i in 0..<result.pixels.length() {
    result.pixels[i] = apply_color_transform(result.pixels[i], transform)
  }
  result
}

///|
pub fn Canvas::grayscale(self : Canvas) -> Canvas {
  self.map_colors(Grayscale)
}

///|
pub fn Canvas::invert(self : Canvas) -> Canvas {
  self.map_colors(Invert)
}

///|
pub fn Canvas::tint(self : Canvas, tint~ : Rgba, strength~ : Int) -> Canvas {
  let amount = if strength < 0 {
    0
  } else if strength > 255 {
    255
  } else {
    strength
  }
  let result = self.copy()
  for i in 0..<result.pixels.length() {
    result.pixels[i] = mix_color(result.pixels[i], tint, amount, 255)
  }
  result
}

///|
pub fn Canvas::fade_to(
  self : Canvas,
  target : Canvas,
  numerator : Int,
  denominator : Int,
) -> Canvas {
  if self.width != target.width || self.height != target.height {
    target.copy()
  } else {
    let result = self.copy()
    for i in 0..<result.pixels.length() {
      result.pixels[i] = mix_color(
        self.pixels[i],
        target.pixels[i],
        numerator,
        denominator,
      )
    }
    result
  }
}

///|
/// A stable non-cryptographic hash for cache keys and snapshot tests.
pub fn Canvas::hash(self : Canvas) -> UInt {
  let mut hash = 2166136261U
  for color in self.pixels {
    hash = (hash ^ color.red().to_uint()) * 16777619U
    hash = (hash ^ color.green().to_uint()) * 16777619U
    hash = (hash ^ color.blue().to_uint()) * 16777619U
    hash = (hash ^ color.alpha().to_uint()) * 16777619U
  }
  hash
}
