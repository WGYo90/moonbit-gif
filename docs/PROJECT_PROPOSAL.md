# MoonBit 黑客松项目申报书
## 一、项目基本信息
- 项目名称：MoonBit 动态 GIF 图像合成与 LZW 压缩编码引擎
- 项目标识：moonbit-gif
- 项目仓库：[WGYo90/moonbit-gif](https://github.com/WGYo90/moonbit-gif)
- 项目定位：基于 `mizchi/image` 的动态 GIF 扩展层
## 二、项目与生态关系
`mizchi/image@0.4.3` 已提供 RGBA `ImageData`、PNG/BMP/JPEG 编解码、缩放和单帧 GIF 编码；上游源码为 [mizchi/image-mbt](https://github.com/mizchi/image-mbt)，采用 Apache-2.0。
本项目通过 Mooncakes 依赖直接复用上游数据表示，在其边界上新增 `ImageData` 与动画引擎的适配 API，不复制上游源码，形成清晰的扩展关系。
## 三、项目简介
`moonbit-gif` 面向“把一组图像稳定地变成可播放 GIF”的工作流，补足多帧时间线、局部帧矩形、透明度、disposal、调色板量化和 LZW 编解码。
## 四、核心功能与应用价值
- 支持 GIF87a/GIF89a 读取，解析逻辑屏幕、全局/局部调色板、图形控制扩展、循环扩展和多帧图像。
- 支持 GIF89a 编码，提供全局/局部调色板、Median Cut、有序/Floyd–Steinberg 抖动、透明色、帧延迟和循环次数。
- 实现位级动态码宽 LZW、12 位码表、清除码、结束码、KwKwK 情形与 GIF data sub-block。
- 提供画布合成、差分帧、关键帧分析和 `ImageData` 多帧桥接，可支撑录屏转 GIF、网页表情包和像素动画导出。
## 五、实施范围与技术路线
以 `mizchi/image.ImageData` 作为输入输出边界，以 RGBA `Canvas` 和 `Animation` 作为中间表示；编码时量化为索引色并写入 GIF 块，解码时恢复帧矩形并依据 disposal 合成。
比赛阶段交付稳定的桥接 API、动态编解码、核心边界测试、CLI 示例、README、来源说明和跨平台 CI；后续可扩展录屏、WASM、流式输入和网页导出。
## 六、实施计划
- 第一阶段维护 `ImageData` 桥接、动态编解码、LZW、调色板和 disposal 合成，补齐核心边界测试。
- 第二阶段完善 CLI 示例、差分帧分析、跨平台 CI、严格格式检查和 Mooncakes 发布材料。
- 第三阶段扩展录屏输入、WASM/网页端导出、流式编码和性能基准，保持上游接口边界稳定。
## 七、验收与开源说明
公开仓库应能通过 `moon fmt --check`、`moon check --target all --deny-warn --fmt`、`moon info --target all`、跨目标测试和构建；有效实现规模以仓库实际统计为准，不虚报。
动态 GIF、合成、量化、LZW 和桥接代码为本项目原创 MoonBit 实现；上游依赖及其许可证在 `NOTICE`、`docs/SOURCE_NOTES.md` 和 `moon.mod` 中完整记录，项目整体采用 Apache-2.0。
## 八、可扩展性与边界
本项目专注动态图像序列，不重复建设上游静态图像编解码；采集、界面和文件系统能力由未来 CLI、WASM 或网页适配器提供。
## 九、版本交付
比赛提交包含公开源码、示例、测试、CI、README、架构文档、来源说明、许可证与可复现的检查命令。
