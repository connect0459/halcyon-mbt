///|
pub struct PngDecoder {
  priv limits : @decode.DecodeLimits
}

///|
pub fn PngDecoder::new(limits? : @decode.DecodeLimits) -> PngDecoder {
  { limits: limits.unwrap_or(@decode.DecodeLimits::default()), }
}

///|
priv struct Pass {
  x0 : Int32
  y0 : Int32
  dx : Int32
  dy : Int32
}

///|
let adam7 : Array[Pass] = [
  { x0: 0, y0: 0, dx: 8, dy: 8, },
  { x0: 4, y0: 0, dx: 8, dy: 8, },
  { x0: 0, y0: 4, dx: 4, dy: 8, },
  { x0: 2, y0: 0, dx: 4, dy: 4, },
  { x0: 0, y0: 2, dx: 2, dy: 4, },
  { x0: 1, y0: 0, dx: 2, dy: 2, },
  { x0: 0, y0: 1, dx: 1, dy: 2, },
]

///|
let single_pass : Array[Pass] = [{ x0: 0, y0: 0, dx: 1, dy: 1, }]

///|
priv struct Transparency {
  gray : Int32
  red : Int32
  green : Int32
  blue : Int32
  alphas : Array[Int32]
}

///|
priv struct Chunks {
  header : Header
  palette : Array[Int32]
  transparency : Transparency
  image_data : Bytes
}

///|
fn is_signature(data : Bytes) -> Bool {
  data.length() >= 8 &&
  data[0] == b'\x89' &&
  data[1] == b'P' &&
  data[2] == b'N' &&
  data[3] == b'G' &&
  data[4] == b'\r' &&
  data[5] == b'\n' &&
  data[6] == b'\x1a' &&
  data[7] == b'\n'
}

///|
fn chunk_name(data : Bytes, at : Int32) -> String {
  let chars = []
  for i in 0..<4 {
    chars.push(data[at + i].to_int().unsafe_to_char())
  }
  String::from_array(chars)
}

///|
fn read_chunks(
  data : Bytes,
  limits : @decode.DecodeLimits,
) -> Chunks raise @decode.DecodeError {
  if !is_signature(data) {
    raise @decode.DecodeError::UnknownFormat
  }
  let mut pos = 8
  let mut header : Header? = None
  let palette : Array[Int32] = []
  let mut has_palette = false
  let mut transparency_bytes : Bytes? = None
  let image_data : Array[Byte] = []
  let mut seen_data = false
  let mut data_ended = false
  let mut finished = false
  while !finished {
    if pos + 8 > data.length() {
      raise @decode.DecodeError::Truncated
    }
    let length = read_u32(data, pos)
    if length < 0 || length > data.length() - pos - 12 {
      raise @decode.DecodeError::Truncated
    }
    let name = chunk_name(data, pos + 4)
    let body = pos + 8
    if crc32(data, pos + 4, body + length) !=
      read_u32(data, body + length).reinterpret_as_uint() {
      raise @decode.DecodeError::Malformed("chunk checksum mismatch in \{name}")
    }
    match header {
      None =>
        if name != "IHDR" {
          raise @decode.DecodeError::Malformed("header chunk is missing")
        }
      Some(_) => ()
    }
    match name {
      "IHDR" =>
        match header {
          Some(_) => raise @decode.DecodeError::Malformed("duplicate header")
          None => header = Some(Header::parse(data, body, length, limits))
        }
      "PLTE" => {
        let h = header.unwrap()
        if seen_data || has_palette {
          raise @decode.DecodeError::Malformed("misplaced palette")
        }
        if h.color_type == 0 || h.color_type == 4 {
          raise @decode.DecodeError::Malformed("palette not allowed")
        }
        if length == 0 || length % 3 != 0 || length / 3 > 256 {
          raise @decode.DecodeError::Malformed("invalid palette length")
        }
        if h.color_type == 3 && length / 3 > 1 << h.bit_depth {
          raise @decode.DecodeError::Malformed("palette larger than bit depth")
        }
        has_palette = true
        for i in 0..<length {
          palette.push(data[body + i].to_int())
        }
      }
      "tRNS" =>
        if !seen_data {
          transparency_bytes = Some(data[body:body + length].to_owned())
        }
      "IDAT" => {
        if data_ended {
          raise @decode.DecodeError::Malformed("image data is not contiguous")
        }
        let h = header.unwrap()
        if h.color_type == 3 && !has_palette {
          raise @decode.DecodeError::Malformed("palette is missing")
        }
        seen_data = true
        for i in 0..<length {
          image_data.push(data[body + i])
        }
      }
      "IEND" => finished = true
      _ => {
        let first = data[pos + 4].to_int()
        if (first & 0x20) == 0 {
          raise @decode.DecodeError::Unsupported("critical chunk \{name}")
        }
      }
    }
    if seen_data && name != "IDAT" {
      data_ended = true
    }
    pos = body + length + 4
  }
  if !seen_data {
    raise @decode.DecodeError::Malformed("image data is missing")
  }
  let h = header.unwrap()
  {
    header: h,
    palette,
    transparency: parse_transparency(
      h,
      transparency_bytes,
      palette.length() / 3,
    ),
    image_data: Bytes::from_array(image_data),
  }
}

