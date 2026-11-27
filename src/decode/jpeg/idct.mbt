///|
fn descale(value : Int32, bits : Int32) -> Int32 {
  (value + (1 << (bits - 1))) >> bits
}

///|
fn clamp_sample(value : Int32) -> Int32 {
  if value < 0 {
    0
  } else if value > 255 {
    255
  } else {
    value
  }
}

///|
fn idct_block(
  coefficients : Array[Int32],
  offset : Int32,
  quant : Array[Int32],
  workspace : Array[Int32],
  plane : Array[Int32],
  plane_offset : Int32,
  stride : Int32,
) -> Unit {
  for column in 0..<8 {
    let z2 = coefficients[offset + 16 + column] * quant[16 + column]
    let z3 = coefficients[offset + 48 + column] * quant[48 + column]
    let z1 = (z2 + z3) * 4433
    let tmp2 = z1 + z3 * -15137
    let tmp3 = z1 + z2 * 6270
    let a = coefficients[offset + column] * quant[column]
    let b = coefficients[offset + 32 + column] * quant[32 + column]
    let tmp0 = (a + b) << 13
    let tmp1 = (a - b) << 13
    let tmp10 = tmp0 + tmp3
    let tmp13 = tmp0 - tmp3
    let tmp11 = tmp1 + tmp2
    let tmp12 = tmp1 - tmp2
    let o0 = coefficients[offset + 56 + column] * quant[56 + column]
    let o1 = coefficients[offset + 40 + column] * quant[40 + column]
    let o2 = coefficients[offset + 24 + column] * quant[24 + column]
    let o3 = coefficients[offset + 8 + column] * quant[8 + column]
    let (t0, t1, t2, t3) = odd_part(o0, o1, o2, o3)
    workspace[column] = descale(tmp10 + t3, 11)
    workspace[56 + column] = descale(tmp10 - t3, 11)
    workspace[8 + column] = descale(tmp11 + t2, 11)
    workspace[48 + column] = descale(tmp11 - t2, 11)
    workspace[16 + column] = descale(tmp12 + t1, 11)
    workspace[40 + column] = descale(tmp12 - t1, 11)
    workspace[24 + column] = descale(tmp13 + t0, 11)
    workspace[32 + column] = descale(tmp13 - t0, 11)
  }
  for row in 0..<8 {
    let base = row * 8
    let z2 = workspace[base + 2]
    let z3 = workspace[base + 6]
    let z1 = (z2 + z3) * 4433
    let tmp2 = z1 + z3 * -15137
    let tmp3 = z1 + z2 * 6270
    let tmp0 = (workspace[base] + workspace[base + 4]) << 13
    let tmp1 = (workspace[base] - workspace[base + 4]) << 13
    let tmp10 = tmp0 + tmp3
    let tmp13 = tmp0 - tmp3
    let tmp11 = tmp1 + tmp2
    let tmp12 = tmp1 - tmp2
    let (t0, t1, t2, t3) = odd_part(
      workspace[base + 7],
      workspace[base + 5],
      workspace[base + 3],
      workspace[base + 1],
    )
    let out = plane_offset + row * stride
    plane[out] = clamp_sample(descale(tmp10 + t3, 18) + 128)
    plane[out + 7] = clamp_sample(descale(tmp10 - t3, 18) + 128)
    plane[out + 1] = clamp_sample(descale(tmp11 + t2, 18) + 128)
    plane[out + 6] = clamp_sample(descale(tmp11 - t2, 18) + 128)
    plane[out + 2] = clamp_sample(descale(tmp12 + t1, 18) + 128)
    plane[out + 5] = clamp_sample(descale(tmp12 - t1, 18) + 128)
    plane[out + 3] = clamp_sample(descale(tmp13 + t0, 18) + 128)
    plane[out + 4] = clamp_sample(descale(tmp13 - t0, 18) + 128)
  }
}

///|
fn odd_part(
  in0 : Int32,
  in1 : Int32,
  in2 : Int32,
  in3 : Int32,
) -> (Int32, Int32, Int32, Int32) {
  let z1 = in0 + in3
  let z2 = in1 + in2
  let z3 = in0 + in2
  let z4 = in1 + in3
  let z5 = (z3 + z4) * 9633
  let t0 = in0 * 2446
  let t1 = in1 * 16819
  let t2 = in2 * 25172
  let t3 = in3 * 12299
  let y1 = z1 * -7373
  let y2 = z2 * -20995
  let y3 = z3 * -16069 + z5
  let y4 = z4 * -3196 + z5
  (t0 + y1 + y3, t1 + y2 + y4, t2 + y2 + y3, t3 + y1 + y4)
}
