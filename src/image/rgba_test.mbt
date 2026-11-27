///|
test "a pixel exposes its four channels" {
  let pixel = @image.Rgba::new(1, 2, 3, 4)
  assert_eq((pixel.r(), pixel.g(), pixel.b(), pixel.a()), (1, 2, 3, 4))
}
