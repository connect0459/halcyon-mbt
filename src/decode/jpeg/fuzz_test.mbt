///|
test "corrupted streams are rejected or decoded without panicking" {
  let decoder = @jpeg.JpegDecoder::new(
    limits=@decode.DecodeLimits::new(max_pixels=1_000_000),
  )
  let mut state = 12345U
  let mut accepted = 0
  let mut rejected = 0
  for fixture in jpeg_fixtures {
    let (_, data, _, _, _) = fixture
    for _ in 0..<150 {
      let mutated = Array::makei(data.length(), i => data[i])
      state = state * 1664525U + 1013904223U
      let flips = 1 + (state >> 28).reinterpret_as_int() % 4
      for _ in 0..<flips {
        state = state * 1664525U + 1013904223U
        let at = (state >> 8).reinterpret_as_int() % mutated.length()
        state = state * 1664525U + 1013904223U
        mutated[at] = (state >> 24).to_byte()
      }
      let _ = decoder.decode(Bytes::from_array(mutated)) catch {
        _ => {
          rejected += 1
          continue
        }
      }
      accepted += 1
    }
  }
  assert_true(accepted + rejected > 0)
}
