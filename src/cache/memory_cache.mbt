///|
priv struct Entry {
  value : @image.PixelBuffer
  cost : Int32
  stored_at : Int64
  mut last_used : Int32
}

///|
pub struct MemoryCache {
  priv clock : &Clock
  priv max_cost : Int32
  priv ttl_millis : Int64?
  priv entries : Map[@image.ImageKey, Entry]
  priv mut total_cost : Int32
  priv mut tick : Int32
}

///|
pub fn MemoryCache::new(
  clock : &Clock,
  max_cost : Int32,
  ttl_millis? : Int64,
) -> MemoryCache {
  { clock, max_cost, ttl_millis, entries: {}, total_cost: 0, tick: 0, }
}

///|
pub fn MemoryCache::total_cost(self : MemoryCache) -> Int32 {
  self.total_cost
}

///|
pub fn MemoryCache::count(self : MemoryCache) -> Int32 {
  self.entries.length()
}

///|
fn MemoryCache::is_expired(self : MemoryCache, entry : Entry) -> Bool {
  match self.ttl_millis {
    Some(ttl) => self.clock.now_millis() - entry.stored_at >= ttl
    None => false
  }
}

///|
fn MemoryCache::next_tick(self : MemoryCache) -> Int32 {
  self.tick = self.tick + 1
  self.tick
}

///|
pub fn MemoryCache::remove(self : MemoryCache, key : @image.ImageKey) -> Unit {
  match self.entries.get(key) {
    Some(entry) => {
      self.entries.remove(key)
      self.total_cost = self.total_cost - entry.cost
    }
    None => ()
  }
}

///|
pub fn MemoryCache::clear(self : MemoryCache) -> Unit {
  self.entries.clear()
  self.total_cost = 0
}

///|
pub fn MemoryCache::get(
  self : MemoryCache,
  key : @image.ImageKey,
) -> @image.PixelBuffer? {
  match self.entries.get(key) {
    None => None
    Some(entry) =>
      if self.is_expired(entry) {
        self.remove(key)
        None
      } else {
        entry.last_used = self.next_tick()
        Some(entry.value)
      }
  }
}

///|
pub fn MemoryCache::set(
  self : MemoryCache,
  key : @image.ImageKey,
  value : @image.PixelBuffer,
) -> Unit {
  self.remove(key)
  let cost = value.byte_size()
  if cost > self.max_cost {
    return
  }
  self.entries[key] = {
    value,
    cost,
    stored_at: self.clock.now_millis(),
    last_used: self.next_tick(),
  }
  self.total_cost = self.total_cost + cost
  self.evict_to_fit()
}

///|
fn MemoryCache::least_recently_used(self : MemoryCache) -> @image.ImageKey? {
  let mut oldest : (@image.ImageKey, Int32)? = None
  for key, entry in self.entries {
    match oldest {
      Some((_, tick)) if tick <= entry.last_used => ()
      _ => oldest = Some((key, entry.last_used))
    }
  }
  oldest.map(pair => pair.0)
}

///|
fn MemoryCache::evict_to_fit(self : MemoryCache) -> Unit {
  while self.total_cost > self.max_cost &&
        self.least_recently_used() is Some(key) {
    self.remove(key)
  }
}
