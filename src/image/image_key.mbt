///|
#derive(Eq, Hash, Debug)
pub struct ImageKey {
  priv source : String
  priv processor_id : String
}

///|
pub fn ImageKey::new(source : String, processor_id : String) -> ImageKey {
  { source, processor_id, }
}

///|
pub fn ImageKey::of_source(source : String) -> ImageKey {
  { source, processor_id: "", }
}

///|
pub fn ImageKey::source(self : ImageKey) -> String {
  self.source
}

///|
pub fn ImageKey::processor_id(self : ImageKey) -> String {
  self.processor_id
}

///|
pub impl Show for ImageKey with fn output(self, logger) {
  logger.write_string(self.source)
  if self.processor_id != "" {
    logger.write_string("#")
    logger.write_string(self.processor_id)
  }
}
