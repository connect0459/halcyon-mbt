///|
priv struct BitReader {
  data : Bytes
  mut pos : Int32
  mut buffer : Int32
  mut count : Int32
}

///|
fn BitReader::new(data : Bytes, pos : Int32) -> BitReader {
  { data, pos, buffer: 0, count: 0, }
}

///|
fn BitReader::fill(self : BitReader) -> Unit raise @decode.DecodeError {
  if self.pos >= self.data.length() {
    raise @decode.DecodeError::Truncated
  }
  let byte = self.data[self.pos].to_int()
  if byte == 0xFF {
    if self.pos + 1 >= self.data.length() || self.data[self.pos + 1] != b'\x00' {
      raise @decode.DecodeError::Truncated
    }
    self.pos += 2
  } else {
    self.pos += 1
  }
  self.buffer = byte
  self.count = 8
}

///|
fn BitReader::bit(self : BitReader) -> Int32 raise @decode.DecodeError {
  if self.count == 0 {
    self.fill()
  }
  self.count -= 1
  (self.buffer >> self.count) & 1
}

///|
fn BitReader::bits(
  self : BitReader,
  count : Int32,
) -> Int32 raise @decode.DecodeError {
  let mut value = 0
  for _ in 0..<count {
    value = (value << 1) | self.bit()
  }
  value
}

///|
fn BitReader::receive_extend(
  self : BitReader,
  size : Int32,
) -> Int32 raise @decode.DecodeError {
  if size == 0 {
    return 0
  }
  let value = self.bits(size)
  if value < 1 << (size - 1) {
    value - (1 << size) + 1
  } else {
    value
  }
}

///|
fn BitReader::expect_restart(
  self : BitReader,
  index : Int32,
) -> Unit raise @decode.DecodeError {
  self.count = 0
  if self.pos + 1 >= self.data.length() {
    raise @decode.DecodeError::Truncated
  }
  if self.data[self.pos] != b'\xff' ||
    self.data[self.pos + 1].to_int() != 0xD0 + (index & 7) {
    raise @decode.DecodeError::Malformed("missing restart marker")
  }
  self.pos += 2
}
