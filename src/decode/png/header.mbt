///|
priv struct Header {
  width : Int32
  height : Int32
  bit_depth : Int32
  color_type : Int32
  interlaced : Bool
}

///|
fn Header::channels(self : Header) -> Int32 {
  match self.color_type {
    0 => 1
    2 => 3
    3 => 1
    4 => 2
    _ => 4
  }
}

///|
fn Header::bits_per_pixel(self : Header) -> Int32 {
  self.channels() * self.bit_depth
}

///|
fn Header::parse(
  data : Bytes,
  start : Int32,
  length : Int32,
  limits : @decode.DecodeLimits,
) -> Header raise @decode.DecodeError {
  if length != 13 {
    raise @decode.DecodeError::Malformed("invalid header length")
  }
  let width = read_u32(data, start)
  let height = read_u32(data, start + 4)
  let bit_depth = data[start + 8].to_int()
  let color_type = data[start + 9].to_int()
  let compression = data[start + 10].to_int()
  let filter = data[start + 11].to_int()
  let interlace = data[start + 12].to_int()
  let valid_depths = match color_type {
    0 => [1, 2, 4, 8, 16]
    2 | 4 | 6 => [8, 16]
    3 => [1, 2, 4, 8]
    _ => raise @decode.DecodeError::Malformed("invalid color type")
  }
  if !valid_depths.contains(bit_depth) {
    raise @decode.DecodeError::Malformed("invalid bit depth for color type")
  }
  if compression != 0 {
    raise @decode.DecodeError::Unsupported("compression method")
  }
  if filter != 0 {
    raise @decode.DecodeError::Unsupported("filter method")
  }
  if interlace > 1 {
    raise @decode.DecodeError::Unsupported("interlace method")
  }
  if width <= 0 || height <= 0 {
    raise @decode.DecodeError::Malformed("invalid dimensions")
  }
  limits.check(width, height)
  { width, height, bit_depth, color_type, interlaced: interlace == 1, }
}

///|
fn read_u32(data : Bytes, at : Int32) -> Int32 {
  (data[at].to_int() << 24) |
  (data[at + 1].to_int() << 16) |
  (data[at + 2].to_int() << 8) |
  data[at + 3].to_int()
}
