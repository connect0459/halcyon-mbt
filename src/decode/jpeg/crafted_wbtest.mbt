///|
fn bytes_of(values : Array[Int32]) -> Bytes {
  Bytes::from_array(values.map(v => (v & 0xFF).to_byte()))
}

///|
fn cat(parts : Array[Bytes]) -> Bytes {
  let out : Array[Byte] = []
  for part in parts {
    for byte in part {
      out.push(byte)
    }
  }
  Bytes::from_array(out)
}

///|
fn segment(marker : Int32, body : Bytes) -> Bytes {
  let length = body.length() + 2
  cat([bytes_of([0xFF, marker, length >> 8, length]), body])
}

///|
let soi : Bytes = b"\xff\xd8"

///|
let eoi : Bytes = b"\xff\xd9"

///|
fn dqt_flat(slot : Int32, value : Int32) -> Bytes {
  segment(0xDB, cat([bytes_of([slot]), bytes_of(Array::make(64, value))]))
}

///|
fn dht(
  class : Int32,
  slot : Int32,
  counts : Array[Int32],
  values : Array[Int32],
) -> Bytes {
  segment(
    0xC4,
    cat([bytes_of([class * 16 + slot]), bytes_of(counts), bytes_of(values)]),
  )
}

///|
fn counts_of(first : Int32, second~ : Int32 = 0) -> Array[Int32] {
  let counts = Array::make(16, 0)
  counts[0] = first
  counts[1] = second
  counts
}

///|
let dc_zero : Bytes = dht(0, 0, counts_of(1), [0])

///|
let dc_pair : Bytes = dht(0, 0, counts_of(2), [0, 1])

///|
let ac_eob : Bytes = dht(1, 0, counts_of(1), [0])

///|
fn sof(
  marker : Int32,
  width : Int32,
  height : Int32,
  components : Array[(Int32, Int32, Int32)],
  precision~ : Int32 = 8,
) -> Bytes {
  let body = [
    precision,
    height >> 8,
    height,
    width >> 8,
    width,
    components.length(),
  ]
  for c in components {
    body.push(c.0)
    body.push(c.1)
    body.push(c.2)
  }
  segment(marker, bytes_of(body))
}

///|
fn sos(
  components : Array[(Int32, Int32)],
  ss~ : Int32 = 0,
  se~ : Int32 = 63,
  ah_al~ : Int32 = 0,
) -> Bytes {
  let body = [components.length()]
  for c in components {
    body.push(c.0)
    body.push(c.1)
  }
  body.push(ss)
  body.push(se)
  body.push(ah_al)
  segment(0xDA, bytes_of(body))
}

///|
fn gray_jpeg(entropy~ : Bytes = b"\x3f", before~ : Array[Bytes] = []) -> Bytes {
  cat(
    [
      soi,
      ..before,
      dqt_flat(0, 1),
      dc_zero,
      ac_eob,
      sof(0xC0, 8, 8, [(1, 0x11, 0)]),
      sos([(1, 0)]),
      entropy,
      eoi,
    ],
  )
}

///|
fn color_jpeg(ids : Array[Int32], before : Array[Bytes]) -> Bytes {
  cat(
    [
      soi,
      ..before,
      dqt_flat(0, 64),
      dc_pair,
      ac_eob,
      sof(0xC0, 8, 8, [(ids[0], 0x11, 0), (ids[1], 0x11, 0), (ids[2], 0x11, 0)]),
      sos([(ids[0], 0), (ids[1], 0), (ids[2], 0)]),
      b"\x34",
      eoi,
    ],
  )
}

