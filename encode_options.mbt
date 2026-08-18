///|
/// Controls palette size and timeline metadata emitted by the GIF encoder.
pub(all) struct EncodeOptions {
  max_colors : Int
  default_delay_cs : Int
  emit_loop_extension : Bool
} derive(Debug)

///|
pub fn EncodeOptions::default() -> EncodeOptions {
  { max_colors: 256, default_delay_cs: 0, emit_loop_extension: true }
}

///|
pub fn EncodeOptions::new(
  max_colors~ : Int,
  default_delay_cs~ : Int,
) -> EncodeOptions {
  {
    max_colors,
    default_delay_cs: if default_delay_cs < 0 {
      0
    } else {
      default_delay_cs
    },
    emit_loop_extension: true,
  }
}

///|
pub fn EncodeOptions::with_loop_extension(
  self : EncodeOptions,
  enabled : Bool,
) -> EncodeOptions {
  { ..self, emit_loop_extension: enabled }
}

///|
pub fn EncodeOptions::colors(self : EncodeOptions) -> Int {
  self.max_colors
}

///|
pub fn EncodeOptions::default_delay(self : EncodeOptions) -> Int {
  self.default_delay_cs
}

///|
pub fn EncodeOptions::loop_extension(self : EncodeOptions) -> Bool {
  self.emit_loop_extension
}
