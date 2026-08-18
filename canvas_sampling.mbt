///|
/// Sampling policy for thumbnails and preview images.
pub(all) enum SamplingMode {
  Nearest
  BoxAverage
} derive(Eq, Debug)

///|
/// Sample a pixel with integer coordinates, returning transparent black outside.
pub fn Canvas::sample(self : Canvas, x~ : Int, y~ : Int) -> Rgba {
  match self.get(x~, y~) {
    None => rgba(0, 0, 0, 0)
    Some(color) => color
  }
}

///|
/// Downsample or upscale using a selectable integer sampling policy.
pub fn Canvas::sampled(
  self : Canvas,
  width~ : Int,
  height~ : Int,
  mode? : SamplingMode = Nearest,
) -> Canvas {
  if width < 0 || height < 0 {
    panic()
  }
  let result = Canvas::new(width~, height~, fill=rgba(0, 0, 0, 0))
  if width == 0 || height == 0 || self.width == 0 || self.height == 0 {
    result
  } else {
    for y in 0..<height {
      for x in 0..<width {
        result.pixels[x + y * width] = match mode {
          Nearest =>
            self.sample(x=x * self.width / width, y=y * self.height / height)
          BoxAverage => average_sample(self, x, y, width, height)
        }
      }
    }
    result
  }
}

///|
fn average_sample(
  source : Canvas,
  x : Int,
  y : Int,
  target_width : Int,
  target_height : Int,
) -> Rgba {
  let start_x = x * source.width / target_width
  let end_x = (x + 1) * source.width / target_width - 1
  let start_y = y * source.height / target_height
  let end_y = (y + 1) * source.height / target_height - 1
  let safe_end_x = if end_x < start_x { start_x } else { end_x }
  let safe_end_y = if end_y < start_y { start_y } else { end_y }
  let mut red = 0
  let mut green = 0
  let mut blue = 0
  let mut alpha = 0
  let mut count = 0
  for row in start_y..<(safe_end_y + 1) {
    for column in start_x..<(safe_end_x + 1) {
      let color = source.sample(x=column, y=row)
      red += color.red().to_int()
      green += color.green().to_int()
      blue += color.blue().to_int()
      alpha += color.alpha().to_int()
      count += 1
    }
  }
  if count == 0 {
    rgba(0, 0, 0, 0)
  } else {
    rgba(
      (red / count).to_byte(),
      (green / count).to_byte(),
      (blue / count).to_byte(),
      (alpha / count).to_byte(),
    )
  }
}

///|
/// Scale the long edge to `max_edge`, preserving aspect ratio.
pub fn Canvas::thumbnail(
  self : Canvas,
  max_edge : Int,
  mode? : SamplingMode = Nearest,
) -> Canvas {
  if max_edge <= 0 || self.width == 0 || self.height == 0 {
    Canvas::new(width=0, height=0, fill=rgba(0, 0, 0, 0))
  } else if self.width >= self.height {
    let height = self.height * max_edge / self.width
    self.sampled(
      width=max_edge,
      height=if height < 1 { 1 } else { height },
      mode~,
    )
  } else {
    let width = self.width * max_edge / self.height
    self.sampled(
      width=if width < 1 { 1 } else { width },
      height=max_edge,
      mode~,
    )
  }
}

///|
/// Compute the arithmetic mean color of all pixels.
pub fn Canvas::average_color(self : Canvas) -> Rgba {
  if self.pixels.length() == 0 {
    rgba(0, 0, 0, 0)
  } else {
    let mut red = 0
    let mut green = 0
    let mut blue = 0
    let mut alpha = 0
    for color in self.pixels {
      red += color.red().to_int()
      green += color.green().to_int()
      blue += color.blue().to_int()
      alpha += color.alpha().to_int()
    }
    let count = self.pixels.length()
    rgba(
      (red / count).to_byte(),
      (green / count).to_byte(),
      (blue / count).to_byte(),
      (alpha / count).to_byte(),
    )
  }
}

///|
/// Return the most common exact color. This intentionally keeps the fast path
/// small; palette quantization remains the right choice for large images.
pub fn Canvas::dominant_color(self : Canvas) -> Rgba {
  if self.pixels.length() == 0 {
    rgba(0, 0, 0, 0)
  } else {
    let mut best = self.pixels[0]
    let mut best_count = 0
    for candidate in self.pixels {
      let mut count = 0
      for color in self.pixels {
        if color == candidate {
          count += 1
        }
      }
      if count > best_count {
        best = candidate
        best_count = count
      }
    }
    best
  }
}

///|
/// Build an alpha-only mask where visible pixels become white.
pub fn Canvas::alpha_mask(self : Canvas, threshold? : Byte = 1) -> Canvas {
  let result = Canvas::new(
    width=self.width,
    height=self.height,
    fill=rgba(0, 0, 0, 0),
  )
  for i in 0..<self.pixels.length() {
    let alpha = self.pixels[i].alpha()
    result.pixels[i] = if alpha >= threshold {
      rgba(255, 255, 255, alpha)
    } else {
      rgba(0, 0, 0, 0)
    }
  }
  result
}

///|
/// Make an opaque silhouette using the source alpha channel.
pub fn Canvas::silhouette(
  self : Canvas,
  color? : Rgba = rgb(0, 0, 0),
  threshold? : Byte = 1,
) -> Canvas {
  let result = Canvas::new(
    width=self.width,
    height=self.height,
    fill=rgba(0, 0, 0, 0),
  )
  for i in 0..<self.pixels.length() {
    let source = self.pixels[i]
    result.pixels[i] = if source.alpha() >= threshold {
      rgba(color.red(), color.green(), color.blue(), source.alpha())
    } else {
      rgba(0, 0, 0, 0)
    }
  }
  result
}

///|
/// Return a compact hexadecimal-like RGB triplet for diagnostics.
pub fn Rgba::packed_rgb(self : Rgba) -> Int {
  (self.red().to_int() << 16) |
  (self.green().to_int() << 8) |
  self.blue().to_int()
}

///|
/// Convert a packed RGB value into an opaque color.
pub fn rgb_from_packed(value : Int) -> Rgba {
  rgba(
    ((value >> 16) & 255).to_byte(),
    ((value >> 8) & 255).to_byte(),
    (value & 255).to_byte(),
    255,
  )
}
