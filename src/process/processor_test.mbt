///|
fn sample() -> @image.PixelBuffer raise {
  @image.PixelBuffer::new(
    2, 2, b"\x01\x00\x00\xff\x02\x00\x00\xff\x03\x00\x00\xff\x04\x00\x00\xff",
  )
}

///|
fn red_of(buffer : @image.PixelBuffer, x : Int32, y : Int32) -> Int32 {
  match buffer.pixel(x, y) {
    Some(p) => p.r()
    None => -1
  }
}

///|
test "resizing up repeats the nearest source pixel" {
  let out = @process.Resize::new(4, 4).process(sample())
  assert_eq((out.width(), out.height()), (4, 4))
  assert_eq(red_of(out, 0, 0), 1)
  assert_eq(red_of(out, 1, 1), 1)
  assert_eq(red_of(out, 2, 0), 2)
  assert_eq(red_of(out, 0, 3), 3)
  assert_eq(red_of(out, 3, 3), 4)
}

///|
test "resizing down samples the nearest source pixel" {
  let big = @process.Resize::new(4, 4).process(sample())
  let out = @process.Resize::new(2, 2).process(big)
  assert_eq(out, sample())
}

///|
test "resizing to a non-positive size is rejected" {
  try @process.Resize::new(0, 4).process(sample()) catch {
    @image.ImageError::InvalidDimensions(w, h) => assert_eq((w, h), (0, 4))
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "resize identifies itself by its target size" {
  assert_eq(@process.Resize::new(10, 20).identifier(), "resize(10x20)")
}

///|
test "cropping keeps only the requested region" {
  let out = @process.Crop::new(1, 0, 1, 2).process(sample())
  assert_eq((out.width(), out.height()), (1, 2))
  assert_eq(red_of(out, 0, 0), 2)
  assert_eq(red_of(out, 0, 1), 4)
}

///|
test "cropping outside the image is rejected" {
  try @process.Crop::new(1, 1, 2, 2).process(sample()) catch {
    @image.ImageError::RegionOutOfBounds(x, y, w, h) =>
      assert_eq((x, y, w, h), (1, 1, 2, 2))
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "cropping with a negative origin is rejected" {
  try @process.Crop::new(-1, 0, 1, 1).process(sample()) catch {
    @image.ImageError::RegionOutOfBounds(_, _, _, _) => ()
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "cropping to an empty region is rejected" {
  try @process.Crop::new(0, 0, 0, 1).process(sample()) catch {
    @image.ImageError::InvalidDimensions(_, _) => ()
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "crop identifies itself by its region" {
  assert_eq(@process.Crop::new(1, 2, 3, 4).identifier(), "crop(1,2,3x4)")
}

///|
test "composed processors apply in order" {
  let composed = @process.Compose::new([
    @process.Resize::new(4, 4),
    @process.Crop::new(2, 2, 2, 2),
  ])
  let out = composed.process(sample())
  assert_eq((out.width(), out.height()), (2, 2))
  assert_eq(red_of(out, 0, 0), 4)
}

///|
test "composition identifies itself by the ordered identifiers of its parts" {
  let composed = @process.Compose::new([
    @process.Resize::new(4, 4),
    @process.Crop::new(2, 2, 2, 2),
  ])
  assert_eq(composed.identifier(), "resize(4x4)|crop(2,2,2x2)")
}

///|
test "an empty composition leaves the image unchanged and has an empty identifier" {
  let composed = @process.Compose::new([])
  assert_eq(composed.process(sample()), sample())
  assert_eq(composed.identifier(), "")
}

///|
test "a processor contributes its identifier to the cache key" {
  let key = @process.key_for(
    "https://example.com/a.png",
    @process.Resize::new(1, 1),
  )
  assert_eq(
    key,
    @image.ImageKey::new("https://example.com/a.png", "resize(1x1)"),
  )
}
