///|
fn int_abs(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
fn clamp_byte_int(value : Int) -> Byte {
  if value < 0 {
    0
  } else if value > 255 {
    255
  } else {
    value.to_byte()
  }
}

///|
fn blend_rgba(source : Rgba, destination : Rgba) -> Rgba {
  let source_alpha = source.alpha().to_int()
  if source_alpha >= 255 {
    source
  } else if source_alpha == 0 {
    destination
  } else {
    let destination_alpha = destination.alpha().to_int()
    let inverse = 255 - source_alpha
    let output_alpha = source_alpha + destination_alpha * inverse / 255
    if output_alpha == 0 {
      rgba(0, 0, 0, 0)
    } else {
      rgba(
        clamp_byte_int(
          (
            source.red().to_int() * source_alpha +
            destination.red().to_int() * destination_alpha * inverse / 255
          ) /
          output_alpha,
        ),
        clamp_byte_int(
          (
            source.green().to_int() * source_alpha +
            destination.green().to_int() * destination_alpha * inverse / 255
          ) /
          output_alpha,
        ),
        clamp_byte_int(
          (
            source.blue().to_int() * source_alpha +
            destination.blue().to_int() * destination_alpha * inverse / 255
          ) /
          output_alpha,
        ),
        output_alpha.to_byte(),
      )
    }
  }
}

///|
/// Fill the entire canvas with a color.
pub fn Canvas::fill(self : Canvas, color : Rgba) -> Unit {
  for i in 0..<self.pixels.length() {
    self.pixels[i] = color
  }
}

///|
/// Fill a clipped rectangle and return the number of pixels written.
pub fn Canvas::fill_rect(
  self : Canvas,
  x~ : Int,
  y~ : Int,
  width~ : Int,
  height~ : Int,
  color~ : Rgba,
) -> Int {
  if width <= 0 || height <= 0 {
    0
  } else {
    let start_x = if x < 0 { 0 } else { x }
    let start_y = if y < 0 { 0 } else { y }
    let end_x = if x + width > self.width { self.width } else { x + width }
    let end_y = if y + height > self.height { self.height } else { y + height }
    let mut count = 0
    if start_x < end_x && start_y < end_y {
      for row in start_y..<end_y {
        for column in start_x..<end_x {
          self.pixels[column + row * self.width] = color
          count += 1
        }
      }
    }
    count
  }
}

///|
/// Alpha-blend one pixel. Returns false when the coordinate is outside the canvas.
pub fn Canvas::blend_pixel(
  self : Canvas,
  x~ : Int,
  y~ : Int,
  color~ : Rgba,
) -> Bool {
  match self.get(x~, y~) {
    None => false
    Some(previous) => {
      self.pixels[x + y * self.width] = blend_rgba(color, previous)
      true
    }
  }
}

///|
/// Draw a clipped Bresenham line.
pub fn Canvas::draw_line(
  self : Canvas,
  x0~ : Int,
  y0~ : Int,
  x1~ : Int,
  y1~ : Int,
  color~ : Rgba,
) -> Int {
  let mut x = x0
  let mut y = y0
  let dx = int_abs(x1 - x0)
  let sx = if x0 < x1 { 1 } else { -1 }
  let dy = -int_abs(y1 - y0)
  let sy = if y0 < y1 { 1 } else { -1 }
  let mut error = dx + dy
  let mut written = 0
  let mut done = false
  while !done {
    if self.set(x~, y~, color~) {
      written += 1
    }
    if x == x1 && y == y1 {
      done = true
    } else {
      let twice = 2 * error
      if twice >= dy {
        error += dy
        x += sx
      }
      if twice <= dx {
        error += dx
        y += sy
      }
    }
  }
  written
}

///|
/// Draw a rectangle outline. Coordinates are inclusive.
pub fn Canvas::draw_rect(
  self : Canvas,
  x~ : Int,
  y~ : Int,
  width~ : Int,
  height~ : Int,
  color~ : Rgba,
) -> Int {
  if width <= 0 || height <= 0 {
    0
  } else {
    let right = x + width - 1
    let bottom = y + height - 1
    let mut count = self.draw_line(x0=x, y0=y, x1=right, y1=y, color~)
    count += self.draw_line(x0=right, y0=y, x1=right, y1=bottom, color~)
    count += self.draw_line(x0=right, y0=bottom, x1=x, y1=bottom, color~)
    count += self.draw_line(x0=x, y0=bottom, x1=x, y1=y, color~)
    count
  }
}

///|
/// Fill a circle using an integer distance test.
pub fn Canvas::fill_circle(
  self : Canvas,
  center_x~ : Int,
  center_y~ : Int,
  radius~ : Int,
  color~ : Rgba,
) -> Int {
  if radius < 0 {
    0
  } else {
    let mut count = 0
    let radius_squared = radius * radius
    for y in (center_y - radius)..<(center_y + radius + 1) {
      for x in (center_x - radius)..<(center_x + radius + 1) {
        let dx = x - center_x
        let dy = y - center_y
        if dx * dx + dy * dy <= radius_squared && self.set(x~, y~, color~) {
          count += 1
        }
      }
    }
    count
  }
}

///|
/// Draw a circle outline using a midpoint-style eight-way rasterization.
pub fn Canvas::draw_circle(
  self : Canvas,
  center_x~ : Int,
  center_y~ : Int,
  radius~ : Int,
  color~ : Rgba,
) -> Int {
  if radius < 0 {
    0
  } else if radius == 0 {
    if self.set(x=center_x, y=center_y, color~) {
      1
    } else {
      0
    }
  } else {
    let mut x = radius
    let mut y = 0
    let mut decision = 1 - radius
    let mut count = 0
    while x >= y {
      count += draw_circle_points(self, center_x, center_y, x, y, color)
      y += 1
      if decision <= 0 {
        decision += 2 * y + 1
      } else {
        x -= 1
        decision += 2 * (y - x) + 1
      }
    }
    count
  }
}

///|
fn draw_circle_points(
  canvas : Canvas,
  cx : Int,
  cy : Int,
  x : Int,
  y : Int,
  color : Rgba,
) -> Int {
  let points = [
    (cx + x, cy + y),
    (cx + y, cy + x),
    (cx - y, cy + x),
    (cx - x, cy + y),
    (cx - x, cy - y),
    (cx - y, cy - x),
    (cx + y, cy - x),
    (cx + x, cy - y),
  ]
  let mut count = 0
  for point in points {
    let (px, py) = point
    if canvas.set(x=px, y=py, color~) {
      count += 1
    }
  }
  count
}

///|
/// Copy a source canvas with alpha compositing and clipping.
pub fn Canvas::blit(
  self : Canvas,
  source : Canvas,
  destination_x~ : Int,
  destination_y~ : Int,
) -> Int {
  let mut count = 0
  for y in 0..<source.height {
    for x in 0..<source.width {
      match source.get(x~, y~) {
        None => ()
        Some(color) =>
          if self.blend_pixel(x=destination_x + x, y=destination_y + y, color~) {
            count += 1
          }
      }
    }
  }
  count
}

///|
/// Crop a rectangle. Pixels outside the source are filled with transparent black.
pub fn Canvas::crop(
  self : Canvas,
  x~ : Int,
  y~ : Int,
  width~ : Int,
  height~ : Int,
) -> Canvas {
  if width < 0 || height < 0 {
    panic()
  }
  let result = Canvas::new(width~, height~, fill=rgba(0, 0, 0, 0))
  for row in 0..<height {
    for column in 0..<width {
      match self.get(x=x + column, y=y + row) {
        None => ()
        Some(color) => ignore(result.set(x=column, y=row, color~))
      }
    }
  }
  result
}

///|
/// Resize with nearest-neighbor sampling, suitable for pixel art and thumbnails.
pub fn Canvas::resize_nearest(
  self : Canvas,
  width~ : Int,
  height~ : Int,
) -> Canvas {
  if width < 0 || height < 0 {
    panic()
  }
  let result = Canvas::new(width~, height~, fill=rgba(0, 0, 0, 0))
  if width > 0 && height > 0 && self.width > 0 && self.height > 0 {
    for y in 0..<height {
      let source_y = y * self.height / height
      for x in 0..<width {
        let source_x = x * self.width / width
        result.pixels[x + y * width] = self.pixels[source_x +
          source_y * self.width]
      }
    }
  }
  result
}

///|
/// Return a horizontally mirrored copy.
pub fn Canvas::flip_horizontal(self : Canvas) -> Canvas {
  let result = Canvas::new(
    width=self.width,
    height=self.height,
    fill=rgba(0, 0, 0, 0),
  )
  for y in 0..<self.height {
    for x in 0..<self.width {
      result.pixels[self.width - x - 1 + y * self.width] = self.pixels[x +
        y * self.width]
    }
  }
  result
}

///|
/// Return a vertically mirrored copy.
pub fn Canvas::flip_vertical(self : Canvas) -> Canvas {
  let result = Canvas::new(
    width=self.width,
    height=self.height,
    fill=rgba(0, 0, 0, 0),
  )
  for y in 0..<self.height {
    for x in 0..<self.width {
      result.pixels[x + (self.height - y - 1) * self.width] = self.pixels[x +
        y * self.width]
    }
  }
  result
}

///|
/// Replace every exact color match and return the number of changed pixels.
pub fn Canvas::replace_color(self : Canvas, from~ : Rgba, to~ : Rgba) -> Int {
  let mut count = 0
  for i in 0..<self.pixels.length() {
    if self.pixels[i] == from {
      self.pixels[i] = to
      count += 1
    }
  }
  count
}

///|
/// Count exact pixel matches.
pub fn Canvas::count_color(self : Canvas, color : Rgba) -> Int {
  let mut count = 0
  for value in self.pixels {
    if value == color {
      count += 1
    }
  }
  count
}

///|
/// Return true when every pixel has an opaque alpha channel.
pub fn Canvas::is_opaque(self : Canvas) -> Bool {
  let mut result = true
  for color in self.pixels {
    if color.alpha() != 255 {
      result = false
    }
  }
  result
}

///|
/// Serialize pixels as tightly packed RGBA bytes.
pub fn Canvas::to_rgba_bytes(self : Canvas) -> Bytes {
  let bytes : Array[Byte] = []
  for color in self.pixels {
    bytes.push(color.red())
    bytes.push(color.green())
    bytes.push(color.blue())
    bytes.push(color.alpha())
  }
  Bytes::from_array(bytes[:])
}

///|
/// Construct a canvas from tightly packed RGBA bytes.
pub fn canvas_from_rgba_bytes(
  width~ : Int,
  height~ : Int,
  bytes : Bytes,
) -> Canvas raise GifError {
  if width < 0 || height < 0 || bytes.length() != width * height * 4 {
    raise InvalidBlock(
      context="RGBA byte length does not match canvas dimensions",
    )
  }
  let pixels : Array[Rgba] = []
  for i in 0..<(width * height) {
    let offset = i * 4
    pixels.push(
      rgba(
        bytes[offset],
        bytes[offset + 1],
        bytes[offset + 2],
        bytes[offset + 3],
      ),
    )
  }
  Canvas::{ width, height, pixels }
}

///|
/// Count pixels that differ between two canvases.
pub fn pixel_difference(left : Canvas, right : Canvas) -> Int {
  if left.width != right.width || left.height != right.height {
    left.width * left.height + right.width * right.height
  } else {
    let mut count = 0
    for i in 0..<left.pixels.length() {
      if left.pixels[i] != right.pixels[i] {
        count += 1
      }
    }
    count
  }
}
