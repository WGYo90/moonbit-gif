///|
/// A rectangular patch containing pixels that differ from a previous canvas.
pub(all) struct PixelPatch {
  rect : GifRect
  pixels : Array[Rgba]
} derive(Debug)

///|
pub fn PixelPatch::rect(self : PixelPatch) -> GifRect {
  self.rect
}

///|
pub fn PixelPatch::pixels(self : PixelPatch) -> ArrayView[Rgba] {
  self.pixels[:]
}

///|
pub fn PixelPatch::pixel_count(self : PixelPatch) -> Int {
  self.pixels.length()
}

///|
pub fn PixelPatch::area(self : PixelPatch) -> Int {
  self.rect.area()
}

///|
pub fn PixelPatch::is_empty(self : PixelPatch) -> Bool {
  self.pixels.length() == 0
}

///|
/// Extract a changed rectangle from `source` relative to `base`.
pub fn Canvas::diff_patch(
  self : Canvas,
  base : Canvas,
  threshold? : Int = 0,
) -> PixelPatch? {
  match changed_rect(base, self, threshold) {
    None => None
    Some(rect) => {
      let pixels : Array[Rgba] = []
      for y in 0..<rect.height() {
        for x in 0..<rect.width() {
          match self.get(x=rect.left() + x, y=rect.top() + y) {
            None => pixels.push(rgba(0, 0, 0, 0))
            Some(color) => pixels.push(color)
          }
        }
      }
      Some(PixelPatch::{ rect, pixels })
    }
  }
}

///|
/// Apply a patch with clipping and alpha compositing.
pub fn Canvas::apply_patch(self : Canvas, patch : PixelPatch) -> Int {
  let rect = patch.rect
  let mut written = 0
  for y in 0..<rect.height() {
    for x in 0..<rect.width() {
      let destination_x = rect.left() + x
      let destination_y = rect.top() + y
      if destination_x >= 0 &&
        destination_y >= 0 &&
        destination_x < self.width &&
        destination_y < self.height {
        let source = patch.pixels[x + y * rect.width()]
        if self.blend_pixel(x=destination_x, y=destination_y, color=source) {
          written += 1
        }
      }
    }
  }
  written
}

///|
/// Apply a patch by replacing pixels rather than alpha blending.
pub fn Canvas::write_patch(self : Canvas, patch : PixelPatch) -> Int {
  let rect = patch.rect
  let mut written = 0
  for y in 0..<rect.height() {
    for x in 0..<rect.width() {
      if self.set(
          x=rect.left() + x,
          y=rect.top() + y,
          color=patch.pixels[x + y * rect.width()],
        ) {
        written += 1
      }
    }
  }
  written
}

///|
/// Rebuild a full canvas by applying patches to a background.
pub fn apply_patches(
  width~ : Int,
  height~ : Int,
  background~ : Rgba,
  patches : ArrayView[PixelPatch],
) -> Canvas {
  let result = Canvas::new(width~, height~, fill=background)
  for patch in patches {
    ignore(result.write_patch(patch))
  }
  result
}

///|
pub(all) struct PatchFrame {
  patch : PixelPatch
  delay_cs : Int
} derive(Debug)

///|
pub fn PatchFrame::patch(self : PatchFrame) -> PixelPatch {
  self.patch
}

///|
pub fn PatchFrame::delay_cs(self : PatchFrame) -> Int {
  self.delay_cs
}

///|
/// Compute one patch per frame, using the logical background as the first base.
pub fn Animation::patch_frames(
  self : Animation,
  threshold? : Int = 0,
) -> Array[PatchFrame] {
  let result : Array[PatchFrame] = []
  let mut previous = self.background_canvas()
  for frame in self.frames {
    match frame.canvas.diff_patch(previous, threshold~) {
      None => {
        let empty = PixelPatch::{
          rect: GifRect::new(left=0, top=0, width=0, height=0),
          pixels: [],
        }
        result.push(PatchFrame::{ patch: empty, delay_cs: frame.delay_cs })
      }
      Some(patch) =>
        result.push(PatchFrame::{ patch, delay_cs: frame.delay_cs })
    }
    previous = frame.canvas
  }
  result
}

///|
/// Reconstruct full frames from patch frames.
pub fn animation_from_patches(
  width~ : Int,
  height~ : Int,
  background~ : Rgba,
  patches : ArrayView[PatchFrame],
  loop_count? : Int? = Some(0),
) -> Animation {
  let frames : Array[Frame] = []
  let current = Canvas::new(width~, height~, fill=background)
  for patch_frame in patches {
    if !patch_frame.patch.is_empty() {
      ignore(current.write_patch(patch_frame.patch))
    }
    frames.push(
      Frame::new(canvas=current.copy(), delay_cs=patch_frame.delay_cs),
    )
  }
  Animation::{ width, height, frames, loop_count, background }
}

///|
/// Return a patch suitable for a GIF local image descriptor.
pub fn PixelPatch::as_frame(self : PixelPatch, delay_cs~ : Int) -> Frame {
  let canvas = Canvas::new(
    width=self.rect.width(),
    height=self.rect.height(),
    fill=rgba(0, 0, 0, 0),
  )
  for y in 0..<self.rect.height() {
    for x in 0..<self.rect.width() {
      canvas.pixels[x + y * self.rect.width()] = self.pixels[x +
        y * self.rect.width()]
    }
  }
  Frame::new(canvas~, delay_cs~).with_offset(
    left=self.rect.left(),
    top=self.rect.top(),
  )
}

///|
/// Estimate the patch ratio of an animation in per mille.
pub fn Animation::patch_density(self : Animation, threshold? : Int = 0) -> Int {
  let patches = self.patch_frames(threshold~)
  let full = self.width * self.height * patches.length()
  if full == 0 {
    0
  } else {
    let mut changed = 0
    for item in patches {
      changed += item.patch.area()
    }
    changed * 1000 / full
  }
}
