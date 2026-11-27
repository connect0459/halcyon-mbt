///|
pub struct JpegDecoder {
  priv limits : @decode.DecodeLimits
}

///|
pub fn JpegDecoder::new(limits? : @decode.DecodeLimits) -> JpegDecoder {
  { limits: limits.unwrap_or(@decode.DecodeLimits::default()), }
}

///|
priv struct Tables {
  quant : Array[Array[Int32]?]
  dc : Array[Huffman?]
  ac : Array[Huffman?]
}

///|
priv enum ColorSpace {
  Gray
  YCbCr
  Rgb
}

///|
fn parse_quant(
  data : Bytes,
  start : Int32,
  length : Int32,
  tables : Tables,
) -> Unit raise @decode.DecodeError {
  let mut at = start
  let end = start + length
  while at < end {
    let precision = data[at].to_int() >> 4
    let slot = data[at].to_int() & 15
    if precision > 1 || slot > 3 {
      raise @decode.DecodeError::Malformed("invalid quantization table")
    }
    let size = if precision == 0 { 64 } else { 128 }
    if at + 1 + size > end {
      raise @decode.DecodeError::Malformed("invalid quantization table length")
    }
    let table = Array::make(64, 0)
    for k in 0..<64 {
      table[natural_order[k]] = if precision == 0 {
        data[at + 1 + k].to_int()
      } else {
        read_u16(data, at + 1 + k * 2)
      }
    }
    tables.quant[slot] = Some(table)
    at += 1 + size
  }
}

///|
fn parse_huffman(
  data : Bytes,
  start : Int32,
  length : Int32,
  tables : Tables,
) -> Unit raise @decode.DecodeError {
  let mut at = start
  let end = start + length
  while at < end {
    if at + 17 > end {
      raise @decode.DecodeError::Malformed("invalid Huffman table length")
    }
    let class = data[at].to_int() >> 4
    let slot = data[at].to_int() & 15
    if class > 1 || slot > 3 {
      raise @decode.DecodeError::Malformed("invalid Huffman table")
    }
    let counts = Array::makei(16, i => data[at + 1 + i].to_int())
    let total = counts.fold(init=0, (a, b) => a + b)
    if total > 256 || at + 17 + total > end {
      raise @decode.DecodeError::Malformed("invalid Huffman table length")
    }
    let values = Array::makei(total, i => data[at + 17 + i].to_int())
    let table = Huffman::new(counts, values)
    if class == 0 {
      tables.dc[slot] = Some(table)
    } else {
      tables.ac[slot] = Some(table)
    }
    at += 17 + total
  }
}

///|
fn next_marker(
  data : Bytes,
  from : Int32,
) -> (Int32, Int32) raise @decode.DecodeError {
  let mut at = from
  while at + 1 < data.length() {
    if data[at] == b'\xff' {
      let marker = data[at + 1].to_int()
      if marker != 0 && marker != 0xFF {
        return (marker, at + 2)
      }
    }
    at += 1
  }
  raise @decode.DecodeError::Truncated
}