///|
fn expect_error(data : Bytes, expected : @decode.DecodeError) -> Unit raise {
  try JpegDecoder::new().decode(data) catch {
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
fn pixel_of(data : Bytes) -> @image.Rgba raise {
  match JpegDecoder::new().decode(data).pixel(0, 0) {
    Some(p) => p
    None => fail("no pixel")
  }
}

///|
test "a flat gray image decodes to mid gray" {
  assert_eq(pixel_of(gray_jpeg()), @image.Rgba::new(128, 128, 128, 255))
}

///|
test "restart, comment and unknown segments are skipped" {
  let data = gray_jpeg(before=[
    segment(0xFE, b"hello"),
    b"\xff\x01",
    b"\xff\xd0",
    segment(0xE1, b"x"),
  ])
  assert_eq(pixel_of(data), @image.Rgba::new(128, 128, 128, 255))
}

///|
test "the format and the trait entry point are reported" {
  let decoder : &@decode.ImageDecoder = JpegDecoder::new()
  assert_eq(decoder.format(), @image.ImageFormat::Jpeg)
  assert_eq(decoder.decode(gray_jpeg()).width(), 8)
}

///|
test "data without a start-of-image marker is not recognised" {
  expect_error(b"", @decode.DecodeError::UnknownFormat)
  expect_error(b"\x89PNG", @decode.DecodeError::UnknownFormat)
}

///|
test "data that ends inside the marker stream is truncated" {
  expect_error(soi, @decode.DecodeError::Truncated)
  expect_error(cat([soi, b"\xff\xc0"]), @decode.DecodeError::Truncated)
  expect_error(cat([soi, b"\xff\xc0\x00\xff"]), @decode.DecodeError::Truncated)
}

///|
test "a stream with no frame header or no scan is rejected" {
  malformed(cat([soi, eoi]), "frame header is missing")
  malformed(
    cat([soi, dqt_flat(0, 1), sof(0xC0, 8, 8, [(1, 0x11, 0)]), eoi]),
    "image data is missing",
  )
}

///|
test "a scan before the frame header is rejected" {
  malformed(cat([soi, sos([(1, 0)]), b"\x3f", eoi]), "scan before frame header")
}

///|
test "a second frame header is rejected" {
  let frame = sof(0xC0, 8, 8, [(1, 0x11, 0)])
  malformed(cat([soi, frame, frame, eoi]), "duplicate frame header")
}

///|
test "processes other than Huffman sequential and progressive are unsupported" {
  expect_error(
    cat([soi, sof(0xC3, 8, 8, [(1, 0x11, 0)]), eoi]),
    @decode.DecodeError::Unsupported("JPEG process"),
  )
  expect_error(
    cat([soi, sof(0xC9, 8, 8, [(1, 0x11, 0)]), eoi]),
    @decode.DecodeError::Unsupported("JPEG process"),
  )
}

///|
test "a restart interval of the wrong length is rejected" {
  malformed(
    cat([soi, segment(0xDD, b"\x00\x01\x00"), eoi]),
    "invalid restart interval length",
  )
}

///|
test "frame headers are validated" {
  let component = [(1, 0x11, 0)]
  malformed(
    cat([soi, segment(0xC0, b"\x08\x00"), eoi]),
    "invalid frame header length",
  )
  expect_error(
    cat([soi, sof(0xC0, 8, 8, component, precision=12), eoi]),
    @decode.DecodeError::Unsupported("sample precision"),
  )
  malformed(cat([soi, sof(0xC0, 0, 8, component), eoi]), "invalid dimensions")
  malformed(cat([soi, sof(0xC0, 8, 0, component), eoi]), "invalid dimensions")
  expect_error(
    cat([soi, sof(0xC0, 8, 8, [(1, 0x11, 0), (2, 0x11, 0)]), eoi]),
    @decode.DecodeError::Unsupported("component count"),
  )
  malformed(
    cat([soi, segment(0xC0, b"\x08\x00\x08\x00\x08\x01\x01\x11"), eoi]),
    "invalid frame header length",
  )
  malformed(
    cat([soi, sof(0xC0, 8, 8, [(1, 0x01, 0)]), eoi]),
    "invalid sampling factor",
  )
  malformed(
    cat([soi, sof(0xC0, 8, 8, [(1, 0x50, 0)]), eoi]),
    "invalid sampling factor",
  )
  malformed(
    cat([soi, sof(0xC0, 8, 8, [(1, 0x11, 4)]), eoi]),
    "invalid quantization table index",
  )
  expect_error(
    cat([soi, sof(0xC0, 8, 8, [(1, 0x21, 0), (2, 0x31, 0), (3, 0x31, 0)]), eoi]),
    @decode.DecodeError::Unsupported("non-integral sampling ratio"),
  )
}

///|
test "an image beyond the pixel limit is rejected from its frame header" {
  let limited = JpegDecoder::new(
    limits=@decode.DecodeLimits::new(max_pixels=10),
  )
  try limited.decode(gray_jpeg()) catch {
    e => assert_eq(e, @decode.DecodeError::LimitExceeded(8, 8))
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "quantization tables are validated" {
  malformed(
    cat([soi, segment(0xDB, b"\x20"), eoi]),
    "invalid quantization table",
  )
  malformed(
    cat([soi, segment(0xDB, b"\x04"), eoi]),
    "invalid quantization table",
  )
  malformed(
    cat([soi, segment(0xDB, b"\x00\x01\x02"), eoi]),
    "invalid quantization table length",
  )
}

///|
test "Huffman tables are validated" {
  malformed(
    cat([soi, segment(0xC4, b"\x00\x01"), eoi]),
    "invalid Huffman table length",
  )
  malformed(
    cat([soi, segment(0xC4, cat([b"\x20", bytes_of(Array::make(16, 0))])), eoi]),
    "invalid Huffman table",
  )
  malformed(
    cat([soi, segment(0xC4, cat([b"\x04", bytes_of(Array::make(16, 0))])), eoi]),
    "invalid Huffman table",
  )
  malformed(
    cat([soi, dht(0, 0, counts_of(1), []), eoi]),
    "invalid Huffman table length",
  )
  malformed(
    cat([soi, dht(0, 0, counts_of(3), [0, 1, 2]), eoi]),
    "oversubscribed Huffman table",
  )
  let too_many = Array::make(16, 0)
  too_many[7] = 200
  too_many[8] = 100
  malformed(
    cat([soi, dht(0, 0, too_many, Array::make(300, 0)), eoi]),
    "invalid Huffman table length",
  )
}

///|
test "scan headers are validated" {
  let frame = sof(0xC0, 8, 8, [(1, 0x11, 0)])
  let tables = [dqt_flat(0, 1), dc_zero, ac_eob, frame]
  malformed(
    cat([soi, ..tables, segment(0xDA, b""), eoi]),
    "invalid scan header length",
  )
  malformed(
    cat([soi, ..tables, segment(0xDA, b"\x02\x01\x00\x00\x3f\x00"), eoi]),
    "invalid scan header",
  )
  malformed(
    cat([soi, ..tables, sos([(9, 0)]), eoi]),
    "scan refers to an unknown component",
  )
  malformed(
    cat([
      soi,
      dqt_flat(0, 1),
      dc_zero,
      ac_eob,
      sof(0xC0, 8, 8, [(1, 0x11, 0), (2, 0x11, 0), (3, 0x11, 0)]),
      sos([(1, 0), (1, 0)]),
      eoi,
    ]),
    "component repeated in scan",
  )
  malformed(
    cat([soi, dc_zero, ac_eob, frame, sos([(1, 0)]), eoi]),
    "missing quantization table",
  )
  malformed(
    cat([soi, dqt_flat(0, 1), dc_zero, ac_eob, frame, sos([(1, 0x40)]), eoi]),
    "invalid Huffman table selector",
  )
}

///|
test "a scan using an undefined Huffman table is rejected" {
  malformed(
    cat([
      soi,
      dqt_flat(0, 1),
      ac_eob,
      sof(0xC0, 8, 8, [(1, 0x11, 0)]),
      sos([(1, 0)]),
      b"\x00",
      eoi,
    ]),
    "missing DC Huffman table",
  )
  malformed(
    cat([
      soi,
      dqt_flat(0, 1),
      dc_zero,
      sof(0xC0, 8, 8, [(1, 0x11, 0)]),
      sos([(1, 0)]),
      b"\x00",
      eoi,
    ]),
    "missing AC Huffman table",
  )
}

///|
fn progressive_jpeg(
  scan : Bytes,
  entropy : Bytes,
  ac : Bytes,
  components~ : Array[(Int32, Int32, Int32)] = [(1, 0x11, 0)],
) -> Bytes {
  cat([
    soi,
    dqt_flat(0, 1),
    dc_zero,
    ac,
    sof(0xC2, 8, 8, components),
    scan,
    entropy,
    eoi,
  ])
}

///|
test "progressive spectral selection is validated" {
  malformed(
    progressive_jpeg(sos([(1, 0)], ss=5, se=2), b"\x00", ac_eob),
    "invalid spectral selection",
  )
  malformed(
    progressive_jpeg(sos([(1, 0)], ss=1, se=64), b"\x00", ac_eob),
    "invalid spectral selection",
  )
  malformed(
    progressive_jpeg(sos([(1, 0)], ss=0, se=5), b"\x00", ac_eob),
    "invalid spectral selection",
  )
  malformed(
    progressive_jpeg(sos([(1, 0)], ss=0, se=0, ah_al=14), b"\x00", ac_eob),
    "invalid spectral selection",
  )
  malformed(
    progressive_jpeg(sos([(1, 0), (2, 0)], ss=1, se=5), b"\x00", ac_eob, components=[
      (1, 0x11, 0),
      (2, 0x11, 0),
      (3, 0x11, 0),
    ]),
    "AC scan must hold one component",
  )
  malformed(
    progressive_jpeg(sos([(1, 0)], ss=1, se=5, ah_al=0x30), b"\x00", ac_eob),
    "invalid successive approximation",
  )
}

///|
test "the DC category of a coefficient is limited" {
  let wide = dht(0, 0, counts_of(1), [16])
  let data = cat([
    soi,
    dqt_flat(0, 1),
    wide,
    ac_eob,
    sof(0xC0, 8, 8, [(1, 0x11, 0)]),
    sos([(1, 0)]),
    b"\x00",
    eoi,
  ])
  malformed(data, "invalid DC category")
  let progressive = cat([
    soi,
    dqt_flat(0, 1),
    wide,
    sof(0xC2, 8, 8, [(1, 0x11, 0)]),
    sos([(1, 0)], ss=0, se=0),
    b"\x00",
    eoi,
  ])
  malformed(progressive, "invalid DC category")
}

///|
test "a run that leaves the block is rejected" {
  let long_run = dht(1, 0, counts_of(1), [0xF1])
  let sequential = cat([
    soi,
    dqt_flat(0, 1),
    dc_zero,
    long_run,
    sof(0xC0, 8, 8, [(1, 0x11, 0)]),
    sos([(1, 0)]),
    b"\x00\x55\x55",
    eoi,
  ])
  malformed(sequential, "coefficient index out of range")
  let first = progressive_jpeg(
    sos([(1, 0)], ss=1, se=63),
    b"\x55\x55\x55",
    long_run,
  )
  malformed(first, "coefficient index out of range")
  let refine = progressive_jpeg(
    sos([(1, 0)], ss=1, se=4, ah_al=0x10),
    b"\x40",
    long_run,
  )
  malformed(refine, "coefficient index out of range")
}

///|
test "a refinement symbol of any magnitude but one is rejected" {
  let bad = dht(1, 0, counts_of(1), [0x02])
  malformed(
    progressive_jpeg(sos([(1, 0)], ss=1, se=5, ah_al=0x10), b"\x00", bad),
    "invalid refinement magnitude",
  )
}

///|
test "entropy data that ends or hits a marker early is truncated" {
  expect_error(
    cat([
      soi,
      dqt_flat(0, 1),
      dc_zero,
      ac_eob,
      sof(0xC0, 8, 8, [(1, 0x11, 0)]),
      sos([(1, 0)]),
    ]),
    @decode.DecodeError::Truncated,
  )
  expect_error(gray_jpeg(entropy=b""), @decode.DecodeError::Truncated)
  expect_error(
    cat([
      soi,
      dqt_flat(0, 1),
      dc_zero,
      ac_eob,
      sof(0xC0, 8, 8, [(1, 0x11, 0)]),
      sos([(1, 0)]),
      b"\xff",
    ]),
    @decode.DecodeError::Truncated,
  )
}

///|
test "a missing or truncated restart marker is detected" {
  let two_blocks = (entropy : Bytes) => {
    cat([
      soi,
      dqt_flat(0, 1),
      dc_zero,
      ac_eob,
      segment(0xDD, b"\x00\x01"),
      sof(0xC0, 8, 16, [(1, 0x11, 0)]),
      sos([(1, 0)]),
      entropy,
    ])
  }
  malformed(two_blocks(b"\x3f\x3f\xff\xd9"), "missing restart marker")
  expect_error(two_blocks(b"\x3f"), @decode.DecodeError::Truncated)
}

///|
test "an unscanned component is reported" {
  malformed(
    cat([
      soi,
      dqt_flat(0, 1),
      dc_zero,
      ac_eob,
      sof(0xC0, 8, 8, [(1, 0x11, 0), (2, 0x11, 0), (3, 0x11, 0)]),
      sos([(1, 0)]),
      b"\x3f",
      eoi,
    ]),
    "component was never scanned",
  )
}

///|
test "an invalid Huffman code in entropy data is rejected" {
  malformed(
    gray_jpeg(entropy=b"\xff\x00\xff\x00\xff\x00"),
    "invalid Huffman code",
  )
}

///|
test "extreme coefficients saturate the samples" {
  let big_dc = dht(0, 0, counts_of(1), [11])
  let build = (bits : Bytes) => {
    cat([
      soi,
      dqt_flat(0, 1),
      big_dc,
      ac_eob,
      sof(0xC0, 8, 8, [(1, 0x11, 0)]),
      sos([(1, 0)]),
      bits,
      eoi,
    ])
  }
  assert_eq(pixel_of(build(b"\x7f\xf7")), @image.Rgba::new(255, 255, 255, 255))
}

///|
test "the color space follows the JFIF and Adobe markers and the component ids" {
  let jfif = segment(0xE0, b"JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00")
  let adobe = (transform : Int32) => {
    segment(0xEE, cat([b"Adobe", bytes_of([0, 100, 0, 0, 0, 0, transform])]))
  }
  let raw = @image.Rgba::new(128, 136, 120, 255)
  let converted = @image.Rgba::new(117, 131, 142, 255)
  assert_eq(pixel_of(color_jpeg([1, 2, 3], [])), converted)
  assert_eq(pixel_of(color_jpeg([82, 71, 66], [])), raw)
  assert_eq(pixel_of(color_jpeg([82, 71, 66], [jfif])), converted)
  assert_eq(pixel_of(color_jpeg([1, 2, 3], [adobe(0)])), raw)
  assert_eq(pixel_of(color_jpeg([82, 71, 66], [adobe(1)])), converted)
  expect_error(
    color_jpeg([1, 2, 3], [adobe(2)]),
    @decode.DecodeError::Unsupported("Adobe color transform"),
  )
}
