///|
fn concat(parts : Array[Bytes]) -> Bytes {
  let out : Array[Byte] = []
  for part in parts {
    for byte in part {
      out.push(byte)
    }
  }
  Bytes::from_array(out)
}

///|
fn u32_bytes(value : Int32) -> Bytes {
  Bytes::from_array([
    (value >> 24).to_byte(),
    (value >> 16).to_byte(),
    (value >> 8).to_byte(),
    value.to_byte(),
  ])
}

///|
fn text_bytes(text : String) -> Bytes {
  Bytes::from_array(text.to_array().map(c => c.to_int().to_byte()))
}

///|
fn chunk(name : String, body : Bytes) -> Bytes {
  let typed = concat([text_bytes(name), body])
  concat([
    u32_bytes(body.length()),
    typed,
    u32_bytes(crc32(typed, 0, typed.length()).reinterpret_as_int()),
  ])
}

///|
fn ihdr_with(
  width : Int32,
  height : Int32,
  depth : Int32,
  color_type : Int32,
  compression~ : Int32 = 0,
  filter~ : Int32 = 0,
  interlace~ : Int32 = 0,
) -> Bytes {
  chunk(
    "IHDR",
    concat([
      u32_bytes(width),
      u32_bytes(height),
      Bytes::from_array([
        depth.to_byte(),
        color_type.to_byte(),
        compression.to_byte(),
        filter.to_byte(),
        interlace.to_byte(),
      ]),
    ]),
  )
}

///|
fn adler(data : Bytes) -> Int32 {
  let mut a = 1
  let mut b = 0
  for byte in data {
    a = (a + byte.to_int()) % 65521
    b = (b + a) % 65521
  }
  (b << 16) | a
}

///|
fn idat_of(raw : Bytes) -> Bytes {
  chunk(
    "IDAT",
    concat([
      b"\x78\x01\x01",
      Bytes::from_array([
        raw.length().to_byte(),
        (raw.length() >> 8).to_byte(),
        (raw.length() ^ 0xFFFF).to_byte(),
        ((raw.length() ^ 0xFFFF) >> 8).to_byte(),
      ]),
      raw,
      u32_bytes(adler(raw)),
    ]),
  )
}

///|
let signature : Bytes = b"\x89PNG\r\n\x1a\n"

///|
let iend : Bytes = chunk("IEND", b"")

///|
fn png_of(chunks : Array[Bytes]) -> Bytes {
  concat([signature, concat(chunks), iend])
}

///|
fn gray_pixel_png(extra : Array[Bytes]) -> Bytes {
  png_of([ihdr_with(1, 1, 8, 0), ..extra, idat_of(b"\x00\x80")])
}

///|
fn expect_error(data : Bytes, expected : @decode.DecodeError) -> Unit raise {
  try PngDecoder::new().decode(data) catch {
    e => assert_eq(e, expected)
  } noraise {
    _ => fail("expected an error")
  }
}

///|
fn malformed(data : Bytes, message : String) -> Unit raise {
  expect_error(data, @decode.DecodeError::Malformed(message))
}

///|
test "a minimal grayscale image decodes" {
  let buffer = PngDecoder::new().decode(gray_pixel_png([]))
  assert_eq(buffer.pixel(0, 0), Some(@image.Rgba::new(128, 128, 128, 255)))
}

///|
test "a header chunk of the wrong length is rejected" {
  malformed(
    png_of([chunk("IHDR", b"\x00\x00\x00\x01\x00\x00\x00\x01\x08\x00\x00\x00")]),
    "invalid header length",
  )
}

///|
test "unsupported compression, filter and interlace methods are reported" {
  expect_error(
    png_of([ihdr_with(1, 1, 8, 0, compression=1)]),
    @decode.DecodeError::Unsupported("compression method"),
  )
  expect_error(
    png_of([ihdr_with(1, 1, 8, 0, filter=1)]),
    @decode.DecodeError::Unsupported("filter method"),
  )
  expect_error(
    png_of([ihdr_with(1, 1, 8, 0, interlace=2)]),
    @decode.DecodeError::Unsupported("interlace method"),
  )
}

