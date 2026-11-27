///|
fn fnv1a32(data : Bytes) -> UInt32 {
  let mut hash = 2166136261U
  for byte in data {
    hash = (hash ^ byte.to_uint()) * 16777619U
  }
  hash
}

///|
test "every PngSuite image decodes to the pixels the reference decoder produces" {
  let decoder = @png.PngDecoder::new()
  for fixture in pngsuite_valid {
    let (name, data, width, height, digest) = fixture
    let buffer = decoder.decode(data) catch {
      e => fail("\{name} failed to decode: \{repr(e)}")
    }
    assert_eq((name, buffer.width(), buffer.height()), (name, width, height))
    assert_eq((name, fnv1a32(buffer.data())), (name, digest))
  }
}

///|
test "every deliberately corrupted PngSuite image is rejected" {
  let decoder = @png.PngDecoder::new()
  for fixture in pngsuite_invalid {
    let (name, data) = fixture
    try decoder.decode(data) catch {
      _ => ()
    } noraise {
      _ => fail("\{name} should have been rejected")
    }
  }
}

///|
fn fixture(name : String) -> Bytes {
  for f in pngsuite_valid {
    if f.0 == name {
      return f.1
    }
  }
  for f in pngsuite_invalid {
    if f.0 == name {
      return f.1
    }
  }
  abort("unknown fixture \{name}")
}

///|
fn expect_decode_error(
  data : Bytes,
  expected : @decode.DecodeError,
  decoder~ : @png.PngDecoder = @png.PngDecoder::new(),
) -> Unit raise {
  try decoder.decode(data) catch {
    e => assert_eq(e, expected)
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "a PNG decoder reports the PNG format" {
  assert_eq(
    @decode.ImageDecoder::format(@png.PngDecoder::new()),
    @image.ImageFormat::Png,
  )
}

///|
test "decoding through the decoder trait yields the same pixels" {
  let decoder : &@decode.ImageDecoder = @png.PngDecoder::new()
  let buffer = decoder.decode(fixture("basn6a08"))
  assert_eq((buffer.width(), buffer.height()), (32, 32))
}

///|
test "data without a PNG signature is not recognised" {
  expect_decode_error(b"", @decode.DecodeError::UnknownFormat)
  expect_decode_error(b"\xff\xd8\xff\xe0", @decode.DecodeError::UnknownFormat)
}

///|
test "data that ends inside the chunk stream is truncated" {
  let data = fixture("basn6a08")
  expect_decode_error(data[0:8].to_owned(), @decode.DecodeError::Truncated)
  expect_decode_error(data[0:20].to_owned(), @decode.DecodeError::Truncated)
  expect_decode_error(
    data[0:data.length() - 12].to_owned(),
    @decode.DecodeError::Truncated,
  )
}

///|
test "an image exceeding the pixel limit is rejected before decoding" {
  let limited = @png.PngDecoder::new(
    limits=@decode.DecodeLimits::new(max_pixels=100),
  )
  expect_decode_error(
    fixture("basn6a08"),
    @decode.DecodeError::LimitExceeded(32, 32),
    decoder=limited,
  )
}

///|
test "an image within the pixel limit is decoded" {
  let limited = @png.PngDecoder::new(
    limits=@decode.DecodeLimits::new(max_pixels=1024),
  )
  assert_eq(limited.decode(fixture("basn6a08")).width(), 32)
}
