///|
fn img(tag : Int32) -> @image.PixelBuffer raise {
  @image.PixelBuffer::new(
    1,
    1,
    Bytes::from_array([b'\x00', b'\x00', b'\x00', tag.to_byte()]),
  )
}

///|
fn key(name : String) -> @image.ImageKey {
  @image.ImageKey::of_source(name)
}

///|
test "a stored image is returned for its key" {
  let cache = @cache.MemoryCache::new(@cache.ManualClock::new(0L), 100)
  cache.set(key("a"), img(1))
  assert_eq(cache.get(key("a")), Some(img(1)))
  assert_eq(cache.get(key("b")), None)
}

///|
test "storing under an existing key replaces the image and its cost" {
  let cache = @cache.MemoryCache::new(@cache.ManualClock::new(0L), 100)
  cache.set(key("a"), img(1))
  cache.set(key("a"), img(2))
  assert_eq(cache.get(key("a")), Some(img(2)))
  assert_eq(cache.count(), 1)
  assert_eq(cache.total_cost(), 4)
}

///|
test "the least recently used image is evicted when the cost limit is exceeded" {
  let cache = @cache.MemoryCache::new(@cache.ManualClock::new(0L), 8)
  cache.set(key("a"), img(1))
  cache.set(key("b"), img(2))
  ignore(cache.get(key("a")))
  cache.set(key("c"), img(3))
  assert_eq(cache.get(key("b")), None)
  assert_eq(cache.get(key("a")), Some(img(1)))
  assert_eq(cache.get(key("c")), Some(img(3)))
  assert_eq(cache.total_cost(), 8)
}

///|
test "an image costing more than the whole limit is not stored" {
  let cache = @cache.MemoryCache::new(@cache.ManualClock::new(0L), 3)
  cache.set(key("a"), img(1))
  assert_eq(cache.get(key("a")), None)
  assert_eq(cache.count(), 0)
}

///|
test "an oversized replacement drops the previous image under that key" {
  let cache = @cache.MemoryCache::new(@cache.ManualClock::new(0L), 4)
  cache.set(key("a"), img(1))
  let big = @image.PixelBuffer::new(2, 1, Bytes::make(8, 0))
  cache.set(key("a"), big)
  assert_eq(cache.get(key("a")), None)
  assert_eq(cache.total_cost(), 0)
}

///|
test "an image expires once its time to live has elapsed" {
  let clock = @cache.ManualClock::new(1000L)
  let cache = @cache.MemoryCache::new(clock, 100, ttl_millis=500L)
  cache.set(key("a"), img(1))
  clock.advance(499L)
  assert_eq(cache.get(key("a")), Some(img(1)))
  clock.advance(1L)
  assert_eq(cache.get(key("a")), None)
  assert_eq(cache.count(), 0)
  assert_eq(cache.total_cost(), 0)
}

///|
test "reading an image does not extend its time to live" {
  let clock = @cache.ManualClock::new(0L)
  let cache = @cache.MemoryCache::new(clock, 100, ttl_millis=500L)
  cache.set(key("a"), img(1))
  clock.advance(300L)
  ignore(cache.get(key("a")))
  clock.advance(200L)
  assert_eq(cache.get(key("a")), None)
}

///|
test "without a time to live images never expire" {
  let clock = @cache.ManualClock::new(0L)
  let cache = @cache.MemoryCache::new(clock, 100)
  cache.set(key("a"), img(1))
  clock.advance(9_000_000_000L)
  assert_eq(cache.get(key("a")), Some(img(1)))
}

///|
test "removing an image releases its cost" {
  let cache = @cache.MemoryCache::new(@cache.ManualClock::new(0L), 100)
  cache.set(key("a"), img(1))
  cache.remove(key("a"))
  cache.remove(key("missing"))
  assert_eq(cache.get(key("a")), None)
  assert_eq(cache.total_cost(), 0)
}

///|
test "clearing the cache removes every image" {
  let cache = @cache.MemoryCache::new(@cache.ManualClock::new(0L), 100)
  cache.set(key("a"), img(1))
  cache.set(key("b"), img(2))
  cache.clear()
  assert_eq(cache.count(), 0)
  assert_eq(cache.total_cost(), 0)
}

///|
test "images processed differently are cached separately" {
  let cache = @cache.MemoryCache::new(@cache.ManualClock::new(0L), 100)
  cache.set(@image.ImageKey::new("a", "p1"), img(1))
  cache.set(@image.ImageKey::new("a", "p2"), img(2))
  assert_eq(cache.get(@image.ImageKey::new("a", "p1")), Some(img(1)))
  assert_eq(cache.get(@image.ImageKey::new("a", "p2")), Some(img(2)))
}
