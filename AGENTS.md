# AGENTS.md

Agent Meter 是一个低资源、原生 macOS 菜单栏用量仪表盘，面向 Codex 和 Kimi Code。最低 macOS 13 Ventura。SwiftPM 使用 `AgentUsageDashboardKit` dynamic library product/target 承载应用代码与 SwiftUI 预览，`AgentUsageDashboardLauncher` executable target 只负责启动 App。

## 构建、测试与打包

```sh
swift build
swift test
./Scripts/package-app.sh   # 生成 Build/AgentUsageDashboard.app
```

Xcode Canvas 预览入口在 `Sources/AgentUsageDashboard/UI/MenuBar/PopoverPreviews.swift`（仅 DEBUG 编译，含假数据）。预览代码属于 `AgentUsageDashboardKit` dynamic library product；在 Xcode scheme 菜单中选择 `AgentUsageDashboardKit` 预览，选择 `AgentUsageDashboard` executable product 时会触发 Xcode 26 的 `ENABLE_DEBUG_DYLIB` 提示。App 启动入口位于 `Sources/AgentUsageDashboard/App/App.swift`，由 `Sources/AgentUsageDashboardLauncher/main.swift` 调用。

## 目录与依赖方向

```text
App ──> Features ──> Core
 │          │
 └──> UI ───┘
Data ──────> Core
```

- `Sources/AgentUsageDashboard/App`：生命周期、依赖组装（`AppDependencies`）、菜单栏入口和窗口注册。
- `Sources/AgentUsageDashboard/Core`：领域模型（`Domain`）、协议端口（`Ports`）和纯逻辑工具（`Support`）。只允许依赖 Foundation；不得导入 SwiftUI、AppKit、Charts、ServiceManagement，不得访问具体文件路径或启动进程。
- `Sources/AgentUsageDashboard/Data`：Core 协议的实现，包括 Provider 采集器、Codex App Server 客户端、快照持久化和 FSEvents 目录监听。
- `Sources/AgentUsageDashboard/Features`：刷新编排（`RefreshCoordinator`）、应用状态（`DashboardModel`）、导航状态和设置仓库。不直接操作 `FileManager`、`Process` 或 UserDefaults 键名。
- `Sources/AgentUsageDashboard/UI`：只消费 `DashboardModel` 和 Core 模型；不读取日志、不启动 CLI、不请求 App Server。

目录隔离无法在编译器层面强制，以上方向由本文件、测试和代码审查共同约束。

## Provider adapter

新增 Provider（如 Claude、Gemini）时：

1. 在 `Data/Providers/<Name>/` 下新增采集器和 adapter，实现 `UsageProviderAdapter` 协议。
2. 在 `Core/Domain/Provider.swift` 增加枚举 case。
3. 在 `App/AppDependencies.swift` 注册 adapter 和监听目录。
4. 不在 `DashboardModel` 或 UI 中增加 Provider 专属分支；adapter 随应用版本发布，不做运行时动态加载。

UI 样式约定：所有 provider 共用同一套视觉样式，不随 provider 换色。文字为白色（主信息）或 `secondaryText` 暗色（辅助信息）；图标、进度条、曲线等装饰统一用固定蓝 `AppTheme.codex`。新增 provider 只需提供数据与 `Resources/ProviderIcon<Name>.png` 图标，UI 无需改动。

数据边界：账号额度和账号 Token 是服务端账号口径（跨设备）；模型排行和本机 Token 是当前 Mac 的日志观测值。账号查询失败时保留上一份可用账号数据并显示错误，不制造虚假的账号级百分比。

## 性能要求

