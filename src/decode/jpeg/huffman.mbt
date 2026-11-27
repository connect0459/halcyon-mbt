///|
priv struct Huffman {
  min_code : Array[Int32]
  max_code : Array[Int32]
  value_pointer : Array[Int32]
  values : Array[Int32]
}

///|
fn Huffman::new(
  counts : Array[Int32],
  values : Array[Int32],
) -> Huffman raise @decode.DecodeError {
  let min_code = Array::make(17, 0)
  let max_code = Array::make(17, -1)
  let value_pointer = Array::make(17, 0)
  let mut code = 0
  let mut next = 0
  for length in 1..<=16 {
    let count = counts[length - 1]
    value_pointer[length] = next
    min_code[length] = code
    code += count
    next += count
    if code > 1 << length {
      raise @decode.DecodeError::Malformed("oversubscribed Huffman table")
    }
    if count > 0 {
      max_code[length] = code - 1
    }
    code = code << 1
  }
  { min_code, max_code, value_pointer, values, }
}

///|
fn Huffman::decode(
  self : Huffman,
  reader : BitReader,
) -> Int32 raise @decode.DecodeError {
  let mut code = 0
  for length in 1..<=16 {
    code = (code << 1) | reader.bit()
    if code <= self.max_code[length] {
      return self.values[self.value_pointer[length] +
        code -
        self.min_code[length]]
    }
  }
  raise @decode.DecodeError::Malformed("invalid Huffman code")
}
