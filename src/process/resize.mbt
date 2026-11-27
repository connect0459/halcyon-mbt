///|
pub struct Resize {
  priv width : Int32
  priv height : Int32
}

///|
pub fn Resize::new(width : Int32, height : Int32) -> Resize {
  { width, height, }
}

///|
pub impl ImageProcessor for Resize with fn identifier(self) {
  "resize(\{self.width}x\{self.height})"
}

///|
pub impl ImageProcessor for Resize with fn process(self, source) {
  if self.width <= 0 || self.height <= 0 {
    raise @image.ImageError::InvalidDimensions(self.width, self.height)
  }
  let src = source.data()
  let out = Array::make(self.width * self.height * 4, b'\x00')
  for y in 0..<self.height {
    let sy = y * source.height() / self.height
    for x in 0..<self.width {
      let sx = x * source.width() / self.width
      let from = (sy * source.width() + sx) * 4
      let to = (y * self.width + x) * 4
      for c in 0..<4 {
        out[to + c] = src[from + c]
      }
    }
  }
  @image.PixelBuffer::new(self.width, self.height, Bytes::from_array(out))
}
