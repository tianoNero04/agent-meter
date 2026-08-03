# AI Usage Dashboard

一个低资源、原生 macOS 菜单栏用量仪表盘，面向 Codex 和 Kimi Code。

点击右上角图标后，App 才会打开详情并刷新账号级数据；平时只保留轻量的菜单栏进程和文件事件监听。

## 当前能力

- macOS 原生 SwiftUI `MenuBarExtra`，最低 macOS 13 Ventura。
- Codex 账号额度：通过官方 `codex app-server` 查询 `account/rateLimits/read`。
- 额度窗口完全按账号服务端返回的 `windowDurationMins` 显示；如果账号当前只返回 `10080` 分钟，就只显示“本周”，不会假定存在 5 小时窗口。
- Codex 账号 Token 总量与每日 buckets：通过 `account/usage/read` 查询。
- Codex 本机 Token 与模型分布：增量解析 `~/.codex/sessions/**/*.jsonl`。
- Kimi Code 本机 Token 与模型分布：解析 `~/.kimi-code/sessions/**/wire.jsonl`。
- 目录发生变化时，只重新聚合本机日志；不轮询、不执行 CLI。
- 点击菜单栏图标时刷新 Codex 账号数据；弹窗关闭后不保持网络连接。
- 本地保存最近 30 天快照到 `~/Library/Application Support/AgentUsageDashboard/snapshots.json`。
- 不保存提示词、回复、代码正文或登录凭证。

## 数据边界

账号额度和账号 Token 总量是跨设备的服务器数据；本机模型排行只代表当前 Mac 的日志观测值。当前 Codex 账号接口没有返回按模型拆分的全账号 Token，因此 UI 会明确标记“本机观测”。

Kimi Code 的官方 `/usage` 目前仍是交互式 CLI 命令；本版本先提供 Kimi 本机日志统计，并把账号额度显示为“平台适配器待接入”，不会抓取网页 Cookie 或要求粘贴凭证。后续可以增加 PTY 或官方非交互接口适配器。

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

首版关闭 App Sandbox，因为需要在用户打开弹窗时启动本机已经安装的 `codex app-server`。App 只访问明确的 Codex/Kimi 数据路径，并在 README 中公开这些路径。

## 验证

```sh
swift test
swift build
```

如果当前终端的 SwiftPM 缓存目录不可写，可把 SwiftPM 的 `--cache-path` 和 `--scratch-path` 指向一个可写的临时目录。