///|
fn parse_transparency(
  header : Header,
  raw : Bytes?,
  palette_size : Int32,
) -> Transparency {
  let none = { gray: -1, red: -1, green: -1, blue: -1, alphas: [], }
  match raw {
    None => none
    Some(bytes) =>
      match header.color_type {
        0 if bytes.length() >= 2 =>
          { ..none, gray: (bytes[0].to_int() << 8) | bytes[1].to_int(), }
        2 if bytes.length() >= 6 =>
          {
            ..none,
            red: (bytes[0].to_int() << 8) | bytes[1].to_int(),
            green: (bytes[2].to_int() << 8) | bytes[3].to_int(),
            blue: (bytes[4].to_int() << 8) | bytes[5].to_int(),
          }
        3 => {
          let alphas = []
          for
            i in 0..<(if bytes.length() < palette_size {
              bytes.length()
            } else {
              palette_size
            }) {
            alphas.push(bytes[i].to_int())
          }
          { ..none, alphas, }
        }
        _ => none
      }
  }
}

///|
fn pass_size(total : Int32, start : Int32, step : Int32) -> Int32 {
  if total <= start {
    0
  } else {
    (total - start + step - 1) / step
  }
}

///|
fn read_sample(
  row : Array[Byte],
  base : Int32,
  index : Int32,
  depth : Int32,
) -> Int32 {
  match depth {
    8 => row[base + index].to_int()
    16 =>
      (row[base + index * 2].to_int() << 8) | row[base + index * 2 + 1].to_int()
    _ => {
      let bit = index * depth
      let byte = row[base + bit / 8].to_int()
      let shift = 8 - depth - bit % 8
      (byte >> shift) & ((1 << depth) - 1)
    }
  }
}

///|
fn scale_to_byte(value : Int32, depth : Int32) -> Int32 {
  match depth {
    16 => (value * 255 + 32895) >> 16
    8 => value
    _ => value * 255 / ((1 << depth) - 1)
  }
}

