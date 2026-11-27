///|
fn fnv1a32(data : Bytes) -> UInt32 {
  let mut hash = 2166136261U
  for byte in data {
    hash = (hash ^ byte.to_uint()) * 16777619U
  }
  hash
}

///|
test "every fixture decodes to the pixels the reference decoder produces" {
  let decoder = @jpeg.JpegDecoder::new()
  for fixture in jpeg_fixtures {
    let (name, data, width, height, digest) = fixture
    let buffer = decoder.decode(data) catch {
      e => fail("\{name} failed to decode: \{repr(e)}")
    }
    assert_eq((name, buffer.width(), buffer.height()), (name, width, height))
    assert_eq((name, fnv1a32(buffer.data())), (name, digest))
  }
}