///|
fn parse_scan_header(
  data : Bytes,
  start : Int32,
  length : Int32,
  frame : Frame,
  tables : Tables,
) -> Scan raise @decode.DecodeError {
  if length < 1 {
    raise @decode.DecodeError::Malformed("invalid scan header length")
  }
  let count = data[start].to_int()
  if count < 1 || count > frame.components.length() || length != 4 + count * 2 {
    raise @decode.DecodeError::Malformed("invalid scan header")
  }
  let entries : Array[ScanComponent] = []
  for i in 0..<count {
    let id = data[start + 1 + i * 2].to_int()
    let selectors = data[start + 2 + i * 2].to_int()
    let mut found : Component? = None
    for c in frame.components {
      if c.id == id {
        found = Some(c)
      }
    }
    let component = match found {
      Some(c) => c
      None =>
        raise @decode.DecodeError::Malformed(
          "scan refers to an unknown component",
        )
    }
    for entry in entries {
      if entry.component.id == id {
        raise @decode.DecodeError::Malformed("component repeated in scan")
      }
    }
    if component.quant is None {
      component.quant = match tables.quant[component.quant_slot] {
        Some(q) => Some(q)
        None =>
          raise @decode.DecodeError::Malformed("missing quantization table")
      }
    }
    let dc_slot = selectors >> 4
    let ac_slot = selectors & 15
    if dc_slot > 3 || ac_slot > 3 {
      raise @decode.DecodeError::Malformed("invalid Huffman table selector")
    }
    entries.push({
      component,
      dc_table: tables.dc[dc_slot],
      ac_table: tables.ac[ac_slot],
    })
  }
  let ss = data[start + 1 + count * 2].to_int()
  let se = data[start + 2 + count * 2].to_int()
  let ah = data[start + 3 + count * 2].to_int() >> 4
  let al = data[start + 3 + count * 2].to_int() & 15
  if frame.progressive {
    if ss > se || se > 63 || al > 13 {
      raise @decode.DecodeError::Malformed("invalid spectral selection")
    }
    if ss == 0 && se != 0 {
      raise @decode.DecodeError::Malformed("invalid spectral selection")
    }
    if ss > 0 && count != 1 {
      raise @decode.DecodeError::Malformed("AC scan must hold one component")
    }
    if ah != 0 && ah != al + 1 {
      raise @decode.DecodeError::Malformed("invalid successive approximation")
    }
  }
  {
    components: entries,
    ss,
    se,
    ah,
    al,
    progressive: frame.progressive,
    reader: BitReader::new(data, 0),
    eob_run: 0,
  }
}

///|
fn reconstruct(frame : Frame) -> Array[Plane] raise @decode.DecodeError {
  let workspace = Array::make(64, 0)
  let planes = []
  for c in frame.components {
    let quant = match c.quant {
      Some(q) => q
      None =>
        raise @decode.DecodeError::Malformed("component was never scanned")
    }
    let stride = c.blocks_w * 8
    let samples = Array::make(stride * c.blocks_h * 8, 0)
    for by in 0..<c.blocks_h {
      for bx in 0..<c.blocks_w {
        idct_block(
          c.coefficients,
          (by * c.blocks_w + bx) * 64,
          quant,
          workspace,
          samples,
          by * 8 * stride + bx * 8,
          stride,
        )
      }
    }
    let cropped = Array::make(c.plane_width * c.plane_height, 0)
    for y in 0..<c.plane_height {
      for x in 0..<c.plane_width {
        cropped[y * c.plane_width + x] = samples[y * stride + x]
      }
    }
    planes.push({
      width: c.plane_width,
      height: c.plane_height,
      samples: cropped,
    })
  }
  planes
}

///|
fn choose_color_space(
  frame : Frame,
  jfif : Bool,
  adobe_transform : Int32?,
) -> ColorSpace raise @decode.DecodeError {
  if frame.components.length() == 1 {
    return Gray
  }
  if jfif {
    return YCbCr
  }
  match adobe_transform {
    Some(0) => Rgb
    Some(1) => YCbCr
    Some(_) => raise @decode.DecodeError::Unsupported("Adobe color transform")
    None => {
      let ids = frame.components.map(c => c.id)
      if ids == [82, 71, 66] {
        Rgb
      } else {
        YCbCr
      }
    }
  }
}

///|
fn to_pixels(
  frame : Frame,
  planes : Array[Plane],
  space : ColorSpace,
) -> Array[Byte] {
  let full = []
  for i, c in frame.components {
    full.push(
      upsample(
        planes[i],
        frame.h_max / c.h,
        frame.v_max / c.v,
        frame.width,
        frame.height,
      ),
    )
  }
  let out = Array::make(frame.width * frame.height * 4, b'\xff')
  for i in 0..<(frame.width * frame.height) {
    let (r, g, b) = match space {
      Gray => (full[0].samples[i], full[0].samples[i], full[0].samples[i])
      Rgb => (full[0].samples[i], full[1].samples[i], full[2].samples[i])
      YCbCr => {
        let y = full[0].samples[i]
        let cb = full[1].samples[i]
        let cr = full[2].samples[i]
        (ycc_red(y, cr), ycc_green(y, cb, cr), ycc_blue(y, cb))
      }
    }
    out[i * 4] = r.to_byte()
    out[i * 4 + 1] = g.to_byte()
    out[i * 4 + 2] = b.to_byte()
  }
  out
}

