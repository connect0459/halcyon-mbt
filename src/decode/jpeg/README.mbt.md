# connect0459/halcyon/decode/jpeg

A JPEG decoder written in MoonBit with no codec dependency. The output is always 8-bit RGBA with an opaque alpha channel.

## Supported

- Baseline and extended sequential Huffman JPEG, 8-bit samples
- Progressive JPEG: spectral selection and successive approximation
- Grayscale and three-component images (YCbCr or RGB)
- Any integral sampling ratio; 4:4:4, 4:2:2, 4:4:0 and 4:2:0 use fancy upsampling
- 8-bit and 16-bit quantization tables, restart intervals, optimized Huffman tables

## Not supported

Reported as `DecodeError::Unsupported`: arithmetic coding, lossless and hierarchical processes, 12-bit samples, two- and four-component images (including CMYK and YCCK), and non-integral sampling ratios.

## Exactness

Decoding is arithmetically identical to libjpeg-turbo configured with the accurate integer DCT and fancy upsampling: every test image decodes to exactly the same pixels, with a maximum per-channel difference of zero.

## Usage

`JpegDecoder::new(limits?)` creates a decoder. `JpegDecoder::decode(bytes)` returns a `PixelBuffer` or raises `DecodeError`. Pixel limits are checked from the frame header, before coefficient memory is allocated.
