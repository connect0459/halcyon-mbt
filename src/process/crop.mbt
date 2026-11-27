///|
pub struct Crop {
  priv x : Int32
  priv y : Int32
  priv width : Int32
  priv height : Int32
}

///|
pub fn Crop::new(x : Int32, y : Int32, width : Int32, height : Int32) -> Crop {
  { x, y, width, height, }
}

///|
pub impl ImageProcessor for Crop with fn identifier(self) {
  "crop(\{self.x},\{self.y},\{self.width}x\{self.height})"
}

///|
pub impl ImageProcessor for Crop with fn process(self, source) {
  if self.width <= 0 || self.height <= 0 {
    raise @image.ImageError::InvalidDimensions(self.width, self.height)
  }
  if self.x < 0 ||
    self.y < 0 ||
    self.x + self.width > source.width() ||
    self.y + self.height > source.height() {
    raise @image.ImageError::RegionOutOfBounds(
      self.x,
      self.y,
      self.width,
      self.height,
    )
  }
  let src = source.data()
  let out = Array::make(self.width * self.height * 4, b'\x00')
  for row in 0..<self.height {
    let from = ((self.y + row) * source.width() + self.x) * 4
    let to = row * self.width * 4
    for i in 0..<(self.width * 4) {
      out[to + i] = src[from + i]
    }
  }
  @image.PixelBuffer::new(self.width, self.height, Bytes::from_array(out))
}
