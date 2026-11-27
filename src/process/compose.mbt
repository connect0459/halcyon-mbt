///|
pub struct Compose {
  priv steps : Array[&ImageProcessor]
}

///|
pub fn Compose::new(steps : Array[&ImageProcessor]) -> Compose {
  { steps: steps.copy(), }
}

///|
pub impl ImageProcessor for Compose with fn identifier(self) {
  self.steps.map(step => step.identifier()).join("|")
}

///|
pub impl ImageProcessor for Compose with fn process(self, source) {
  let mut current = source
  for step in self.steps {
    current = step.process(current)
  }
  current
}
