///|
fn copy_canvas(canvas : Canvas) -> Canvas {
  let copy = Canvas::new(
    width=canvas.width,
    height=canvas.height,
    fill=rgb(0, 0, 0),
  )
  for i, color in canvas.pixels {
    copy.pixels[i] = color
  }
  copy
}

///|
fn clear_canvas_rect(
  canvas : Canvas,
  left : Int,
  top : Int,
  width : Int,
  height : Int,
  fill : Rgba,
) -> Unit {
  for y in 0..<height {
    for x in 0..<width {
      ignore(canvas.set(x=left + x, y=top + y, color=fill))
    }
  }
}

///|
fn draw_frame(canvas : Canvas, frame : Frame) -> Unit {
  let source = frame.canvas
  let (left, top) = frame.offset()
  for y in 0..<source.height {
    for x in 0..<source.width {
      match source.get(x~, y~) {
        None => ()
        Some(color) => {
          let matches_transparent = match frame.transparent {
            None => false
            Some(t) => color == t
          }
          let transparent = color.alpha() == 0 || matches_transparent
          if !transparent {
            ignore(canvas.set(x=left + x, y=top + y, color~))
          }
        }
      }
    }
  }
}

///|
/// Compose frames in display order and apply GIF disposal semantics.
///
/// The returned canvases are independent snapshots, so callers can render or
/// compare them without mutating later frames. `Background` clears only the
/// frame rectangle; `Previous` restores the canvas from before the frame.
pub fn compose(animation : Animation) -> Array[Canvas] {
  let current = Canvas::new(
    width=animation.width,
    height=animation.height,
    fill=animation.background,
  )
  let rendered : Array[Canvas] = []
  for frame in animation.frames {
    let before = copy_canvas(current)
    draw_frame(current, frame)
    rendered.push(copy_canvas(current))
    let (left, top) = frame.offset()
    match frame.disposal {
      Keep => ()
      Background =>
        clear_canvas_rect(
          current,
          left,
          top,
          frame.canvas.width,
          frame.canvas.height,
          animation.background,
        )
      Previous =>
        for i, color in before.pixels {
          current.pixels[i] = color
        }
    }
  }
  rendered
}

///|
pub fn Canvas::copy(self : Canvas) -> Canvas {
  copy_canvas(self)
}
