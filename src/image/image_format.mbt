///|
#derive(Eq, Hash, Debug)
pub(all) enum ImageFormat {
  Png
  Jpeg
}

///|
pub impl Show for ImageFormat with fn output(self, logger) {
  match self {
    Png => logger.write_string("png")
    Jpeg => logger.write_string("jpeg")
  }
}
