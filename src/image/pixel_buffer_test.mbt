///|
test "a buffer reports its dimensions and byte size" {
  let buffer = @image.PixelBuffer::new(2, 3, Bytes::make(24, 0))
  assert_eq(buffer.width(), 2)
  assert_eq(buffer.height(), 3)
  assert_eq(buffer.byte_size(), 24)
}

///|
test "a buffer is rejected when the data length does not match the dimensions" {
  try @image.PixelBuffer::new(2, 2, Bytes::make(15, 0)) catch {
    @image.ImageError::DataLengthMismatch(expected, actual) =>
      assert_eq((expected, actual), (16, 15))
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "a buffer is rejected when the width is not positive" {
  try @image.PixelBuffer::new(0, 2, Bytes::make(0, 0)) catch {
    @image.ImageError::InvalidDimensions(w, h) => assert_eq((w, h), (0, 2))
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "a buffer is rejected when the height is not positive" {
  try @image.PixelBuffer::new(2, -1, Bytes::make(0, 0)) catch {
    @image.ImageError::InvalidDimensions(w, h) => assert_eq((w, h), (2, -1))
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "a pixel is read in row-major order as RGBA" {
  let data : Bytes = b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10"
  let buffer = @image.PixelBuffer::new(2, 2, data)
  assert_eq(buffer.pixel(1, 0), Some(@image.Rgba::new(5, 6, 7, 8)))
  assert_eq(buffer.pixel(0, 1), Some(@image.Rgba::new(9, 10, 11, 12)))
}

///|
test "reading outside the buffer yields nothing" {
  let buffer = @image.PixelBuffer::new(1, 1, Bytes::make(4, 0))
  assert_eq(buffer.pixel(1, 0), None)
  assert_eq(buffer.pixel(0, -1), None)
}

///|
test "buffers with the same dimensions and pixels are equal" {
  let a = @image.PixelBuffer::new(1, 1, b"\x01\x02\x03\x04")
  let b = @image.PixelBuffer::new(1, 1, b"\x01\x02\x03\x04")
  let c = @image.PixelBuffer::new(1, 1, b"\x01\x02\x03\x05")
  assert_eq(a, b)
  assert_true(a != c)
}

///|
test "the data of a buffer is exposed as RGBA bytes" {
  let buffer = @image.PixelBuffer::new(1, 1, b"\x01\x02\x03\x04")
  assert_eq(buffer.data(), b"\x01\x02\x03\x04")
}
