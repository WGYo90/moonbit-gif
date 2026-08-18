# moonbit-gif

MoonBit 原生实现的 GIF89a 动态图像合成与 LZW 编码引擎。

项目面向“把一组 RGBA 帧稳定地变成可播放 GIF”这一具体工作流，提供帧时间线、透明色、局部/全局调色板、Median Cut 量化、位级 LZW、差分帧分析和 GIF 解析。它不是通用图片格式大而全的替代品。

## 为什么做这个项目

MoonBit 生态已经有覆盖多种静态图像格式的图像库。本项目把边界放在动态 GIF 生产链上：动态帧合成、disposal 语义、帧间延迟、调色板量化和 GIF 子块/LZW 的完整闭环。这样既能复用 RGBA 画布，也能服务录屏转 GIF、网页表情包合成、像素画动画导出等上层工具。

## 已实现

- GIF87a/GIF89a 读取，逻辑屏幕、全局/局部调色板、图形控制扩展、循环扩展和多帧图像数据解析。
- GIF89a 编码，自动选择全局与局部调色板，支持透明色、帧延迟、disposal 和循环次数。
- Median Cut 调色板量化；可选有序抖动与 Floyd–Steinberg 抖动。
- 动态 LZW 编码/解码，12 位码表、清除码、结束码、KwKwK 情形和 GIF data sub-block 打包。
- RGBA 画布绘制、alpha 合成、裁剪、缩放、旋转、透明边界裁剪、contain/cover 预览和缩略采样。
- 动画拼接、反向、交叉淡化、延迟重排、差分矩形、差分补丁、关键帧分析和结构检查。
- `cmd/main` 中的最小可运行示例，以及覆盖编码、解码、LZW、量化、时间线和画布工具的测试。

## 快速开始

当前模块名使用了作者目录名 `weiguangyang` 作为本地占位。提交到 GitHub 前，请把 `moon.mod` 中的模块名和仓库地址替换为实际 GitHub 用户名/仓库。

```bash
moon add weiguangyang/moonbit-gif@0.1.0
```

```moonbit
import {
  "weiguangyang/moonbit-gif" @gif,
}

let canvas = @gif.Canvas::new(
  width=32,
  height=32,
  fill=@gif.rgba(0, 0, 0, 0),
)
ignore(canvas.fill_rect(x=4, y=4, width=24, height=24, color=@gif.rgb(40, 180, 255)))

let animation = @gif.Animation::new(width=32, height=32)
  .add_frame(@gif.Frame::new(canvas=canvas, delay_cs=8))
let bytes = @gif.encode(animation)
```

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
| `cmd/main` | 可运行示例 |
| `docs/PROJECT_PROPOSAL.md` | 黑客松项目说明初稿 |

## 边界与后续计划

当前编码器以 GIF89a 为输出目标，解码器暂不展开隔行扫描图像，也不负责文件系统或屏幕捕获。上层工具可以把采集到的 RGBA 帧交给本库；后续可增加流式输入适配器、隔行扫描、CLI 参数层以及浏览器/WASM 示例。

## 来源与许可证

本仓库为原创 MoonBit 实现，没有复制第三方源码、图片或闭源实现。GIF 的公开格式语义和 LZW 算法按公开标准自行实现；生态对比仅用于明确边界，不构成本项目依赖。项目使用 Apache-2.0，详见 [`LICENSE`](LICENSE)。

AI 工具曾用于局部脚手架建议和调试辅助；接口设计、实现取舍、测试、格式检查和许可证边界由项目作者复核并负责。本仓库未引入未经授权的生成内容。