///|
test "an unknown color type or an invalid bit depth is rejected" {
  malformed(png_of([ihdr_with(1, 1, 8, 5)]), "invalid color type")
  malformed(png_of([ihdr_with(1, 1, 4, 2)]), "invalid bit depth for color type")
}

///|
test "zero width or height is rejected" {
  malformed(png_of([ihdr_with(0, 1, 8, 0)]), "invalid dimensions")
  malformed(png_of([ihdr_with(1, 0, 8, 0)]), "invalid dimensions")
}

///|
test "a stream must begin with the header chunk" {
  malformed(
    png_of([idat_of(b"\x00\x80"), ihdr_with(1, 1, 8, 0)]),
    "header chunk is missing",
  )
}

///|
test "a second header chunk is rejected" {
  malformed(
    png_of([ihdr_with(1, 1, 8, 0), ihdr_with(1, 1, 8, 0)]),
    "duplicate header",
  )
}

///|
test "palette rules are enforced" {
  let rgb = b"\x01\x02\x03"
  malformed(gray_pixel_png([chunk("PLTE", rgb)]), "palette not allowed")
  malformed(
    png_of([ihdr_with(1, 1, 8, 3), chunk("PLTE", b"\x01\x02")]),
    "invalid palette length",
  )
  malformed(
    png_of([ihdr_with(1, 1, 8, 3), chunk("PLTE", b"")]),
    "invalid palette length",
  )
  malformed(
    png_of([
      ihdr_with(1, 1, 1, 3),
      chunk("PLTE", b"\x01\x02\x03\x04\x05\x06\x07\x08\x09"),
    ]),
    "palette larger than bit depth",
  )
  malformed(
    png_of([ihdr_with(1, 1, 8, 3), chunk("PLTE", rgb), chunk("PLTE", rgb)]),
    "misplaced palette",
  )
  malformed(
    png_of([
      ihdr_with(1, 1, 8, 2),
      idat_of(b"\x00\x00\x00\x00"),
      chunk("PLTE", rgb),
    ]),
    "misplaced palette",
  )
  malformed(
    png_of([ihdr_with(1, 1, 8, 3), idat_of(b"\x00\x00")]),
    "palette is missing",
  )
}

///|
test "a palette image pointing outside its palette is rejected" {
  malformed(
    png_of([
      ihdr_with(1, 1, 8, 3),
      chunk("PLTE", b"\x01\x02\x03"),
      idat_of(b"\x00\x05"),
    ]),
    "palette index out of range",
  )
}

///|
test "palette transparency applies to the listed entries only" {
  let data = png_of([
    ihdr_with(2, 1, 8, 3),
    chunk("PLTE", b"\x01\x02\x03\x04\x05\x06"),
    chunk("tRNS", b"\x07"),
    idat_of(b"\x00\x00\x01"),
  ])
  let buffer = PngDecoder::new().decode(data)
  assert_eq(buffer.pixel(0, 0), Some(@image.Rgba::new(1, 2, 3, 7)))
  assert_eq(buffer.pixel(1, 0), Some(@image.Rgba::new(4, 5, 6, 255)))
}

///|
test "palette transparency longer than the palette is truncated" {
  let data = png_of([
    ihdr_with(1, 1, 8, 3),
    chunk("PLTE", b"\x01\x02\x03"),
    chunk("tRNS", b"\x07\x08\x09"),
    idat_of(b"\x00\x00"),
  ])
  assert_eq(
    PngDecoder::new().decode(data).pixel(0, 0),
    Some(@image.Rgba::new(1, 2, 3, 7)),
  )
}

