///|
#derive(Eq, Debug)
pub(all) suberror InflateError {
  InvalidHeader
  UnsupportedDictionary
  UnexpectedEnd
  InvalidBlockType
  InvalidStoredLength
  InvalidCodeLengths
  InvalidSymbol
  InvalidDistance
  OutputLimitExceeded
  ChecksumMismatch
}

///|
priv struct BitReader {
  data : Bytes
  mut pos : Int32
  mut bit_buffer : Int32
  mut bit_count : Int32
}

///|
fn BitReader::new(data : Bytes, pos : Int32) -> BitReader {
  { data, pos, bit_buffer: 0, bit_count: 0, }
}

///|
fn BitReader::bits(self : BitReader, need : Int32) -> Int32 raise InflateError {
  while self.bit_count < need {
    if self.pos >= self.data.length() {
      raise UnexpectedEnd
    }
    self.bit_buffer = self.bit_buffer |
      (self.data[self.pos].to_int() << self.bit_count)
    self.pos += 1
    self.bit_count += 8
  }
  let value = self.bit_buffer & ((1 << need) - 1)
  self.bit_buffer = self.bit_buffer >> need
  self.bit_count -= need
  value
}

///|
fn BitReader::align_to_byte(self : BitReader) -> Unit {
  self.bit_buffer = 0
  self.bit_count = 0
}

///|
priv struct Huffman {
  counts : Array[Int32]
  symbols : Array[Int32]
}

///|
fn Huffman::from_lengths(lengths : ArrayView[Int32]) -> Huffman {
  let counts = Array::make(16, 0)
  for length in lengths {
    counts[length] += 1
  }
  let offsets = Array::make(16, 0)
  for len in 1..<15 {
    offsets[len + 1] = offsets[len] + counts[len]
  }
  let symbols = Array::make(lengths.length(), 0)
  for symbol, length in lengths {
    if length != 0 {
      symbols[offsets[length]] = symbol
      offsets[length] += 1
    }
  }
  { counts, symbols, }
}

///|
fn Huffman::new(lengths : ArrayView[Int32]) -> Huffman raise InflateError {
  let huffman = Huffman::from_lengths(lengths)
  let mut left = 1
  for len in 1..<16 {
    left = left * 2 - huffman.counts[len]
    if left < 0 {
      raise InvalidCodeLengths
    }
  }
  huffman
}

///|
fn Huffman::decode(
  self : Huffman,
  reader : BitReader,
) -> Int32 raise InflateError {
  let mut code = 0
  let mut first = 0
  let mut index = 0
  for len in 1..<16 {
    code = code | reader.bits(1)
    let count = self.counts[len]
    if code - count < first {
      return self.symbols[index + (code - first)]
    }
    index += count
    first += count
    first = first << 1
    code = code << 1
  }
  raise InvalidSymbol
}

///|
let length_base : Array[Int32] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
let length_extra : Array[Int32] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0,
]

///|
let distance_base : Array[Int32] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
let distance_extra : Array[Int32] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

///|
let code_length_order : Array[Int32] = [
  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
]

///|
fn fixed_tables() -> (Huffman, Huffman) {
  let lengths = Array::make(288, 8)
  for i in 144..<256 {
    lengths[i] = 9
  }
  for i in 256..<280 {
    lengths[i] = 7
  }
  let literals = Huffman::from_lengths(lengths[:])
  let distances = Huffman::from_lengths(Array::make(30, 5)[:])
  (literals, distances)
}

///|
fn push_checked(
  out : Array[Byte],
  byte : Byte,
  limit : Int32,
) -> Unit raise InflateError {
  if out.length() >= limit {
    raise OutputLimitExceeded
  }
  out.push(byte)
}

///|
fn inflate_codes(
  reader : BitReader,
  out : Array[Byte],
  literals : Huffman,
  distances : Huffman,
  limit : Int32,
) -> Unit raise InflateError {
  while true {
    let symbol = literals.decode(reader)
    if symbol < 256 {
      push_checked(out, symbol.to_byte(), limit)
    } else if symbol == 256 {
      break
    } else {
      let index = symbol - 257
      if index >= 29 {
        raise InvalidSymbol
      }
      let length = length_base[index] + reader.bits(length_extra[index])
      let distance_symbol = distances.decode(reader)
      let distance = distance_base[distance_symbol] +
        reader.bits(distance_extra[distance_symbol])
      if distance > out.length() {
        raise InvalidDistance
      }
      for _ in 0..<length {
        push_checked(out, out[out.length() - distance], limit)
      }
    }
  }
}

