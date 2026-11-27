# connect0459/halcyon/decode/png

A PNG decoder written in MoonBit with no codec dependency. The output is always 8-bit RGBA.

## Supported

- All color types and bit depths defined by the specification (1, 2, 4, 8 and 16 bits)
- Adam7 interlacing
- Palette, `tRNS` transparency for every color type
- Multiple `IDAT` chunks, chunk checksum verification

## Conversion rules

- Samples below 8 bits are scaled to the full 0-255 range.
- 16-bit samples are scaled with `(v * 255 + 32895) >> 16`, the same rounding as libpng.
- Gamma, color profiles, and other ancillary chunks are ignored.

## Usage

`PngDecoder::new(limits?)` creates a decoder. `PngDecoder::decode(bytes)` returns a `PixelBuffer` or raises `DecodeError`.

## Verification

The test suite decodes every image of PngSuite and compares the result with libpng. See `testdata/png/README.md`.
