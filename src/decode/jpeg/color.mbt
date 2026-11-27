///|
fn ycc_red(y : Int32, cr : Int32) -> Int32 {
  clamp_sample(y + ((91881 * (cr - 128) + 32768) >> 16))
}

///|
fn ycc_blue(y : Int32, cb : Int32) -> Int32 {
  clamp_sample(y + ((116130 * (cb - 128) + 32768) >> 16))
}

///|
fn ycc_green(y : Int32, cb : Int32, cr : Int32) -> Int32 {
  clamp_sample(y + ((-22554 * (cb - 128) + 32768 + -46802 * (cr - 128)) >> 16))
}
