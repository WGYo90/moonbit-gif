///|
/// A compact GIF color table and the optional transparent entry.
pub(all) struct Palette {
  colors : Array[Rgba]
  transparent_index : Int?
} derive(Debug)

///|
pub fn Palette::new(
  colors~ : Array[Rgba],
  transparent_index~ : Int?,
) -> Palette {
  if colors.length() == 0 || colors.length() > 256 {
    panic()
  }
  { colors, transparent_index }
}

///|
pub fn Palette::len(self : Palette) -> Int {
  self.colors.length()
}

///|
pub fn Palette::color(self : Palette, index : Int) -> Rgba? {
  if index < 0 || index >= self.colors.length() {
    None
  } else {
    Some(self.colors[index])
  }
}

///|
pub fn Palette::colors(self : Palette) -> ArrayView[Rgba] {
  self.colors[:]
}

///|
pub fn Palette::transparent_index(self : Palette) -> Int? {
  self.transparent_index
}

///|
/// Quantized pixels plus the palette used to encode them.
pub(all) struct QuantizedFrame {
  palette : Palette
  indices : Array[Byte]
} derive(Debug)

///|
pub fn QuantizedFrame::palette(self : QuantizedFrame) -> Palette {
  self.palette
}

///|
pub fn QuantizedFrame::indices(self : QuantizedFrame) -> ArrayView[Byte] {
  self.indices[:]
}

///|
struct PaletteSample {
  color : Rgba
  weight : Int
} derive(Debug)

///|
struct ColorBox {
  start : Int
  end : Int
} derive(Debug)

///|
fn color_key(color : Rgba) -> Int {
  (color.red().to_int() >> 3 << 10) |
  (color.green().to_int() >> 3 << 5) |
  (color.blue().to_int() >> 3)
}

///|
fn add_histogram_color(
  histogram : Map[Int, (Int, Int, Int, Int)],
  color : Rgba,
) -> Unit {
  let key = color_key(color)
  match histogram.get(key) {
    None =>
      histogram[key] = (
        color.red().to_int(),
        color.green().to_int(),
        color.blue().to_int(),
        1,
      )
    Some((r, g, b, count)) =>
      histogram[key] = (
        r + color.red().to_int(),
        g + color.green().to_int(),
        b + color.blue().to_int(),
        count + 1,
      )
  }
}

///|
fn histogram_samples(
  canvas : Canvas,
  transparent : Rgba?,
) -> Array[PaletteSample] {
  let histogram : Map[Int, (Int, Int, Int, Int)] = Map([])
  for color in canvas.pixels {
    if transparent is Some(t) && color == t {
      continue
    }
    add_histogram_color(histogram, color)
  }
  let samples : Array[PaletteSample] = []
  for _, value in histogram {
    match value {
      (r, g, b, count) =>
        samples.push(PaletteSample::{
          color: rgba(
            (r / count).to_byte(),
            (g / count).to_byte(),
            (b / count).to_byte(),
            0xff,
          ),
          weight: count,
        })
    }
  }
  samples
}

///|
fn channel_value(color : Rgba, channel : Int) -> Int {
  match channel {
    0 => color.red().to_int()
    1 => color.green().to_int()
    _ => color.blue().to_int()
  }
}

///|
fn box_channel(box : ColorBox, samples : Array[PaletteSample]) -> Int {
  let mut min_r = 255
  let mut max_r = 0
  let mut min_g = 255
  let mut max_g = 0
  let mut min_b = 255
  let mut max_b = 0
  for i in box.start..<box.end {
    let color = samples[i].color
    let r = color.red().to_int()
    let g = color.green().to_int()
    let b = color.blue().to_int()
    if r < min_r {
      min_r = r
    }
    if r > max_r {
      max_r = r
    }
    if g < min_g {
      min_g = g
    }
    if g > max_g {
      max_g = g
    }
    if b < min_b {
      min_b = b
    }
    if b > max_b {
      max_b = b
    }
  }
  let rr = max_r - min_r
  let gg = max_g - min_g
  let bb = max_b - min_b
  if rr >= gg && rr >= bb {
    0
  } else if gg >= bb {
    1
  } else {
    2
  }
}

///|
fn box_volume(box : ColorBox, samples : Array[PaletteSample]) -> Int {
  if box.start >= box.end {
    0
  } else {
    let mut min_r = 255
    let mut max_r = 0
    let mut min_g = 255
    let mut max_g = 0
    let mut min_b = 255
    let mut max_b = 0
    for i in box.start..<box.end {
      let color = samples[i].color
      let r = color.red().to_int()
      let g = color.green().to_int()
      let b = color.blue().to_int()
      if r < min_r {
        min_r = r
      }
      if r > max_r {
        max_r = r
      }
      if g < min_g {
        min_g = g
      }
      if g > max_g {
        max_g = g
      }
      if b < min_b {
        min_b = b
      }
      if b > max_b {
        max_b = b
      }
    }
    (max_r - min_r + 1) * (max_g - min_g + 1) * (max_b - min_b + 1)
  }
}

