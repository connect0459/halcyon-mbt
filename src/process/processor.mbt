///|
pub(open) trait ImageProcessor {
  fn identifier(Self) -> String
  fn process(Self, @image.PixelBuffer) -> @image.PixelBuffer raise @image.ImageError
}

///|
pub fn[P : ImageProcessor] key_for(
  source : String,
  processor : P,
) -> @image.ImageKey {
  @image.ImageKey::new(source, processor.identifier())
}
