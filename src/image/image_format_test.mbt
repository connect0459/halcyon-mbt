///|
test "formats are named by their conventional label" {
  assert_eq(Show::to_string(@image.ImageFormat::Png), "png")
  assert_eq(Show::to_string(@image.ImageFormat::Jpeg), "jpeg")
}
