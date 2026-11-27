///|
let dynamic_stream : Bytes = b"\x78\xda\x75\x90\x41\x0e\xc0\x20\x08\x04\xbf\xc2\xd7\x20\xb5\xda\x44\x8d\x07\xff\x9f\x46\x90\x00\xb1\xbd\x20\xe2\xce\xb2\x91\xd2\x44\x18\x3d\x03\xd6\x51\x10\x32\xb6\x86\xbb\xbf\x52\x9d\xb1\x3e\xfd\xae\x38\xd3\xbe\xd1\x42\xbd\xf4\xc4\xcc\x38\xa2\xb2\x46\x67\xf4\x9f\xc1\x57\x95\x9b\x32\xa6\x62\x9b\x38\x12\xd9\x02\xdc\xa3\x45\xe3\xa1\xac\xe3\xf6\xc3\xe9\xfc\x90\x05\x46\xff\xc0\xea\xe9\xc1\x17\x07\xb9\x80\xb0"

///|
let dynamic_text : String = "beta png alpha gamma alpha delta delta delta inflate delta beta alpha delta alpha delta delta png alpha inflate delta gamma inflate beta png alpha gamma alpha alpha alpha inflate png alpha delta inflate beta delta inflate alpha png beta delta delta png beta gamma beta inflate beta delta gamma alpha delta png inflate alpha beta inflate inflate gamma alpha "