///|
fn sort_samples(
  samples : Array[PaletteSample],
  start : Int,
  end : Int,
  channel : Int,
) -> Unit {
  if end - start < 2 {
    return
  }
  for i in (start + 1)..<end {
    let item = samples[i]
    let mut j = i
    while j > start &&
          channel_value(samples[j - 1].color, channel) >
          channel_value(item.color, channel) {
      samples[j] = samples[j - 1]
      j -= 1
    }
    samples[j] = item
  }
}

///|
fn split_box(
  box : ColorBox,
  samples : Array[PaletteSample],
) -> (ColorBox, ColorBox)? {
  if box.end - box.start < 2 {
    return None
  }
  let channel = box_channel(box, samples)
  sort_samples(samples, box.start, box.end, channel)
  let mut total = 0
  for i in box.start..<box.end {
    total += samples[i].weight
  }
  let target = (total + 1) / 2
  let mut seen = 0
  let mut split = box.start + 1
  while split < box.end - 1 && seen < target {
    seen += samples[split - 1].weight
    split += 1
  }
  if split <= box.start || split >= box.end {
    None
  } else {
    Some(
      (
        ColorBox::{ start: box.start, end: split },
        ColorBox::{ start: split, end: box.end },
      ),
    )
  }
}

///|
fn average_box(box : ColorBox, samples : Array[PaletteSample]) -> Rgba {
  let mut r = 0
  let mut g = 0
  let mut b = 0
  let mut total = 0
  for i in box.start..<box.end {
    let sample = samples[i]
    r += sample.color.red().to_int() * sample.weight
    g += sample.color.green().to_int() * sample.weight
    b += sample.color.blue().to_int() * sample.weight
    total += sample.weight
  }
  if total == 0 {
    rgb(0, 0, 0)
  } else {
    rgb((r / total).to_byte(), (g / total).to_byte(), (b / total).to_byte())
  }
}

///|
fn nearest_palette_index(color : Rgba, palette : Array[Rgba]) -> Int {
  let mut best = 0
  let mut best_distance = 1_000_000_000
  for i, candidate in palette {
    let dr = color.red().to_int() - candidate.red().to_int()
    let dg = color.green().to_int() - candidate.green().to_int()
    let db = color.blue().to_int() - candidate.blue().to_int()
    let distance = dr * dr + dg * dg + db * db
    if distance < best_distance {
      best = i
      best_distance = distance
    }
  }
  best
}

///|
/// Quantize an RGBA canvas with a Median Cut palette.
///
/// `max_colors` is clamped to the GIF range of 2..256. Transparent pixels are
/// removed before quantization and receive a dedicated palette entry.
pub fn quantize(
  canvas : Canvas,
  max_colors? : Int = 256,
  transparent? : Rgba,
) -> QuantizedFrame {
  let transparent = transparent
  let budget = if transparent is Some(_) { max_colors - 1 } else { max_colors }
  let target = if budget < 2 { 2 } else if budget > 256 { 256 } else { budget }
  let samples = histogram_samples(canvas, transparent)
  let palette_colors : Array[Rgba] = []
  if samples.length() == 0 {
    palette_colors.push(rgb(0, 0, 0))
  } else {
    let boxes : Array[ColorBox] = [
      ColorBox::{ start: 0, end: samples.length() },
    ]
    while boxes.length() < target {
      let mut selected = -1
      let mut selected_score = -1
      for i, box in boxes {
        let score = box_volume(box, samples) * (box.end - box.start)
        if score > selected_score && box.end - box.start > 1 {
          selected = i
          selected_score = score
        }
      }
      if selected < 0 {
        break
      }
      match split_box(boxes[selected], samples) {
        None => break
        Some((left, right)) => {
          boxes[selected] = left
          boxes.push(right)
        }
      }
    }
    for box in boxes {
      palette_colors.push(average_box(box, samples))
    }
  }
  let transparent_index = match transparent {
    None => None
    Some(color) => {
      palette_colors.push(color)
      Some(palette_colors.length() - 1)
    }
  }
  let palette = Palette::{ colors: palette_colors, transparent_index }
  let indices : Array[Byte] = []
  for color in canvas.pixels {
    match transparent_index {
      Some(_) if transparent is Some(t) && color == t =>
        indices.push((palette.colors.length() - 1).to_byte())
      _ => indices.push(nearest_palette_index(color, palette.colors).to_byte())
    }
  }
  QuantizedFrame::{ palette, indices }
}
