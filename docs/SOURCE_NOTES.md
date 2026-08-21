# Source and License Notes

- The animation engine, canvas utilities, palette quantization, LZW codec, compositor, and `image_bridge.mbt` are original MoonBit code authored for `WGYo90/moonbit-gif`.
- This module explicitly depends on `mizchi/image@0.4.3` from Mooncakes. The upstream repository is [`mizchi/image-mbt`](https://github.com/mizchi/image-mbt), whose `moon.mod` declares Apache-2.0.
- `mizchi/image` supplies the shared RGBA `ImageData` boundary and its image codec/resize capabilities; this repository adds multi-frame GIF timelines, disposal/composition, palette handling, GIF block parsing, and streaming LZW.
- No upstream source files are copied into this repository. The dependency is resolved by MoonBit tooling and remains outside the committed source tree.
- GIF89a block semantics and LZW behavior are implemented from the public format description; tests generate their image data in memory.
- The project and future contributions are distributed under Apache-2.0. See the root `LICENSE` and `NOTICE` files.
