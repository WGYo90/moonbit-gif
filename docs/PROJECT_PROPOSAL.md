# moonbit-gif 项目说明

## 项目定位

`moonbit-gif` 是纯 MoonBit 的 GIF89a 动态图像合成与 LZW 压缩编码引擎，服务录屏转 GIF、网页表情包合成和画板动画导出。

## 现有基础

仓库已经具备 RGBA 画布、动画帧模型、disposal 合成、GIF 解析与生成、Median Cut 调色板量化、抖动、位级 LZW、差分帧分析、CLI 示例和自动化测试。实现不依赖外部图片库。

## 本次黑客松工作

1. 稳定 GIF89a 多帧编解码和透明帧行为。
2. 完善局部调色板、量化和 LZW 子块的边界测试。
3. 提供差分帧/补丁与画布采样接口，降低上层动画工具的接入成本。
4. 补齐跨平台 CI、严格格式/接口生成检查、README、许可证和可运行示例。

## 技术路线

以 RGBA Canvas 作为统一中间表示；编码前使用 Median Cut 生成索引色调色板，再以动态码宽 LZW 写入 GIF data sub-block。解码时先恢复索引帧和透明语义，再由合成器按 disposal 与帧延迟重建播放画面。帧差分接口为录屏和低带宽传输保留扩展边界。

## 预期验收

仓库可由 `moon test --target all --deny-warn`、`moon fmt --check`、`moon info --target all` 和 `moon build --target all --deny-warn` 检查；示例能够生成并再次解析 GIF 字节，测试覆盖 LZW 动态码宽、透明色、多帧延迟、调色板、差分和画布操作。

## 原创与边界

本项目为原创 MoonBit 实现，不是对已有图像库的搬运。生态中已有的通用图像库覆盖更广格式；本项目专注动态 GIF 的帧时间线、disposal、调色板量化和 LZW 闭环。当前不承诺隔行扫描和屏幕采集，后续通过独立适配器扩展。

