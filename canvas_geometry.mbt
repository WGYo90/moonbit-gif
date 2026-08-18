///|
/// A geometric transform that preserves the pixel grid.
pub(all) enum CanvasRotation {
  Clockwise90
  HalfTurn
  Clockwise270
} derive(Eq, Debug)

///|
/// Rotate a canvas without interpolation.
pub fn Canvas::rotate(self : Canvas, rotation : CanvasRotation) -> Canvas {
  match rotation {
    Clockwise90 => self.rotate90()
    HalfTurn => self.rotate180()
    Clockwise270 => self.rotate270()
  }
}

///|
/// Rotate clockwise. The old top-left pixel becomes the top-right pixel.
pub fn Canvas::rotate90(self : Canvas) -> Canvas {
  let result = Canvas::new(
    width=self.height,
    height=self.width,
    fill=rgba(0, 0, 0, 0),
  )
  for y in 0..<self.height {
    for x in 0..<self.width {
      result.pixels[self.height - y - 1 + x * result.width] = self.pixels[x +
        y * self.width]
    }
  }
  result
}

///|
/// Rotate by 180 degrees.
pub fn Canvas::rotate180(self : Canvas) -> Canvas {
  let result = Canvas::new(
    width=self.width,
    height=self.height,
    fill=rgba(0, 0, 0, 0),
  )
  for y in 0..<self.height {
    for x in 0..<self.width {
      result.pixels[self.width - x - 1 + (self.height - y - 1) * self.width] = self.pixels[x +
        y * self.width]
    }
  }
  result
}

///|
/// Rotate counter-clockwise, or equivalently three clockwise turns.
pub fn Canvas::rotate270(self : Canvas) -> Canvas {
  let result = Canvas::new(
    width=self.height,
    height=self.width,
    fill=rgba(0, 0, 0, 0),
  )
  for y in 0..<self.height {
    for x in 0..<self.width {
      result.pixels[y + (self.width - x - 1) * result.width] = self.pixels[x +
        y * self.width]
    }
  }
  result
}

///|
/// Add transparent or colored margins around a canvas.
pub fn Canvas::pad(
  self : Canvas,
  left~ : Int,
  top~ : Int,
  right~ : Int,
  bottom~ : Int,
  fill? : Rgba = rgba(0, 0, 0, 0),
) -> Canvas {
  if left < 0 || top < 0 || right < 0 || bottom < 0 {
    panic()
  }
  let result = Canvas::new(
    width=left + self.width + right,
    height=top + self.height + bottom,
    fill~,
  )
  for y in 0..<self.height {
    for x in 0..<self.width {
      result.pixels[x + left + (y + top) * result.width] = self.pixels[x +
        y * self.width]
    }
  }
  result
}

///|
/// Return a copy with every alpha channel multiplied by `alpha`.
pub fn Canvas::scale_alpha(self : Canvas, alpha : Byte) -> Canvas {
  let result = self.copy()
  for i in 0..<result.pixels.length() {
    let old = result.pixels[i]
    result.pixels[i] = rgba(
      old.red(),
      old.green(),
      old.blue(),
      (old.alpha().to_int() * alpha.to_int() / 255).to_byte(),
    )
  }
  result
}

///|
/// Replace transparent pixels with `fill`, keeping all visible pixels.
pub fn Canvas::flatten_alpha(self : Canvas, fill~ : Rgba) -> Canvas {
  let result = self.copy()
  for i in 0..<result.pixels.length() {
    let color = result.pixels[i]
    if color.alpha() == 0 {
      result.pixels[i] = fill
    } else if color.alpha() != 255 {
      result.pixels[i] = blend_rgba(color, fill)
    }
  }
  result
}

