///|
test "keys with the same source and processor are equal" {
  let a = @image.ImageKey::new("https://example.com/a.png", "resize(10x10)")
  let b = @image.ImageKey::new("https://example.com/a.png", "resize(10x10)")
  assert_eq(a, b)
  assert_eq(Hash::hash(a), Hash::hash(b))
}

///|
test "keys differ when the processor identifier differs" {
  let a = @image.ImageKey::new("https://example.com/a.png", "resize(10x10)")
  let b = @image.ImageKey::new("https://example.com/a.png", "resize(20x20)")
  assert_true(a != b)
}

///|
test "a key without a processor uses the empty identifier" {
  let key = @image.ImageKey::of_source("https://example.com/a.png")
  assert_eq(key.source(), "https://example.com/a.png")
  assert_eq(key.processor_id(), "")
}

///|
test "a key renders the source and the processor identifier" {
  let key = @image.ImageKey::new("s", "p")
  assert_eq(Show::to_string(key), "s#p")
  assert_eq(Show::to_string(@image.ImageKey::of_source("s")), "s")
}
