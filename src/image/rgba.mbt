///|
#derive(Eq, Debug)
pub struct Rgba {
  priv r : Int32
  priv g : Int32
  priv b : Int32
  priv a : Int32
}

///|
pub fn Rgba::new(r : Int32, g : Int32, b : Int32, a : Int32) -> Rgba {
  { r, g, b, a, }
}

///|
pub fn Rgba::r(self : Rgba) -> Int32 {
  self.r
}

///|
pub fn Rgba::g(self : Rgba) -> Int32 {
  self.g
}

///|
pub fn Rgba::b(self : Rgba) -> Int32 {
  self.b
}

///|
pub fn Rgba::a(self : Rgba) -> Int32 {
  self.a
}
