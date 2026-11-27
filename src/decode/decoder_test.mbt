///|
test "a PNG signature is detected" {
  assert_eq(
    @decode.detect_format(b"\x89PNG\r\n\x1a\n\x00\x00"),
    Some(@image.ImageFormat::Png),
  )
}

///|
test "a JPEG start-of-image marker is detected" {
  assert_eq(
    @decode.detect_format(b"\xff\xd8\xff\xe0"),
    Some(@image.ImageFormat::Jpeg),
  )
}

///|
test "unrecognised or too short data has no format" {
  assert_eq(@decode.detect_format(b"GIF89a"), None)
  assert_eq(@decode.detect_format(b""), None)
  assert_eq(@decode.detect_format(b"\x89PNG\r\n\x1a"), None)
  assert_eq(@decode.detect_format(b"\xff\xd8"), None)
}

///|
test "an image within the pixel limit is accepted" {
  @decode.DecodeLimits::new(max_pixels=100).check(10, 10)
}

///|
test "an image beyond the pixel limit is rejected" {
  try @decode.DecodeLimits::new(max_pixels=100).check(11, 10) catch {
    @decode.DecodeError::LimitExceeded(w, h) => assert_eq((w, h), (11, 10))
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "the default limit admits ordinary photographs but not decompression bombs" {
  let limits = @decode.DecodeLimits::default()
  assert_eq(limits.max_pixels(), 100_000_000)
  limits.check(4000, 3000)
  try limits.check(100000, 100000) catch {
    @decode.DecodeError::LimitExceeded(_, _) => ()
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "non-positive dimensions are malformed" {
  try @decode.DecodeLimits::default().check(0, 5) catch {
    @decode.DecodeError::Malformed(_) => ()
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected an error")
  }
}
