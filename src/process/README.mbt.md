# connect0459/halcyon/process

Pure transformations from one `PixelBuffer` to another.

| Item | Purpose |
| :--- | :--- |
| `ImageProcessor` | Trait with `identifier()` and `process(buffer)`. The identifier is part of the cache key. |
| `Resize` | Nearest-neighbour resize to a fixed size. |
| `Crop` | Extracts a rectangular region; raises when the region leaves the image. |
| `Compose` | Applies processors in order; its identifier joins the parts with `\|`. |
| `key_for(source, processor)` | Builds the `ImageKey` for a processed image. |
