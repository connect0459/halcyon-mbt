# PNG test data

`pngsuite/` holds the PngSuite images by Willem van Schaik. The license is in `PngSuite.LICENSE`.

## Oracle

Expected pixels come from libpng, driven by `tools/png_reference.c`, configured to produce 8-bit RGBA (palette and `tRNS` expanded, 16-bit scaled, grayscale expanded to RGB). Images that libpng rejects are expected to be rejected by this decoder as well.

The expectations are embedded in `src/decode/png/pngsuite_fixtures_test.mbt` so that tests run on every backend without file access. That file is generated. The test suite never calls libpng.

## Regenerating

```sh
cc tools/png_reference.c $(pkg-config --cflags --libs libpng) -o /path/to/png_reference
python3 tools/gen_png_fixtures.py /path/to/png_reference
```

Fixtures were generated with libpng 1.6.59.