///|
fn inflate_stored(
  reader : BitReader,
  out : Array[Byte],
  limit : Int32,
) -> Unit raise InflateError {
  reader.align_to_byte()
  if reader.pos + 4 > reader.data.length() {
    raise UnexpectedEnd
  }
  let len = reader.data[reader.pos].to_int() |
    (reader.data[reader.pos + 1].to_int() << 8)
  let nlen = reader.data[reader.pos + 2].to_int() |
    (reader.data[reader.pos + 3].to_int() << 8)
  if len != (nlen ^ 0xFFFF) {
    raise InvalidStoredLength
  }
  reader.pos += 4
  if reader.pos + len > reader.data.length() {
    raise UnexpectedEnd
  }
  for i in 0..<len {
    push_checked(out, reader.data[reader.pos + i], limit)
  }
  reader.pos += len
}

///|
fn inflate_dynamic(
  reader : BitReader,
  out : Array[Byte],
  limit : Int32,
) -> Unit raise InflateError {
  let literal_count = reader.bits(5) + 257
  let distance_count = reader.bits(5) + 1
  let code_length_count = reader.bits(4) + 4
  if literal_count > 286 || distance_count > 30 {
    raise InvalidCodeLengths
  }
  let code_lengths = Array::make(19, 0)
  for i in 0..<code_length_count {
    code_lengths[code_length_order[i]] = reader.bits(3)
  }
  let code_length_table = Huffman::new(code_lengths[:])
  let lengths = Array::make(literal_count + distance_count, 0)
  let mut index = 0
  while index < literal_count + distance_count {
    let symbol = code_length_table.decode(reader)
    if symbol < 16 {
      lengths[index] = symbol
      index += 1
    } else {
      let (value, repeat) = match symbol {
        16 => {
          if index == 0 {
            raise InvalidCodeLengths
          }
          (lengths[index - 1], 3 + reader.bits(2))
        }
        17 => (0, 3 + reader.bits(3))
        _ => (0, 11 + reader.bits(7))
      }
      if index + repeat > literal_count + distance_count {
        raise InvalidCodeLengths
      }
      for _ in 0..<repeat {
        lengths[index] = value
        index += 1
      }
    }
  }
  if lengths[256] == 0 {
    raise InvalidCodeLengths
  }
  let literals = Huffman::new(lengths[0:literal_count])
  let distances = Huffman::new(lengths[literal_count:])
  inflate_codes(reader, out, literals, distances, limit)
}

///|
fn inflate_blocks(
  reader : BitReader,
  limit : Int32,
) -> Array[Byte] raise InflateError {
  let out : Array[Byte] = []
  while true {
    let last = reader.bits(1)
    match reader.bits(2) {
      0 => inflate_stored(reader, out, limit)
      1 => {
        let (literals, distances) = fixed_tables()
        inflate_codes(reader, out, literals, distances, limit)
      }
      2 => inflate_dynamic(reader, out, limit)
      _ => raise InvalidBlockType
    }
    if last == 1 {
      break
    }
  }
  out
}

///|
pub fn inflate(
  data : Bytes,
  max_output~ : Int32 = 1073741824,
) -> Bytes raise InflateError {
  Bytes::from_array(inflate_blocks(BitReader::new(data, 0), max_output))
}

///|
fn adler32(data : Bytes) -> UInt32 {
  let mut a = 1U
  let mut b = 0U
  for byte in data {
    a = (a + byte.to_uint()) % 65521U
    b = (b + a) % 65521U
  }
  (b << 16) | a
}

///|
pub fn zlib_decompress(
  data : Bytes,
  max_output~ : Int32 = 1073741824,
) -> Bytes raise InflateError {
  if data.length() < 6 {
    raise UnexpectedEnd
  }
  let cmf = data[0].to_int()
  let flg = data[1].to_int()
  if (cmf & 0x0F) != 8 || cmf >> 4 > 7 || (cmf * 256 + flg) % 31 != 0 {
    raise InvalidHeader
  }
  if (flg & 0x20) != 0 {
    raise UnsupportedDictionary
  }
  let reader = BitReader::new(data, 2)
  let out = Bytes::from_array(inflate_blocks(reader, max_output))
  let at = reader.pos
  if at + 4 > data.length() {
    raise UnexpectedEnd
  }
  let expected = (data[at].to_uint() << 24) |
    (data[at + 1].to_uint() << 16) |
    (data[at + 2].to_uint() << 8) |
    data[at + 3].to_uint()
  if adler32(out) != expected {
    raise ChecksumMismatch
  }
  out
}
