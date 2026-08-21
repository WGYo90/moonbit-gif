///|
/// Convert `mizchi/image` RGBA ImageData into the animation engine's Canvas.
///
/// `mizchi/image` normalizes decoded PNG/BMP/JPEG data to four bytes per pixel.
/// This adapter keeps that representation at the package boundary and lets
/// the animation core own frame timing, disposal, and GIF indexing.
pub fn canvas_from_image_data(
  image : @image.ImageData,
) -> Canvas raise GifError {
  canvas_from_rgba_bytes(width=image.width, height=image.height, image.data)
}

///|
/// Convert a Canvas back to `mizchi/image` RGBA ImageData.
pub fn Canvas::to_image_data(self : Canvas) -> @image.ImageData {
  @image.ImageData::{
    width: self.width,
    height: self.height,
    data: self.to_rgba_bytes(),
  }
}

///|
/// Build a frame from one `mizchi/image` image.
pub fn frame_from_image_data(
  image : @image.ImageData,
  delay_cs? : Int = 0,
) -> Frame raise GifError {
  Frame::new(canvas=canvas_from_image_data(image), delay_cs~)
}

///|
/// Build an animation from RGBA images decoded or resized by `mizchi/image`.
pub fn animation_from_image_data(
  images : ArrayView[@image.ImageData],
  delay_cs? : Int = 5,
  loop_count? : Int,
) -> Animation raise GifError {
  if images.length() == 0 {
    raise InvalidDimensions
  }
  let first = images[0]
  let mut animation = Animation::new(width=first.width, height=first.height)
  match loop_count {
    None => ()
    Some(value) => animation = animation.with_loop_count(loop_count=Some(value))
  }
  for image in images {
    if image.width != first.width || image.height != first.height {
      raise InvalidDimensions
    }
    animation = animation.add_frame(frame_from_image_data(image, delay_cs~))
  }
  animation
}

///|
/// Encode one `mizchi/image` ImageData using the extended GIF engine.
pub fn encode_image_data(
  image : @image.ImageData,
  delay_cs? : Int = 0,
) -> Bytes raise GifError {
  encode(animation_from_image_data([image], delay_cs~))
}

///|
/// Decode the first composited frame into the upstream ImageData shape.
pub fn decode_first_image_data(data : Bytes) -> @image.ImageData raise GifError {
  let animation = decode(data)
  let snapshots = compose(animation)
  if snapshots.length() == 0 {
    raise InvalidBlock(context="GIF has no composited frames")
  }
  snapshots[0].to_image_data()
}

///|
/// Encode a sequence of upstream ImageData values as a dynamic GIF.
pub fn encode_image_sequence(
  images : ArrayView[@image.ImageData],
  delay_cs? : Int = 5,
  loop_count? : Int,
) -> Bytes raise GifError {
  let loop_value = match loop_count {
    None => 0
    Some(value) => value
  }
  encode(animation_from_image_data(images, delay_cs~, loop_count=loop_value))
}
