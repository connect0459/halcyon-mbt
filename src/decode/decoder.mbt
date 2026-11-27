///|
#derive(Eq, Debug)
pub(all) suberror DecodeError {
  UnknownFormat
  Truncated
  Malformed(String)
  Unsupported(String)
  LimitExceeded(Int32, Int32)
}

///|
pub(open) trait ImageDecoder {
  fn format(Self) -> @image.ImageFormat
  fn decode(Self, Bytes) -> @image.PixelBuffer raise DecodeError
}

///|
pub fn detect_format(data : Bytes) -> @image.ImageFormat? {
  if data.length() >= 8 &&
    data[0] == b'\x89' &&
    data[1] == b'P' &&
    data[2] == b'N' &&
    data[3] == b'G' &&
    data[4] == b'\r' &&
    data[5] == b'\n' &&
    data[6] == b'\x1a' &&
    data[7] == b'\n' {
    return Some(Png)
  }
  if data.length() >= 3 &&
    data[0] == b'\xff' &&
    data[1] == b'\xd8' &&
    data[2] == b'\xff' {
    return Some(Jpeg)
  }
  None
}

///|
pub struct DecodeLimits {
  priv max_pixels : Int32
}

///|
pub fn DecodeLimits::new(max_pixels~ : Int32) -> DecodeLimits {
  { max_pixels, }
}

///|
pub fn DecodeLimits::default() -> DecodeLimits {
  { max_pixels: 100_000_000, }
}

///|
pub fn DecodeLimits::max_pixels(self : DecodeLimits) -> Int32 {
  self.max_pixels
}

///|
pub fn DecodeLimits::check(
  self : DecodeLimits,
  width : Int32,
  height : Int32,
) -> Unit raise DecodeError {
  if width <= 0 || height <= 0 {
    raise Malformed("non-positive dimensions")
  }
  if width.to_int64() * height.to_int64() > self.max_pixels.to_int64() {
    raise LimitExceeded(width, height)
  }
}
