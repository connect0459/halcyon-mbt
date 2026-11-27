///|
fn paeth(a : Int32, b : Int32, c : Int32) -> Int32 {
  let p = a + b - c
  let pa = (p - a).abs()
  let pb = (p - b).abs()
  let pc = (p - c).abs()
  if pa <= pb && pa <= pc {
    a
  } else if pb <= pc {
    b
  } else {
    c
  }
}

///|
fn unfilter(
  raw : Bytes,
  offset : Int32,
  rows : Int32,
  stride : Int32,
  bytes_per_pixel : Int32,
) -> Array[Byte] raise @decode.DecodeError {
  let out = Array::make(rows * stride, b'\x00')
  for row in 0..<rows {
    let src = offset + row * (stride + 1)
    let dst = row * stride
    let filter = raw[src].to_int()
    for i in 0..<stride {
      let x = raw[src + 1 + i].to_int()
      let a = if i >= bytes_per_pixel {
        out[dst + i - bytes_per_pixel].to_int()
      } else {
        0
      }
      let b = if row > 0 { out[dst - stride + i].to_int() } else { 0 }
      let c = if row > 0 && i >= bytes_per_pixel {
        out[dst - stride + i - bytes_per_pixel].to_int()
      } else {
        0
      }
      let value = match filter {
        0 => x
        1 => x + a
        2 => x + b
        3 => x + (a + b) / 2
        4 => x + paeth(a, b, c)
        _ => raise @decode.DecodeError::Malformed("invalid filter type")
      }
      out[dst + i] = (value & 0xFF).to_byte()
    }
  }
  out
}
