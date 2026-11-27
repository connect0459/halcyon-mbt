///|
let crc_table : Array[UInt32] = build_crc_table()

///|
fn build_crc_table() -> Array[UInt32] {
  let table = Array::make(256, 0U)
  for n in 0..<256 {
    let mut c = n.reinterpret_as_uint()
    for _ in 0..<8 {
      c = if (c & 1U) != 0U { 0xEDB88320U ^ (c >> 1) } else { c >> 1 }
    }
    table[n] = c
  }
  table
}

///|
fn crc32(data : Bytes, start : Int32, end : Int32) -> UInt32 {
  let mut c = 0xFFFFFFFFU
  for i in start..<end {
    c = crc_table[((c ^ data[i].to_uint()) & 0xFFU).reinterpret_as_int()] ^
      (c >> 8)
  }
  c ^ 0xFFFFFFFFU
}
