///|
test "the checksum of the standard check string matches the published value" {
  let data = b"123456789"
  assert_eq(crc32(data, 0, 9), 0xCBF43926U)
}

///|
test "the checksum of no data is zero" {
  assert_eq(crc32(b"", 0, 0), 0U)
}
