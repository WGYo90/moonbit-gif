///|
/// A resolved position on an animation timeline.
pub(all) struct TimelinePosition {
  index : Int
  elapsed_cs : Int
  remaining_cs : Int
} derive(Eq, Debug)

///|
pub fn TimelinePosition::index(self : TimelinePosition) -> Int {
  self.index
}

///|
pub fn TimelinePosition::elapsed_cs(self : TimelinePosition) -> Int {
  self.elapsed_cs
}

///|
pub fn TimelinePosition::remaining_cs(self : TimelinePosition) -> Int {
  self.remaining_cs
}

///|
/// Validate dimensions, offsets, delays, and GIF representability.
pub fn Animation::validate(self : Animation) -> Array[String] {
  let issues : Array[String] = []
  if self.width <= 0 || self.height <= 0 {
    issues.push("logical screen must have positive dimensions")
  }
  if self.width > 65535 || self.height > 65535 {
    issues.push("logical screen exceeds GIF's 16-bit dimension limit")
  }
  if self.loop_count is Some(value) && (value < 0 || value > 65535) {
    issues.push("loop count must be between 0 and 65535")
  }
  for index, frame in self.frames {
    if frame.canvas.width <= 0 || frame.canvas.height <= 0 {
      issues.push("frame \{index} has an empty canvas")
    }
    if frame.canvas.width > 65535 || frame.canvas.height > 65535 {
      issues.push("frame \{index} exceeds GIF's 16-bit image limit")
    }
    if frame.delay_cs < 0 || frame.delay_cs > 65535 {
      issues.push("frame \{index} delay is outside the GIF range")
    }
    if frame.left < 0 ||
      frame.top < 0 ||
      frame.left + frame.canvas.width > self.width ||
      frame.top + frame.canvas.height > self.height {
      issues.push("frame \{index} lies outside the logical screen")
    }
  }
  issues
}

///|
/// Return the frame occupying a centisecond position, with loop handling.
pub fn Animation::position_at(
  self : Animation,
  time_cs : Int,
) -> TimelinePosition? {
  if self.frames.length() == 0 {
    None
  } else {
    let duration = self.duration_cs()
    let safe_time = if time_cs < 0 { 0 } else { time_cs }
    let timeline_time = if duration <= 0 { 0 } else { safe_time % duration }
    let mut elapsed = 0
    let mut result : TimelinePosition? = None
    for index, frame in self.frames {
      let delay = if frame.delay_cs <= 0 { 1 } else { frame.delay_cs }
      if result is None && timeline_time < elapsed + delay {
        result = Some(TimelinePosition::{
          index,
          elapsed_cs: timeline_time - elapsed,
          remaining_cs: elapsed + delay - timeline_time,
        })
      }
      elapsed += delay
    }
    match result {
      Some(position) => Some(position)
      None =>
        Some(TimelinePosition::{
          index: self.frames.length() - 1,
          elapsed_cs: 0,
          remaining_cs: 0,
        })
    }
  }
}

///|
/// Return the frame visible at a centisecond position.
pub fn Animation::frame_at(self : Animation, time_cs : Int) -> Frame? {
  match self.position_at(time_cs) {
    None => None
    Some(position) => Some(self.frames[position.index])
  }
}

///|
/// Return the frame indices at every timeline boundary.
pub fn Animation::timeline_indices(self : Animation) -> Array[Int] {
  let result : Array[Int] = []
  for index, _ in self.frames {
    result.push(index)
  }
  result
}

///|
/// Return cumulative frame start times in centiseconds.
pub fn Animation::timeline_starts(self : Animation) -> Array[Int] {
  let result : Array[Int] = []
  let mut elapsed = 0
  for frame in self.frames {
    result.push(elapsed)
    elapsed += if frame.delay_cs <= 0 { 1 } else { frame.delay_cs }
  }
  result
}

///|
/// Replace zero-delay frames with a visible default delay.
pub fn Animation::normalize_delays(
  self : Animation,
  default_delay_cs? : Int = 1,
) -> Animation {
  let safe_delay = if default_delay_cs <= 0 {
    1
  } else if default_delay_cs > 65535 {
    65535
  } else {
    default_delay_cs
  }
  let frames : Array[Frame] = []
  for frame in self.frames {
    frames.push(
      if frame.delay_cs <= 0 {
        frame.with_delay(delay_cs=safe_delay)
      } else {
        frame
      },
    )
  }
  Animation::{ ..self, frames, }
}

