# moonbit-gif

基于 `mizchi/image` 的 MoonBit GIF89a 动态图像合成与 LZW 扩展层。

项目面向“把一组 `mizchi/image.ImageData` 稳定地变成可播放 GIF”这一具体工作流，在上游 RGBA 图像表示之上增加帧时间线、透明色、局部/全局调色板、Median Cut 量化、位级 LZW、差分帧分析和 GIF 解析。本项目不复制上游源码，也不试图替代通用静态图像库。

## 为什么做这个项目

`mizchi/image` 已经提供 `ImageData`、PNG/BMP/JPEG 编解码、缩放和单帧 GIF 编码。本项目明确沿着它的 RGBA 数据边界扩展动态 GIF 生产链：帧合成、disposal 语义、帧间延迟、调色板量化和 GIF 子块/LZW 的完整闭环。这样上游负责“得到图像”，本项目负责“组织并播放图像序列”，可服务录屏转 GIF、网页表情包合成和像素画动画导出等工具。

## 上游依赖与扩展边界

仓库通过 Mooncakes 依赖 `mizchi/image@0.4.3`，上游源码和 Apache-2.0 许可见 [`mizchi/image-mbt`](https://github.com/mizchi/image-mbt)，包文档见 [`mizchi/image`](https://mooncakes.io/docs/mizchi/image)。本项目新增 `image_bridge.mbt`，提供 `ImageData` 与 `Canvas`、`Frame`、`Animation` 之间的转换，以及多帧编码和首帧解码 API；动态 GIF 的时间线、局部帧矩形、disposal、量化和 LZW 仍由本仓库实现。

## 已实现

- GIF87a/GIF89a 读取，逻辑屏幕、全局/局部调色板、图形控制扩展、循环扩展和多帧图像数据解析。
- GIF89a 编码，自动选择全局与局部调色板，支持透明色、帧延迟、disposal 和循环次数。
- Median Cut 调色板量化；可选有序抖动与 Floyd–Steinberg 抖动。
- 动态 LZW 编码/解码，12 位码表、清除码、结束码、KwKwK 情形和 GIF data sub-block 打包。
- RGBA 画布绘制、alpha 合成、裁剪、缩放、旋转、透明边界裁剪、contain/cover 预览和缩略采样。
- 动画拼接、反向、交叉淡化、延迟重排、差分矩形、差分补丁、关键帧分析和结构检查。
- `cmd/main` 中的最小可运行示例，以及覆盖编码、解码、LZW、量化、时间线和画布工具的测试。

## 快速开始

模块命名空间和仓库地址均对应本项目 GitHub 账号 `WGYo90`。

```bash
moon add mizchi/image@0.4.3
moon add WGYo90/moonbit-gif@0.1.0
```

```moonbit
import {
  "mizchi/image" @image,
  "WGYo90/moonbit-gif" @gif,
}

let frame = @image.ImageData::{
  width: 32,
  height: 32,
  data: Bytes::make(32 * 32 * 4, 255),
}
let bytes = @gif.encode_image_sequence([frame], delay_cs=8, loop_count=0)
```

需要精细绘制时，也可以继续使用 `@gif.Canvas` 构造 `Frame` 和 `Animation`；`Canvas::to_image_data` 可将结果交回 `mizchi/image` 的 RGBA 表示。

运行仓库示例：

```bash
moon run --target native cmd/main
```

## 开发与检查

```bash
moon fmt --check
moon check --target all --deny-warn --fmt
moon info --target all
moon test --target all --deny-warn
moon build --target all --deny-warn
```

Windows 开发者也可以直接运行 `pwsh ./scripts/check.ps1` 执行同一套检查、测试、构建和 CLI 示例。

CI 在 Ubuntu、macOS 和 Windows 上安装 MoonBit 后执行同一组检查。`moon fmt` 与 `moon info` 本身没有 `--deny-warn` 选项，因此格式严格性由 `moon fmt --check`/`moon check --fmt --deny-warn` 保证，信息文件通过 `git diff --exit-code` 保证没有未生成变更。

## 目录结构

| 路径 | 内容 |
| --- | --- |
| `gif_types.mbt` | RGBA、Canvas、Frame、Animation 和错误类型 |
| `palette.mbt` / `palette_tools.mbt` | Median Cut、调色板和抖动量化 |
| `lzw.mbt` / `gif_stream.mbt` | 位级 LZW 与 GIF 子块流 |
| `gif_encoder.mbt` / `gif_decoder.mbt` | GIF89a 编解码 |
| `compose.mbt` / `gif_delta.mbt` / `gif_patch.mbt` | disposal 合成和帧差分 |
| `canvas_*.mbt` / `animation_*.mbt` | 画布工具和动画时间线工具 |
| `image_bridge.mbt` | `mizchi/image.ImageData` 适配与多帧 API |
| `cmd/main` | 可运行示例 |
| `docs/PROJECT_PROPOSAL.md` | 黑客松项目说明初稿 |

## 边界与后续计划

当前编码器以 GIF89a 为输出目标，解码器暂不展开隔行扫描图像，也不负责文件系统或屏幕捕获。上层工具可以把采集到的 RGBA 帧交给本库；后续可增加流式输入适配器、隔行扫描、CLI 参数层以及浏览器/WASM 示例。

## 来源与许可证

本仓库的动态 GIF、画布、量化、LZW、合成和适配代码为本项目原创 MoonBit 实现；GIF 的公开格式语义和 LZW 算法按公开规范自行实现。`mizchi/image@0.4.3` 作为 Apache-2.0 上游依赖使用，不复制其源码；项目整体使用 Apache-2.0，详见 [`LICENSE`](LICENSE)、[`NOTICE`](NOTICE) 和 [`SOURCE_NOTES.md`](docs/SOURCE_NOTES.md)。