///|
pub fn JpegDecoder::decode(
  self : JpegDecoder,
  data : Bytes,
) -> @image.PixelBuffer raise @decode.DecodeError {
  if data.length() < 2 || data[0] != b'\xff' || data[1] != b'\xd8' {
    raise @decode.DecodeError::UnknownFormat
  }
  let tables : Tables = {
    quant: Array::make(4, None),
    dc: Array::make(4, None),
    ac: Array::make(4, None),
  }
  let mut frame : Frame? = None
  let mut restart_interval = 0
  let mut jfif = false
  let mut adobe_transform : Int32? = None
  let mut scans = 0
  let mut pos = 2
  while true {
    let (marker, after) = next_marker(data, pos)
    if marker == 0xD9 {
      break
    }
    if marker == 0xD8 || (marker >= 0xD0 && marker <= 0xD7) || marker == 0x01 {
      pos = after
      continue
    }
    if after + 2 > data.length() {
      raise @decode.DecodeError::Truncated
    }
    let length = read_u16(data, after) - 2
    if length < 0 || after + 2 + length > data.length() {
      raise @decode.DecodeError::Truncated
    }
    let body = after + 2
    pos = body + length
    match marker {
      0xC0 | 0xC1 | 0xC2 => {
        if frame is Some(_) {
          raise @decode.DecodeError::Malformed("duplicate frame header")
        }
        frame = Some(
          Frame::parse(data, body, length, marker == 0xC2, self.limits),
        )
      }
      0xC3 | 0xC5 | 0xC6 | 0xC7 | 0xC9 | 0xCA | 0xCB | 0xCD | 0xCE | 0xCF =>
        raise @decode.DecodeError::Unsupported("JPEG process")
      0xC4 => parse_huffman(data, body, length, tables)
      0xDB => parse_quant(data, body, length, tables)
      0xDD => {
        if length != 2 {
          raise @decode.DecodeError::Malformed(
            "invalid restart interval length",
          )
        }
        restart_interval = read_u16(data, body)
      }
      0xE0 =>
        if length >= 5 && data[body:body + 5] == b"JFIF\x00"[:] {
          jfif = true
        }
      0xEE =>
        if length >= 12 && data[body:body + 5] == b"Adobe"[:] {
          adobe_transform = Some(data[body + 11].to_int())
        }
      0xDA => {
        let current = match frame {
          Some(f) => f
          None =>
            raise @decode.DecodeError::Malformed("scan before frame header")
        }
        let scan = parse_scan_header(data, body, length, current, tables)
        let reader = BitReader::new(data, pos)
        let live : Scan = { ..scan, reader, }
        run_scan(current, live, restart_interval)
        pos = reader.pos
        scans += 1
      }
      _ => ()
    }
  }
  let current = match frame {
    Some(f) => f
    None => raise @decode.DecodeError::Malformed("frame header is missing")
  }
  if scans == 0 {
    raise @decode.DecodeError::Malformed("image data is missing")
  }
  let space = choose_color_space(current, jfif, adobe_transform)
  let planes = reconstruct(current)
  let pixels = to_pixels(current, planes, space)
  try! @image.PixelBuffer::new(
    current.width,
    current.height,
    Bytes::from_array(pixels),
  )
}

///|
pub impl @decode.ImageDecoder for JpegDecoder with fn format(_self) {
  Jpeg
}

///|
pub impl @decode.ImageDecoder for JpegDecoder with fn decode(self, data) {
  JpegDecoder::decode(self, data)
}
