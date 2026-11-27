///|
pub(open) trait Clock {
  fn now_millis(Self) -> Int64
}

///|
pub struct ManualClock {
  priv mut now : Int64
}

///|
pub fn ManualClock::new(start : Int64) -> ManualClock {
  { now: start, }
}

///|
pub fn ManualClock::advance(self : ManualClock, millis : Int64) -> Unit {
  self.now = self.now + millis
}

///|
pub impl Clock for ManualClock with fn now_millis(self) {
  self.now
}