///|
/// Rescale all delays so the total duration approaches `target_cs`.
pub fn Animation::retime(self : Animation, target_cs : Int) -> Animation {
  if self.frames.length() == 0 || target_cs <= 0 {
    self
  } else {
    let source = self.duration_cs()
    if source <= 0 {
      self.normalize_delays(default_delay_cs=target_cs / self.frames.length())
    } else {
      let frames : Array[Frame] = []
      let mut assigned = 0
      for index, frame in self.frames {
        let delay = if index == self.frames.length() - 1 {
          target_cs - assigned
        } else {
          frame.delay_cs * target_cs / source
        }
        let safe_delay = if delay < 1 {
          1
        } else if delay > 65535 {
          65535
        } else {
          delay
        }
        assigned += safe_delay
        frames.push(frame.with_delay(delay_cs=safe_delay))
      }
      Animation::{ ..self, frames, }
    }
  }
}

///|
/// Find keyframes by comparing each frame to the previous full canvas.
pub fn Animation::keyframe_indices(
  self : Animation,
  threshold? : Int = 0,
) -> Array[Int] {
  let result : Array[Int] = []
  if self.frames.length() == 0 {
    result
  } else {
    let mut previous = self.background_canvas()
    for index, frame in self.frames {
      match changed_rect(previous, frame.canvas, threshold) {
        None => ()
        Some(_) => result.push(index)
      }
      previous = frame.canvas
    }
    result
  }
}

///|
/// Keep only keyframes and preserve each frame's timing.
pub fn Animation::keyframes(
  self : Animation,
  threshold? : Int = 0,
) -> Animation {
  let indices = self.keyframe_indices(threshold~)
  let frames : Array[Frame] = []
  for index in indices {
    frames.push(self.frames[index])
  }
  Animation::{ ..self, frames, }
}

///|
/// Build a sampled timeline with evenly spaced positions.
pub fn Animation::sample(self : Animation, count : Int) -> Animation {
  if count <= 0 || self.frames.length() == 0 {
    Animation::{ ..self, frames: [] }
  } else {
    let frames : Array[Frame] = []
    let duration = self.duration_cs()
    for index in 0..<count {
      let time = if count == 1 { 0 } else { index * duration / count }
      match self.frame_at(time) {
        None => ()
        Some(frame) =>
          frames.push(
            frame.with_delay(
              delay_cs=if count == 0 { 1 } else { duration / count },
            ),
          )
      }
    }
    Animation::{ ..self, frames, }
  }
}

///|
/// Add a reverse pass without duplicating the endpoints.
pub fn Animation::ping_pong(self : Animation) -> Animation {
  if self.frames.length() <= 1 {
    self
  } else {
    let frames : Array[Frame] = []
    for frame in self.frames {
      frames.push(frame)
    }
    let mut index = self.frames.length() - 2
    while index > 0 {
      frames.push(self.frames[index])
      index -= 1
    }
    Animation::{ ..self, frames, }
  }
}

///|
/// Return one frame's delay, defaulting zero-delay frames to one centisecond.
pub fn Frame::visible_delay_cs(self : Frame) -> Int {
  if self.delay_cs <= 0 {
    1
  } else {
    self.delay_cs
  }
}

///|
/// Return a frame with its display delay clamped to GIF's 16-bit field.
pub fn Frame::clamp_delay(self : Frame) -> Frame {
  let value = if self.delay_cs < 0 {
    0
  } else if self.delay_cs > 65535 {
    65535
  } else {
    self.delay_cs
  }
  { ..self, delay_cs: value }
}

///|
/// Return a copy with frame offsets clipped to the logical screen.
pub fn Animation::clip_offsets(self : Animation) -> Animation {
  let frames : Array[Frame] = []
  for frame in self.frames {
    let left = if frame.left < 0 {
      0
    } else if frame.left >= self.width {
      self.width - 1
    } else {
      frame.left
    }
    let top = if frame.top < 0 {
      0
    } else if frame.top >= self.height {
      self.height - 1
    } else {
      frame.top
    }
    frames.push({ ..frame, left, top })
  }
  Animation::{ ..self, frames, }
}
