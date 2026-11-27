///|
priv struct Component {
  id : Int32
  h : Int32
  v : Int32
  quant_slot : Int32
  blocks_w : Int32
  blocks_h : Int32
  scan_blocks_w : Int32
  scan_blocks_h : Int32
  plane_width : Int32
  plane_height : Int32
  coefficients : Array[Int32]
  mut quant : Array[Int32]?
  mut dc_pred : Int32
}

///|
priv struct Frame {
  width : Int32
  height : Int32
  progressive : Bool
  h_max : Int32
  v_max : Int32
  mcus_x : Int32
  mcus_y : Int32
  components : Array[Component]
}

///|
fn ceil_div(a : Int32, b : Int32) -> Int32 {
  (a + b - 1) / b
}

///|
fn read_u16(data : Bytes, at : Int32) -> Int32 {
  (data[at].to_int() << 8) | data[at + 1].to_int()
}

///|
fn Frame::parse(
  data : Bytes,
  start : Int32,
  length : Int32,
  progressive : Bool,
  limits : @decode.DecodeLimits,
) -> Frame raise @decode.DecodeError {
  if length < 6 {
    raise @decode.DecodeError::Malformed("invalid frame header length")
  }
  let precision = data[start].to_int()
  let height = read_u16(data, start + 1)
  let width = read_u16(data, start + 3)
  let count = data[start + 5].to_int()
  if precision != 8 {
    raise @decode.DecodeError::Unsupported("sample precision")
  }
  if width == 0 || height == 0 {
    raise @decode.DecodeError::Malformed("invalid dimensions")
  }
  if count != 1 && count != 3 {
    raise @decode.DecodeError::Unsupported("component count")
  }
  if length != 6 + count * 3 {
    raise @decode.DecodeError::Malformed("invalid frame header length")
  }
  limits.check(width, height)
  let specs = []
  let mut h_max = 1
  let mut v_max = 1
  for i in 0..<count {
    let at = start + 6 + i * 3
    let id = data[at].to_int()
    let h = data[at + 1].to_int() >> 4
    let v = data[at + 1].to_int() & 15
    let quant_slot = data[at + 2].to_int()
    if h < 1 || h > 4 || v < 1 || v > 4 {
      raise @decode.DecodeError::Malformed("invalid sampling factor")
    }
    if quant_slot > 3 {
      raise @decode.DecodeError::Malformed("invalid quantization table index")
    }
    specs.push((id, h, v, quant_slot))
    h_max = if h > h_max { h } else { h_max }
    v_max = if v > v_max { v } else { v_max }
  }
  let mcus_x = ceil_div(width, 8 * h_max)
  let mcus_y = ceil_div(height, 8 * v_max)
  let components = []
  for spec in specs {
    let (id, h, v, quant_slot) = spec
    if h_max % h != 0 || v_max % v != 0 {
      raise @decode.DecodeError::Unsupported("non-integral sampling ratio")
    }
    let plane_width = ceil_div(width * h, h_max)
    let plane_height = ceil_div(height * v, v_max)
    let blocks_w = mcus_x * h
    let blocks_h = mcus_y * v
    components.push({
      id,
      h,
      v,
      quant_slot,
      blocks_w,
      blocks_h,
      scan_blocks_w: ceil_div(plane_width, 8),
      scan_blocks_h: ceil_div(plane_height, 8),
      plane_width,
      plane_height,
      coefficients: Array::make(blocks_w * blocks_h * 64, 0),
      quant: None,
      dc_pred: 0,
    })
  }
  { width, height, progressive, h_max, v_max, mcus_x, mcus_y, components, }
}