///|
test "a transparency chunk that does not fit the color type is ignored" {
  let too_short = gray_pixel_png([chunk("tRNS", b"\x00")])
  assert_eq(
    PngDecoder::new().decode(too_short).pixel(0, 0),
    Some(@image.Rgba::new(128, 128, 128, 255)),
  )
  let with_alpha = png_of([
    ihdr_with(1, 1, 8, 4),
    chunk("tRNS", b"\x00\x80"),
    idat_of(b"\x00\x80\x40"),
  ])
  assert_eq(
    PngDecoder::new().decode(with_alpha).pixel(0, 0),
    Some(@image.Rgba::new(128, 128, 128, 64)),
  )
}

///|
test "image data split by another chunk is rejected" {
  malformed(
    png_of([
      ihdr_with(1, 1, 8, 0),
      idat_of(b"\x00"),
      chunk("tEXt", b"a\x00b"),
      idat_of(b"\x80"),
    ]),
    "image data is not contiguous",
  )
}

///|
test "an unknown critical chunk is unsupported but an unknown ancillary chunk is skipped" {
  expect_error(
    gray_pixel_png([chunk("FOOO", b"")]),
    @decode.DecodeError::Unsupported("critical chunk FOOO"),
  )
  let buffer = PngDecoder::new().decode(gray_pixel_png([chunk("fooo", b"x")]))
  assert_eq(buffer.width(), 1)
}

///|
test "image data missing from the stream is rejected" {
  malformed(png_of([ihdr_with(1, 1, 8, 0)]), "image data is missing")
}

///|
test "a stream without an end chunk is truncated" {
  let data = concat([signature, ihdr_with(1, 1, 8, 0), idat_of(b"\x00\x80")])
  expect_error(data, @decode.DecodeError::Truncated)
}

///|
test "a corrupted chunk checksum is rejected" {
  let data = gray_pixel_png([])
  let broken = Bytes::from_array(Array::makei(data.length(), i => data[i]))
  let at = 8 + 8 + 13
  let flipped = Bytes::from_array(
    Array::makei(broken.length(), i => {
      if i == at {
        broken[i] ^ b'\xff'
      } else {
        broken[i]
      }
    }),
  )
  malformed(flipped, "chunk checksum mismatch in IHDR")
}

///|
test "more image data than the dimensions call for is rejected" {
  malformed(
    png_of([ihdr_with(1, 1, 8, 0), idat_of(b"\x00\x80\x00\x00")]),
    "excess image data",
  )
}

///|
test "less image data than the dimensions call for is truncated" {
  expect_error(
    png_of([ihdr_with(1, 2, 8, 0), idat_of(b"\x00\x80")]),
    @decode.DecodeError::Truncated,
  )
}

///|
test "a corrupt compressed stream is rejected" {
  let bad = chunk("IDAT", b"\x79\x01\x01\x00\x00\xff\xff\x00\x00\x00\x01")
  malformed(png_of([ihdr_with(1, 1, 8, 0), bad]), "invalid compressed data")
}

///|
test "an unknown scanline filter is rejected" {
  malformed(
    png_of([ihdr_with(1, 1, 8, 0), idat_of(b"\x05\x80")]),
    "invalid filter type",
  )
}

///|
test "all filters reconstruct the original rows" {
  let rows = b"\x01\x0a\x14\x02\x01\x01\x03\x01\x01\x04\x01\x01"
  let data = png_of([ihdr_with(2, 4, 8, 0), idat_of(rows)])
  let buffer = PngDecoder::new().decode(data)
  assert_eq(buffer.pixel(1, 0), Some(@image.Rgba::new(30, 30, 30, 255)))
}

///|
test "a compressed stream that ends early is truncated" {
  let cut = chunk("IDAT", b"\x78\x01\x01\x02\x00")
  expect_error(
    png_of([ihdr_with(1, 1, 8, 0), cut]),
    @decode.DecodeError::Truncated,
  )
}