///|
/// Find the non-transparent bounds of a canvas.
pub fn Canvas::opaque_bounds(
  self : Canvas,
  alpha_threshold? : Byte = 1,
) -> GifRect? {
  let mut min_x = self.width
  let mut min_y = self.height
  let mut max_x = -1
  let mut max_y = -1
  for y in 0..<self.height {
    for x in 0..<self.width {
      if self.pixels[x + y * self.width].alpha() >= alpha_threshold {
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
    Some(
      GifRect::new(
        left=min_x,
        top=min_y,
        width=max_x - min_x + 1,
        height=max_y - min_y + 1,
      ),
    )
  }
}

///|
/// Crop transparent margins. An empty canvas returns a 1x1 transparent canvas.
pub fn Canvas::trim_transparent(
  self : Canvas,
  alpha_threshold? : Byte = 1,
) -> Canvas {
  match self.opaque_bounds(alpha_threshold~) {
    None => Canvas::new(width=1, height=1, fill=rgba(0, 0, 0, 0))
    Some(bounds) =>
      self.crop(
        x=bounds.left(),
        y=bounds.top(),
        width=bounds.width(),
        height=bounds.height(),
      )
  }
}

///|
/// Composite a source image over this canvas at an offset.
pub fn Canvas::overlay(
  self : Canvas,
  source : Canvas,
  left~ : Int,
  top~ : Int,
) -> Canvas {
  let result = self.copy()
  ignore(result.blit(source, destination_x=left, destination_y=top))
  result
}

///|
/// Create a tiled checkerboard useful as a transparency preview background.
pub fn checkerboard_canvas(
  width~ : Int,
  height~ : Int,
  cell_size? : Int = 8,
  light? : Rgba = rgb(238, 238, 238),
  dark? : Rgba = rgb(204, 204, 204),
) -> Canvas {
  if width < 0 || height < 0 || cell_size <= 0 {
    panic()
  }
  let result = Canvas::new(width~, height~, fill=light)
  for y in 0..<height {
    for x in 0..<width {
      if (x / cell_size + y / cell_size) % 2 == 1 {
        result.pixels[x + y * width] = dark
      }
    }
  }
  result
}

///|
/// Place a canvas over a checkerboard transparency preview.
pub fn Canvas::preview(self : Canvas, cell_size? : Int = 8) -> Canvas {
  checkerboard_canvas(width=self.width, height=self.height, cell_size~).overlay(
    self,
    left=0,
    top=0,
  )
}

///|
/// Nearest-neighbor scale to fit inside a box, preserving aspect ratio.
pub fn Canvas::contain(
  self : Canvas,
  width~ : Int,
  height~ : Int,
  fill? : Rgba = rgba(0, 0, 0, 0),
) -> Canvas {
  if width < 0 || height < 0 {
    panic()
  }
  if self.width == 0 || self.height == 0 || width == 0 || height == 0 {
    Canvas::new(width~, height~, fill~)
  } else {
    let by_width = width * self.height / self.width
    let scaled_width = if by_width <= height {
      width
    } else {
      height * self.width / self.height
    }
    let scaled_height = if by_width <= height { by_width } else { height }
    let scaled = self.resize_nearest(width=scaled_width, height=scaled_height)
    let result = Canvas::new(width~, height~, fill~)
    let left = (width - scaled_width) / 2
    let top = (height - scaled_height) / 2
    ignore(result.blit(scaled, destination_x=left, destination_y=top))
    result
  }
}

///|
/// Nearest-neighbor scale to cover a box, cropping the overflow.
pub fn Canvas::cover(self : Canvas, width~ : Int, height~ : Int) -> Canvas {
  if width < 0 || height < 0 {
    panic()
  }
  if self.width == 0 || self.height == 0 || width == 0 || height == 0 {
    Canvas::new(width~, height~, fill=rgba(0, 0, 0, 0))
  } else {
    let by_width = width * self.height / self.width
    let scaled_width = if by_width >= height {
      width
    } else {
      height * self.width / self.height
    }
    let scaled_height = if by_width >= height { by_width } else { height }
    let scaled = self.resize_nearest(width=scaled_width, height=scaled_height)
    let left = (scaled_width - width) / 2
    let top = (scaled_height - height) / 2
    scaled.crop(x=left, y=top, width~, height~)
  }
}

///|
/// Return the four corner colors in clockwise order.
pub fn Canvas::corners(self : Canvas) -> Array[Rgba] {
  if self.width == 0 || self.height == 0 {
    []
  } else {
    [
      self.pixels[0],
      self.pixels[self.width - 1],
      self.pixels[(self.height - 1) * self.width + self.width - 1],
      self.pixels[(self.height - 1) * self.width],
    ]
  }
}

///|
/// Return a clipped rectangle as a value suitable for frame metadata.
pub fn Canvas::bounds(self : Canvas) -> GifRect {
  GifRect::new(left=0, top=0, width=self.width, height=self.height)
}
