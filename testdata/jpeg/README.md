# JPEG test data

The images are produced by `cjpeg` from deterministic synthetic sources (see `tools/gen_jpeg_fixtures.py`) and cover baseline and progressive coding, every common sampling ratio, grayscale, RGB, restart intervals, optimized tables, extreme quality settings, and 16-bit quantization tables.

## Oracle

Expected pixels come from libjpeg-turbo, driven by `tools/jpeg_reference.c`: accurate integer DCT (`islow`), fancy upsampling, no block smoothing, output as 8-bit RGBA. Expectations are exact: the maximum allowed per-channel difference is zero.

They are embedded in `src/decode/jpeg/jpeg_fixtures_test.mbt`, which is generated. The test suite never calls libjpeg.

## Regenerating

```sh
cc tools/jpeg_reference.c $(pkg-config --cflags --libs libjpeg) -o /path/to/jpeg_reference
python3 tools/gen_jpeg_fixtures.py /path/to/jpeg_reference [/path/to/cjpeg]
```

Fixtures were generated with libjpeg-turbo 3.2.1.