- 无固定轮询：刷新严格由弹窗出现（带 30 秒智能防刷冷却，平时完全不发网络请求，弹窗关闭立即中断在途请求）、手动刷新和目录变化（1 秒防抖后的本地日志刷新，绝不触发网络）触发。
- 账号通道与本地通道解耦：Codex 与 Kimi Code 额度均优先通过轻量级 HTTPS 直连接口（读取本地 Keychain 或 `~/.codex/auth.json`、`~/.kimi-code/credentials/kimi-code.json` 凭据直接请求官方后端，百毫秒级且免子进程开销）；Codex 直连失败或凭据未配置时降级至 `codex app-server` 兜底。
- 本地日志统计对齐 cc-switch：同时支持 `last_token_usage` 与 `total_token_usage` 的 delta 增量计算，兼容 `cached_input_tokens` 与 `cache_read_input_tokens` 别名，并从本地日志聚合 7 日历史趋势分桶与计算缓存命中率（Cache Hit Rate）。
- 日志采集在 utility 优先级后台执行，结果回主 actor 发布。
- 采集器按文件做增量缓存（修改时间 + 文件大小为键），未变化的文件不重复解析；解析按行流式读取，并逐行释放 autorelease 对象，避免全量日志堆积内存。
- 内存中的历史快照与落盘保持同一 30 天裁剪规则，并按 5 分钟最小间隔记录，常驻期间不无限增长；落盘加载时裁掉 30 天外或未来时间的本地分桶。
- 弹窗关闭后不保持网络连接，无常驻后台网络或 CLI 进程。

## 隐私要求

- 不保存提示词、回复、代码正文、Cookie、令牌或完整日志行。
- 只访问明确的 Codex/Kimi 数据路径（`~/.codex/sessions`、`~/.kimi-code/sessions`）和 `~/Library/Application Support/AgentUsageDashboard/snapshots.json`。
- 快照只保存最近 30 天，JSON 字段和文件路径变更属于数据格式变更，需同步 README。

## 测试要求

- 测试使用临时目录、fixture 和 fake（`Tests/AgentUsageDashboardTests/Support/TestFakes.swift`），不依赖真实账号、用户目录或网络。
- 测试目录按职责镜像源码：`Core/`、`Data/`、`Features/`、`Support/`。
- ISO8601 落盘精度到秒，涉及快照相等的断言使用整秒时间。

## 文档同步

功能、接口、数据格式、目录结构或交互变化时，同步检查并更新 README 和本文件，保持命令、路径和数据边界与实际一致。

## 独立功能完成后的自动提交与推送

- 自动提交与推送适用于大功能，也适用于功能边界清晰的小功能。小功能应当职责单一、变更范围可准确识别、可以独立测试和回滚，并且不是依赖尚未完成的大型改造才能成立的中间切片。
- 功能是否完成由 Agent 自主判断，不等待用户明确说“完成”。判断必须结合代码实际完成度：约定范围和核心路径已实现，相关测试通过，文档已同步，没有已知阻塞问题或临时残留。
- 当用户开始一个与上一项无关的新功能时，Agent 必须先复核上一功能单元的代码完成度；若满足上述完成条件，应判定该功能单元已经完成，并在开始新功能前完成收尾、提交与推送。不能只凭话题切换判断完成，也不能因用户没有宣布完成而无限推迟提交。
- 判定独立功能完成后，Agent 自动检查 `git status` 与 diff，只暂存该功能及其必要测试、文档的变更；完成临时残留清理并运行相关测试后，创建清晰的提交，并将当前分支推送到已配置的 GitHub upstream，无需再次请求用户确认。
- 用户明确要求暂不提交或暂不推送时，以用户要求为准。禁止强制推送、改写历史或把密钥、构建产物、无关改动纳入提交。
- 若测试失败、变更无法与用户的其他未提交内容安全分离、GitHub 鉴权或 upstream 缺失、远端拒绝推送或存在冲突，不得绕过保护或擅自扩大提交范围；保留本地变更并向用户说明阻塞原因。

## 提交前清理

提交前检查并清理调试输出、临时脚本、假数据和没有正式引用的验证代码；正式回归测试和 fixture 不属于清理范围。
