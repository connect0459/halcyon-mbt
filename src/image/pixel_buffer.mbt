///|
#derive(Eq, Debug)
pub(all) suberror ImageError {
  InvalidDimensions(Int32, Int32)
  DataLengthMismatch(Int32, Int32)
  RegionOutOfBounds(Int32, Int32, Int32, Int32)
}

///|
#derive(Eq, Debug)
pub struct PixelBuffer {
  priv width : Int32
  priv height : Int32
  priv data : Bytes
}

///|
pub fn PixelBuffer::new(
  width : Int32,
  height : Int32,
  data : Bytes,
) -> PixelBuffer raise ImageError {
  if width <= 0 || height <= 0 {
    raise InvalidDimensions(width, height)
  }
  let expected = width * height * 4
  if data.length() != expected {
    raise DataLengthMismatch(expected, data.length())
  }
  { width, height, data, }
}

///|
pub fn PixelBuffer::width(self : PixelBuffer) -> Int32 {
  self.width
}

///|
pub fn PixelBuffer::height(self : PixelBuffer) -> Int32 {
  self.height
}

///|
pub fn PixelBuffer::data(self : PixelBuffer) -> Bytes {
  self.data
}

///|
pub fn PixelBuffer::byte_size(self : PixelBuffer) -> Int32 {
  self.data.length()
}

///|
pub fn PixelBuffer::pixel(self : PixelBuffer, x : Int32, y : Int32) -> Rgba? {
  if x < 0 || y < 0 || x >= self.width || y >= self.height {
    return None
  }
  let offset = (y * self.width + x) * 4
  Some(
    Rgba::new(
      self.data[offset].to_int(),
      self.data[offset + 1].to_int(),
      self.data[offset + 2].to_int(),
      self.data[offset + 3].to_int(),
    ),
  )
}
