# Architecture

## Upstream integration

`moonbit-gif` depends on `mizchi/image@0.4.3` for the shared `ImageData` RGBA representation and upstream image codec boundary. `image_bridge.mbt` converts that type to the local `Canvas`, `Frame`, and `Animation` types, so PNG/BMP/JPEG or resized images can enter the animation pipeline without duplicating the upstream implementation. The GIF timeline, composition, palette quantization, and LZW layers remain local to this repository.

## Data flow

`Canvas` stores row-major RGBA pixels. `Frame` adds delay, disposal, transparency, and logical-screen offset. `Animation` owns the logical screen, background, loop policy, and ordered frames.

```text
RGBA Canvas -> frame timeline -> palette quantizer -> indexed pixels -> LZW bitstream -> GIF blocks
     ^              |                 |                    |                |
     |              +-- compose <-----+                    +-- inspect <-----+
     +---------------- decode <--------- GIF89a parser <----------------------
```

## Encoding path

The encoder quantizes each frame independently. The first palette is written as the logical-screen global table; later frames receive local tables so their colors do not depend on earlier frames. Graphic Control Extensions carry delay, disposal, and transparency metadata. Image data is encoded with a dynamic 9–12 bit LZW code width and split into GIF sub-blocks.

## Decoding path

The parser validates the signature and logical screen, reads global or local tables, decodes LZW indices, and keeps each image descriptor's local width, height, and offset. `compose` then applies transparency and disposal semantics to produce full-screen snapshots without mutating later frames.

## Extension points

`gif_delta.mbt` and `gif_patch.mbt` provide frame-difference primitives for recording tools and low-bandwidth transfer. `canvas_sampling.mbt` supplies thumbnails and previews. Future adapters can feed RGBA frames from screen capture or a browser without changing the GIF core.