///|
fn to_rgba(
  chunks : Chunks,
  samples : Array[Int32],
) -> (Int32, Int32, Int32, Int32) raise @decode.DecodeError {
  let h = chunks.header
  let t = chunks.transparency
  let depth = h.bit_depth
  match h.color_type {
    0 => {
      let g = scale_to_byte(samples[0], depth)
      (g, g, g, if samples[0] == t.gray { 0 } else { 255 })
    }
    2 => {
      let transparent = samples[0] == t.red &&
        samples[1] == t.green &&
        samples[2] == t.blue
      (
        scale_to_byte(samples[0], depth),
        scale_to_byte(samples[1], depth),
        scale_to_byte(samples[2], depth),
        if transparent {
          0
        } else {
          255
        },
      )
    }
    3 => {
      let index = samples[0]
      if index * 3 + 2 >= chunks.palette.length() {
        raise @decode.DecodeError::Malformed("palette index out of range")
      }
      (
        chunks.palette[index * 3],
        chunks.palette[index * 3 + 1],
        chunks.palette[index * 3 + 2],
        if index < t.alphas.length() {
          t.alphas[index]
        } else {
          255
        },
      )
    }
    4 => {
      let g = scale_to_byte(samples[0], depth)
      (g, g, g, scale_to_byte(samples[1], depth))
    }
    _ =>
      (
        scale_to_byte(samples[0], depth),
        scale_to_byte(samples[1], depth),
        scale_to_byte(samples[2], depth),
        scale_to_byte(samples[3], depth),
      )
  }
}

///|
fn decode_pixels(chunks : Chunks) -> Array[Byte] raise @decode.DecodeError {
  let h = chunks.header
  let passes = if h.interlaced { adam7 } else { single_pass }
  let bpp_bits = h.bits_per_pixel()
  let bytes_per_pixel = if bpp_bits >= 8 { bpp_bits / 8 } else { 1 }
  let mut expected = 0
  for pass in passes {
    let pw = pass_size(h.width, pass.x0, pass.dx)
    let ph = pass_size(h.height, pass.y0, pass.dy)
    if pw > 0 && ph > 0 {
      expected += ph * (1 + (pw * bpp_bits + 7) / 8)
    }
  }
  let raw = @inflate.zlib_decompress(chunks.image_data, max_output=expected) catch {
    @inflate.InflateError::OutputLimitExceeded =>
      raise @decode.DecodeError::Malformed("excess image data")
    @inflate.InflateError::UnexpectedEnd => raise @decode.DecodeError::Truncated
    _ => raise @decode.DecodeError::Malformed("invalid compressed data")
  }
  if raw.length() < expected {
    raise @decode.DecodeError::Truncated
  }
  let out = Array::make(h.width * h.height * 4, b'\x00')
  let samples = Array::make(h.channels(), 0)
  let mut offset = 0
  for pass in passes {
    let pw = pass_size(h.width, pass.x0, pass.dx)
    let ph = pass_size(h.height, pass.y0, pass.dy)
    if pw > 0 && ph > 0 {
      let stride = (pw * bpp_bits + 7) / 8
      let rows = unfilter(raw, offset, ph, stride, bytes_per_pixel)
      offset += ph * (stride + 1)
      for py in 0..<ph {
        for px in 0..<pw {
          for c in 0..<h.channels() {
            samples[c] = read_sample(
              rows,
              py * stride,
              px * h.channels() + c,
              h.bit_depth,
            )
          }
          let (r, g, b, a) = to_rgba(chunks, samples)
          let x = pass.x0 + px * pass.dx
          let y = pass.y0 + py * pass.dy
          let at = (y * h.width + x) * 4
          out[at] = r.to_byte()
          out[at + 1] = g.to_byte()
          out[at + 2] = b.to_byte()
          out[at + 3] = a.to_byte()
        }
      }
    }
  }
  out
}

///|
pub impl @decode.ImageDecoder for PngDecoder with fn format(_self) {
  Png
}

///|
pub fn PngDecoder::decode(
  self : PngDecoder,
  data : Bytes,
) -> @image.PixelBuffer raise @decode.DecodeError {
  let chunks = read_chunks(data, self.limits)
  let pixels = decode_pixels(chunks)
  try! @image.PixelBuffer::new(
    chunks.header.width,
    chunks.header.height,
    Bytes::from_array(pixels),
  )
}

///|
pub impl @decode.ImageDecoder for PngDecoder with fn decode(self, data) {
  PngDecoder::decode(self, data)
}
