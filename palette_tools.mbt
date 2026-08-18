///|
/// Palette selection mode for quantized frames.
pub(all) enum DitherMode {
  NoDither
  Ordered2x2
  FloydSteinberg
} derive(Eq, Debug)

///|
pub fn Palette::nearest(self : Palette, color : Rgba) -> Int {
  nearest_palette_index(color, self.colors)
}

///|
pub fn Palette::contains(self : Palette, color : Rgba) -> Bool {
  let mut found = false
  for value in self.colors {
    if value == color {
      found = true
    }
  }
  found
}

///|
/// Serialize an RGB color table without GIF sub-block framing.
pub fn Palette::to_rgb_bytes(self : Palette, table_size~ : Int) -> Bytes {
  let size = if table_size < self.colors.length() {
    self.colors.length()
  } else {
    table_size
  }
  let bytes : Array[Byte] = []
  for i in 0..<size {
    match self.color(i) {
      None => {
        bytes.push(0)
        bytes.push(0)
        bytes.push(0)
      }
      Some(color) => {
        bytes.push(color.red())
        bytes.push(color.green())
        bytes.push(color.blue())
      }
    }
  }
  Bytes::from_array(bytes[:])
}

///|
fn dithered_color(color : Rgba, x : Int, y : Int, mode : DitherMode) -> Rgba {
  match mode {
    NoDither | FloydSteinberg => color
    Ordered2x2 => {
      let matrix = [[0, 2], [3, 1]]
      let amount = (matrix[y % 2][x % 2] - 1) * 16
      rgba(
        clamp_byte_int(color.red().to_int() + amount),
        clamp_byte_int(color.green().to_int() + amount),
        clamp_byte_int(color.blue().to_int() + amount),
        color.alpha(),
      )
    }
  }
}

///|
fn add_error(
  values : Array[Int],
  index : Int,
  error : Int,
  numerator : Int,
) -> Unit {
  values[index] += error * numerator / 16
}

///|
fn quantize_floyd(
  canvas : Canvas,
  base : QuantizedFrame,
  transparent : Rgba?,
) -> QuantizedFrame {
  let palette = base.palette()
  let indices : Array[Byte] = Array::make(canvas.width * canvas.height, b'\x00')
  let mut current_r = Array::make(canvas.width + 2, 0)
  let mut current_g = Array::make(canvas.width + 2, 0)
  let mut current_b = Array::make(canvas.width + 2, 0)
  let mut next_r = Array::make(canvas.width + 2, 0)
  let mut next_g = Array::make(canvas.width + 2, 0)
  let mut next_b = Array::make(canvas.width + 2, 0)
  for y in 0..<canvas.height {
    for x in 0..<canvas.width {
      let color = canvas.pixels[x + y * canvas.width]
      if transparent is Some(t) && color == t {
        match palette.transparent_index() {
          None => ()
          Some(index) => indices[x + y * canvas.width] = index.to_byte()
        }
      } else {
        let adjusted = rgba(
          clamp_byte_int(color.red().to_int() + current_r[x + 1]),
          clamp_byte_int(color.green().to_int() + current_g[x + 1]),
          clamp_byte_int(color.blue().to_int() + current_b[x + 1]),
          color.alpha(),
        )
        let index = palette.nearest(adjusted)
        indices[x + y * canvas.width] = index.to_byte()
        let chosen = palette.colors[index]
        let error_r = adjusted.red().to_int() - chosen.red().to_int()
        let error_g = adjusted.green().to_int() - chosen.green().to_int()
        let error_b = adjusted.blue().to_int() - chosen.blue().to_int()
        add_error(current_r, x + 2, error_r, 7)
        add_error(current_g, x + 2, error_g, 7)
        add_error(current_b, x + 2, error_b, 7)
        add_error(next_r, x, error_r, 3)
        add_error(next_g, x, error_g, 3)
        add_error(next_b, x, error_b, 3)
        add_error(next_r, x + 1, error_r, 5)
        add_error(next_g, x + 1, error_g, 5)
        add_error(next_b, x + 1, error_b, 5)
        add_error(next_r, x + 2, error_r, 1)
        add_error(next_g, x + 2, error_g, 1)
        add_error(next_b, x + 2, error_b, 1)
      }
    }
    let old_r = current_r
    let old_g = current_g
    let old_b = current_b
    current_r = next_r
    current_g = next_g
    current_b = next_b
    next_r = old_r
    next_g = old_g
    next_b = old_b
    for i in 0..<next_r.length() {
      next_r[i] = 0
      next_g[i] = 0
      next_b[i] = 0
    }
  }
  QuantizedFrame::{ palette, indices }
}

///|
/// Quantize with optional ordered or Floyd-Steinberg error diffusion.
pub fn quantize_dithered(
  canvas : Canvas,
  max_colors : Int,
  transparent : Rgba?,
  mode : DitherMode,
) -> QuantizedFrame {
  let base = match transparent {
    None => quantize(canvas, max_colors~)
    Some(color) => quantize(canvas, max_colors~, transparent=color)
  }
  match mode {
    NoDither => base
    Ordered2x2 => {
      let palette = base.palette()
      let indices : Array[Byte] = []
      for y in 0..<canvas.height {
        for x in 0..<canvas.width {
          let color = canvas.pixels[x + y * canvas.width]
          match transparent {
            Some(t) if color == t =>
              indices.push(palette.transparent_index().unwrap_or(0).to_byte())
            _ =>
              indices.push(
                palette.nearest(dithered_color(color, x, y, mode)).to_byte(),
              )
          }
        }
      }
      QuantizedFrame::{ palette, indices }
    }
    FloydSteinberg => quantize_floyd(canvas, base, transparent)
  }
}