///|
fn expect_error(
  result : () -> Bytes raise @inflate.InflateError,
  expected : @inflate.InflateError,
) -> Unit raise {
  try result() catch {
    e => assert_eq(e, expected)
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "a stored block is copied verbatim" {
  let out = @inflate.zlib_decompress(
    b"\x78\x01\x01\x05\x00\xfa\xff\x68\x65\x6c\x6c\x6f\x06\x2c\x02\x15",
  )
  assert_eq(out, b"hello")
}

///|
test "a stream holding no data yields empty output" {
  assert_eq(@inflate.zlib_decompress(b"\x78\x9c\x03\x00\x00\x00\x00\x01"), b"")
  assert_eq(
    @inflate.zlib_decompress(b"\x78\x01\x01\x00\x00\xff\xff\x00\x00\x00\x01"),
    b"",
  )
}

///|
test "a fixed Huffman block with back references is expanded" {
  let out = @inflate.zlib_decompress(
    b"\x78\x01\x4b\x4c\x4a\x4e\x44\x45\x00\x41\x7c\x06\xe5",
  )
  assert_eq(out, b"abcabcabcabcabcabc")
}

///|
test "a back reference overlapping its own output repeats the pattern" {
  let out = @inflate.zlib_decompress(
    b"\x78\x9c\x4b\x4c\x1c\x05\xa3\x60\x14\x0c\x77\x00\x00\xf9\xd8\x7a\xf8",
  )
  assert_eq(out.length(), 1000)
  assert_eq(out[0], b'a')
  assert_eq(out[999], b'a')
}

///|
test "a dynamic Huffman block is expanded" {
  let out = @inflate.zlib_decompress(dynamic_stream)
  assert_eq(out, @utf8.encode(dynamic_text))
}

///|
test "raw deflate data is inflated without a zlib wrapper" {
  let out = @inflate.inflate(b"\x01\x05\x00\xfa\xff\x68\x65\x6c\x6c\x6f")
  assert_eq(out, b"hello")
}

///|
test "multiple blocks are concatenated" {
  let out = @inflate.inflate(b"\x00\x01\x00\xfe\xffa\x01\x01\x00\xfe\xffb")
  assert_eq(out, b"ab")
}

///|
test "output beyond the configured limit is rejected" {
  expect_error(
    () => @inflate.zlib_decompress(dynamic_stream, max_output=10),
    @inflate.InflateError::OutputLimitExceeded,
  )
  expect_error(
    () => {
      @inflate.inflate(
        b"\x01\x05\x00\xfa\xff\x68\x65\x6c\x6c\x6f",
        max_output=4,
      )
    },
    @inflate.InflateError::OutputLimitExceeded,
  )
}

///|
test "a zlib header with the wrong compression method is rejected" {
  expect_error(
    () => @inflate.zlib_decompress(b"\x79\x9c\x03\x00\x00\x00\x00\x01"),
    @inflate.InflateError::InvalidHeader,
  )
}

///|
test "a zlib header that fails its check bits is rejected" {
  expect_error(
    () => @inflate.zlib_decompress(b"\x78\x9d\x03\x00\x00\x00\x00\x01"),
    @inflate.InflateError::InvalidHeader,
  )
}

///|
test "a zlib stream requiring a preset dictionary is rejected" {
  expect_error(
    () => {
      @inflate.zlib_decompress(
        b"\x78\xbb\x00\x00\x00\x00\x03\x00\x00\x00\x00\x01",
      )
    },
    @inflate.InflateError::UnsupportedDictionary,
  )
}

///|
test "a corrupted checksum is detected" {
  expect_error(
    () => {
      @inflate.zlib_decompress(
        b"\x78\x01\x01\x05\x00\xfa\xff\x68\x65\x6c\x6c\x6f\x06\x2c\x02\x16",
      )
    },
    @inflate.InflateError::ChecksumMismatch,
  )
}

///|
test "a stream shorter than a zlib header and trailer is rejected" {
  expect_error(
    () => @inflate.zlib_decompress(b"\x78\x9c"),
    @inflate.InflateError::UnexpectedEnd,
  )
}

///|
test "a stream missing its checksum is rejected" {
  expect_error(
    () => @inflate.zlib_decompress(b"\x78\x01\x01\x01\x00\xfe\xffa\x00\x00"),
    @inflate.InflateError::UnexpectedEnd,
  )
}

///|
test "a truncated deflate stream is rejected" {
  expect_error(
    () => @inflate.inflate(b""),
    @inflate.InflateError::UnexpectedEnd,
  )
  expect_error(
    () => @inflate.inflate(b"\x01\x05\x00\xfa\xff\x68\x65"),
    @inflate.InflateError::UnexpectedEnd,
  )
  expect_error(
    () => @inflate.inflate(b"\x01\x05\x00"),
    @inflate.InflateError::UnexpectedEnd,
  )
}

///|
test "a reserved block type is rejected" {
  expect_error(
    () => @inflate.inflate(b"\x07"),
    @inflate.InflateError::InvalidBlockType,
  )
}

///|
test "a stored block whose length complement does not match is rejected" {
  expect_error(
    () => @inflate.inflate(b"\x01\x05\x00\xfb\xff\x68\x65\x6c\x6c\x6f"),
    @inflate.InflateError::InvalidStoredLength,
  )
}

///|
test "a back reference reaching before the start of the output is rejected" {
  expect_error(
    () => @inflate.inflate(b"\x03\x02\x00"),
    @inflate.InflateError::InvalidDistance,
  )
}

///|
fn lsb(value : Int32, count : Int32) -> Array[Int32] {
  let bits = []
  for i in 0..<count {
    bits.push((value >> i) & 1)
  }
  bits
}

///|
fn msb(value : Int32, count : Int32) -> Array[Int32] {
  let bits = []
  for i in 0..<count {
    bits.push((value >> (count - 1 - i)) & 1)
  }
  bits
}

///|
fn pack(parts : Array[Array[Int32]]) -> Bytes {
  let bits = []
  for part in parts {
    bits.append(part)
  }
  let bytes = Array::make((bits.length() + 7) / 8, b'\x00')
  for i, bit in bits {
    if bit == 1 {
      bytes[i / 8] = (bytes[i / 8].to_int() | (1 << (i % 8))).to_byte()
    }
  }
  Bytes::from_array(bytes)
}

///|
fn dynamic_header(
  literal_count : Int32,
  distance_count : Int32,
  code_length_count : Int32,
) -> Array[Array[Int32]] {
  [
    lsb(1, 1),
    lsb(2, 2),
    lsb(literal_count, 5),
    lsb(distance_count, 5),
    lsb(code_length_count, 4),
  ]
}

///|
test "a literal symbol outside the length alphabet is rejected" {
  let stream = pack([lsb(1, 1), lsb(1, 2), msb(0b11000110, 8)])
  expect_error(
    () => @inflate.inflate(stream),
    @inflate.InflateError::InvalidSymbol,
  )
}

///|
test "a dynamic block declaring too many literal codes is rejected" {
  let stream = pack(dynamic_header(30, 0, 0))
  expect_error(
    () => @inflate.inflate(stream),
    @inflate.InflateError::InvalidCodeLengths,
  )
}

///|
test "an oversubscribed set of code lengths is rejected" {
  let stream = pack(
    dynamic_header(0, 0, 0) + [lsb(1, 3), lsb(1, 3), lsb(1, 3), lsb(1, 3)],
  )
  expect_error(
    () => @inflate.inflate(stream),
    @inflate.InflateError::InvalidCodeLengths,
  )
}

///|
test "repeating the previous length with no previous length is rejected" {
  let stream = pack(
    dynamic_header(0, 0, 0) + [lsb(1, 3), lsb(0, 3), lsb(0, 3), lsb(0, 3), [0]],
  )
  expect_error(
    () => @inflate.inflate(stream),
    @inflate.InflateError::InvalidCodeLengths,
  )
}

///|
test "a run of code lengths that overflows the declared count is rejected" {
  let stream = pack(
    dynamic_header(0, 0, 0) +
    [
      lsb(0, 3),
      lsb(0, 3),
      lsb(1, 3),
      lsb(0, 3),
      [0],
      lsb(127, 7),
      [0],
      lsb(127, 7),
    ],
  )
  expect_error(
    () => @inflate.inflate(stream),
    @inflate.InflateError::InvalidCodeLengths,
  )
}

///|
test "a dynamic block without an end-of-block code is rejected" {
  let stream = pack(
    dynamic_header(0, 0, 0) +
    [
      lsb(0, 3),
      lsb(0, 3),
      lsb(1, 3),
      lsb(0, 3),
      [0],
      lsb(127, 7),
      [0],
      lsb(109, 7),
    ],
  )
  expect_error(
    () => @inflate.inflate(stream),
    @inflate.InflateError::InvalidCodeLengths,
  )
}

///|
test "a dynamic block may repeat the previous code length" {
  let stream = pack(
    dynamic_header(0, 3, 14) +
    [
      lsb(2, 3),
      lsb(0, 3),
      lsb(2, 3),
      lsb(2, 3),
      Array::make(13, 0).map(_ => lsb(0, 3)).flatten(),
      lsb(2, 3),
      msb(0b11, 2),
      lsb(86, 7),
      msb(0b01, 2),
      msb(0b11, 2),
      lsb(127, 7),
      msb(0b11, 2),
      lsb(9, 7),
      msb(0b01, 2),
      msb(0b00, 2),
      msb(0b10, 2),
      lsb(0, 2),
      [0, 1],
    ],
  )
  assert_eq(@inflate.inflate(stream), b"a")
}
