# connect0459/halcyon/image

Value objects shared by every other halcyon package. This package has no dependencies.

| Item | Purpose |
| :--- | :--- |
| `PixelBuffer` | Immutable-by-convention RGBA8 bitmap in row-major order. `PixelBuffer::new(width, height, data)` validates dimensions and data length. |
| `Rgba` | One pixel read with `PixelBuffer::pixel(x, y)`, which returns `None` outside the bitmap. |
| `ImageFormat` | `Png` or `Jpeg`. |
| `ImageKey` | Cache identity made of a source and a processor identifier. |
| `ImageError` | `InvalidDimensions`, `DataLengthMismatch`, `RegionOutOfBounds`. |
