# Agent Meter

一个低资源、原生 macOS 菜单栏用量仪表盘，面向 Codex 和 Kimi Code。

点击右上角图标后，App 会打开固定尺寸的用量弹窗并刷新账号级数据；平时只保留轻量的菜单栏进程和文件事件监听。

## 当前能力

- macOS 原生 SwiftUI `MenuBarExtra`，最低 macOS 13 Ventura。
- App 图标源文件位于 `assets/image.png`；打包脚本会自动生成多尺寸 `AppIcon.icns` 并写入 App 包。弹窗 Logo 使用 `Sources/AgentUsageDashboard/Resources/AgentMeterLogoWhite.png` 的透明白色版本，不改变 App 图标源。
- 视觉概念图归档在 `assets/references/agent-concept.png`；弹窗界面完全采用原生 SwiftUI 矢量布局与暗色材质绘制，不使用静态背景贴图。
- 点击弹窗左上角 Logo 会打开独立的原生“设置”窗口；设置内容暂留占位，后续再接入服务开关。
- 杂志风与国际主义设计（Swiss Style）：深墨黑 `#0A0C10`、网格表面 `#11151C`、`0.75pt` 发丝线与微型 20 格精密分段能量标尺。
- Codex / Kimi 账号额度：仿照 `cc-switch` 模式，优先通过轻量级 HTTPS 直连接口（读取本地 Keychain 或 `~/.codex/auth.json`、`~/.kimi-code/credentials/kimi-code.json` 凭据直接请求官方后端，支持静默自动刷新），百毫秒级响应且无子进程开销；Codex 直连未果时平滑降级至 `codex app-server`。
- 打开面板才查询，平时不查询：带 30 秒智能防刷冷却，频繁打开自动复用内存快照避免限频；面板关闭立即中断在途请求，后台常驻期间绝无网络活动。
- Codex/Kimi 用量统计对齐 `cc-switch`：精准解析会话日志中的 `last_token_usage` 与 `total_token_usage` 增量 delta，兼容 `cached_input_tokens` 与 `cache_read_input_tokens`，在面板中展示真实算力消耗、输入输出细分与缓存命中率（Cache Hit Rate），并按日聚合 7 天趋势分桶。
- 5 小时额度显示相对重置时长，周额度显示具体重置时间；服务端没有返回的窗口不会被 UI 猜测补齐。
- 本地日志变化时只增量更新本地 Token 统计；不轮询、不触发网络请求。
- 本地保存最近 30 天快照到 `~/Library/Application Support/AgentUsageDashboard/snapshots.json`。
- 隐私保障：不保存提示词、回复、代码正文或登录凭证。

## 数据边界

账号额度和账号 Token 总量是跨设备的服务器数据；本机模型排行只代表当前 Mac 的日志观测值。Codex 与 Kimi Code 均通过各自的轻量官方直连接口获取实时 5 小时与周额度，不制造虚假的账号级百分比。

## 使用

先完成官方 CLI 登录：

```sh
codex login
kimi
# 在 Kimi CLI 中完成 /login
```

然后用 Xcode 打开 `Package.swift`，选择 `AgentUsageDashboard` 运行。

也可以直接打包成菜单栏 App：

```sh
./Scripts/package-app.sh
open Build/AgentUsageDashboard.app
```

打包脚本会使用 macOS 原生 `sips` 和 `iconutil` 从 `assets/image.png` 生成 App 图标，不需要手动准备 `.icns` 文件。

首版关闭 App Sandbox，因为需要在用户打开弹窗时启动本机已经安装的 `codex app-server`。App 只访问明确的 Codex/Kimi 数据路径，并在 README 中公开这些路径。

## 验证

```sh
swift test
swift build
```

如果当前终端的 SwiftPM 缓存目录不可写，可把 SwiftPM 的 `--cache-path` 和 `--scratch-path` 指向一个可写的临时目录。
