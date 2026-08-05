# Agent Meter 模块化与开发规范设计

日期：2026-08-05
状态：已获用户确认，待进入实施计划

## 1. 背景

Agent Meter 当前是一个 macOS 原生菜单栏用量仪表盘，使用单一 SwiftPM executable target。现有功能已经覆盖 Codex 与 Kimi Code 的本机日志统计、Codex 账号额度查询、历史快照、文件变化监听和顶部 Provider 导航。

当前源码全部平铺在 `Sources/AgentUsageDashboard` 下，`Views.swift` 集中了菜单栏、设置、详情页和通用组件，`DashboardModel` 同时负责状态发布、持久化、文件监听、采集器构造、刷新调度和账号请求。项目根目录也没有统一的开发规范文件。

本设计解决结构和职责问题，不改变现有产品行为、数据口径或持久化格式。

## 2. 目标

- 在保留单一 SwiftPM target 的前提下建立清晰的分层目录。
- 以协议隔离 Provider、持久化和目录监听实现。
- 让 `DashboardModel` 只负责应用状态和用例编排。
- 让 Codex、Kimi Code 以及未来 Provider 通过统一 adapter 接入。
- 保持现有刷新时机、账号与本机数据边界、历史快照格式和 UI 行为不变。
- 通过可注入的 fake 实现提高测试稳定性，不依赖真实登录、用户目录或网络。
- 新增根目录 `AGENTS.md`，固定模块边界、性能、隐私、测试和文档同步规则。

## 3. 非目标

- 不引入运行时动态插件系统。
- 不拆分多个 SwiftPM target 或独立 Package。
- 不新增 Claude、Gemini 等 Provider 功能。
- 不改变快照 JSON 字段、UserDefaults 键名、数据保存路径或保留周期。
- 不借模块化之机重做菜单栏 UI、文案或交互。
- 不启用 App Sandbox，也不改变现有用户授权策略。

## 4. 方案选择

评估过三种方案：

1. 仅移动文件到几个目录。风险低，但职责和依赖关系仍然容易重新变平。
2. 单一 target 的分层架构加端口/适配器。能够在不增加构建复杂度的情况下隔离 Core、Data、Features 和 UI，是本项目采用的方案。
3. 多 SwiftPM target 或运行时插件。隔离性更强，但会增加 Package.swift、签名、版本兼容和测试维护成本，不符合当前规模。

采用方案 2，并将“可扩展 Provider”定义为源码级 adapter：新增 Provider 时遵循统一协议并随应用版本发布，不做运行时动态加载。

## 5. 目标目录结构

```text
Sources/AgentUsageDashboard/
├── App/
│   ├── App.swift
│   └── AppDependencies.swift
├── Core/
│   ├── Domain/
│   │   ├── Provider.swift
│   │   ├── UsageModels.swift
│   │   ├── SnapshotModels.swift
│   │   └── ProviderPreferences.swift
│   ├── Ports/
│   │   ├── UsageProvider.swift
│   │   ├── SnapshotRepository.swift
│   │   ├── DirectoryWatcher.swift
│   │   └── ProviderSettingsStore.swift
│   └── Support/
│       ├── JSONSupport.swift
│       └── NumberFormatting.swift
├── Data/
│   ├── Providers/
│   │   ├── Codex/
│   │   │   ├── CodexProvider.swift
│   │   │   ├── CodexAppServerClient.swift
│   │   │   └── CodexSessionCollector.swift
│   │   └── Kimi/
│   │       ├── KimiProvider.swift
│   │       └── KimiSessionCollector.swift
│   ├── Persistence/
│   │   └── JSONSnapshotRepository.swift
│   └── FileWatching/
│       └── FSEventsDirectoryWatcher.swift
├── Features/
│   ├── Dashboard/
│   │   ├── DashboardModel.swift
│   │   └── RefreshCoordinator.swift
│   ├── Navigation/
│   │   └── ProviderNavigationState.swift
│   └── Settings/
│       └── UserDefaultsProviderSettingsStore.swift
└── UI/
    ├── MenuBar/
    │   ├── PopoverView.swift
    │   ├── PopoverHeader.swift
    │   ├── ProviderNavigationBar.swift
    │   ├── OverviewPanel.swift
    │   ├── ProviderPanel.swift
    │   ├── SettingsPanel.swift
    │   └── PopoverFooter.swift
    ├── Details/
    │   ├── DetailsView.swift
    │   ├── OverviewTab.swift
    │   ├── ProviderTrendCard.swift
    │   └── ModelUsageTab.swift
    └── Components/
        ├── ProviderCard.swift
        ├── RateLimitRow.swift
        ├── Metric.swift
        ├── StatusBadge.swift
        └── ProviderIconTile.swift
```

测试目录按职责镜像：

```text
Tests/AgentUsageDashboardTests/
├── Core/
├── Data/Codex/
├── Data/Kimi/
├── Features/
└── Support/
```

这不是“一类型一文件”的硬性要求。小型、强相关的私有 SwiftUI 子视图可以放在同一个文件中；拆分依据是职责和依赖，而不是文件数量。

## 6. 依赖方向

```text
App ──> Features ──> Core
 │          │
 └──> UI ───┘
Data ──────> Core
```

- `Core` 只包含领域模型、协议和纯逻辑，只允许依赖 Foundation；不得导入 SwiftUI、AppKit、Charts、ServiceManagement，也不得访问具体文件路径或启动进程。
- `Data` 实现 Core 协议，可以访问文件系统、FSEvents、JSONL 和 Codex App Server。
- `Features` 负责编排刷新、应用状态、历史和导航设置，但不直接操作 `FileManager`、`Process` 或 UserDefaults 键名。
- `UI` 只消费 `DashboardModel` 和 Core 模型，不读取日志、不启动 CLI、不请求 App Server。
- `App` 只负责生命周期、依赖组装、菜单栏入口和窗口注册。

SwiftPM 单 target 不会在编译器层面强制目录隔离，因此以上方向由 `AGENTS.md`、测试和代码审查共同约束。

## 7. 协议与职责边界

### 7.1 Provider adapter

Core 提供统一的 Provider 入口，概念接口如下：

```swift
protocol UsageProviderAdapter {
    var provider: Provider { get }

    func refresh(
        previous: ProviderSnapshot,
        includeAccount: Bool
    ) async -> ProviderSnapshot
}
```

`CodexProvider` 组合 Codex 本机会话采集器和 App Server 客户端。账号查询失败时沿用上一份账号窗口和账号 Token，同时更新本机日志统计并保留错误信息。

`KimiProvider` 组合 Kimi 本机会话采集器。当前没有账号接口时返回本机日志统计和明确的“账号额度待接入”状态，不制造账号级百分比。

未来增加 Claude 或 Gemini 时，只新增对应 Provider 目录和 adapter，不在 `DashboardModel` 或 UI 中增加 Provider 专属分支。

### 7.2 持久化与监听

```swift
protocol SnapshotRepository {
    func load() -> PersistedDashboard?
    func save(current: DashboardSnapshot, history: [DashboardSnapshot])
}

protocol DirectoryWatcher {
    func start()
    func stop()
}

protocol ProviderSettingsStore {
    func load() -> ProviderPreferences
    func save(_ preferences: ProviderPreferences)
}
```

`JSONSnapshotRepository` 负责 ISO 日期编码、快照文件和最近 30 天裁剪。`FSEventsDirectoryWatcher` 负责目录变化回调。`UserDefaultsProviderSettingsStore` 负责启用 Provider 和当前选中 Provider 的键值读写。

`ProviderPreferences` 是 Core 中不含 UI 语义的值对象；`Features/Navigation` 将它映射成 `ProviderNavigationState`，避免 Core 反向依赖 Features。

### 7.3 Features

`DashboardModel` 保留 `@MainActor ObservableObject`，但只负责：

- 发布 Provider 快照、刷新状态、历史、错误和最后刷新时间。
- 通过 adapter 执行本地或账号刷新。
- 将结果写入 Repository。
- 响应导航选择、Provider 开关和窗口生命周期。

`RefreshCoordinator` 负责刷新任务取消、防抖、本地/账号刷新分流、utility 优先级后台任务和主 actor 回传。`DashboardModel` 不再构造 `CodexLogCollector`、`KimiLogCollector`、`SnapshotStore` 或 `FileTreeWatcher`。

导航状态属于 `Features/Navigation`，不放入 Core 领域模型，因为它是应用界面状态，不是 Provider 数据。

## 8. 数据流与行为保持

```text
菜单栏弹窗出现 ─┐
目录变化 ───────> RefreshCoordinator
                         │
                         ▼
                  Provider adapters
                    │          │
              本机日志      Codex App Server
                    │          │
                    └────┬─────┘
                         ▼
                DashboardModel (@MainActor)
                         │
                ┌────────┴────────┐
                ▼                 ▼
              UI          SnapshotRepository
```

必须保持的行为：

- App 启动时加载历史快照、启动 Codex/Kimi 目录监听，并执行一次本地刷新。
- 菜单栏弹窗出现时执行账号刷新；Codex App Server 只在该路径短暂启动。
- 目录变化经过 1 秒防抖后只触发本地刷新，不轮询、不执行 CLI。
- 账号数据是服务端账号口径；模型排行和本机 Token 是当前 Mac 的日志观测值。
- Codex 只返回周窗口时只显示周窗口；返回多个窗口时按服务端返回展示。
- 账号请求失败时保留上一份可用账号数据，并在状态中显示错误。
- 历史快照继续保存最近 30 天，原有文件路径和 JSON 结构不变。

## 9. `AGENTS.md` 内容设计

根目录新增一个 `AGENTS.md`，不增加嵌套规范文件。它包含：

1. 项目定位、macOS 版本、构建/测试/打包命令。
2. `App / Core / Data / Features / UI` 的职责和允许的依赖方向。
3. Provider adapter 的新增流程和账号数据/本机数据边界。
4. 性能要求：无固定轮询、可取消刷新、utility 后台采集、低内存和无 CLI 常驻。
5. 隐私要求：不保存提示词、回复、代码正文、Cookie、令牌或完整日志行。
6. 测试要求：使用临时目录、fixture 和 fake，不依赖真实账号或网络。
7. README、接口、数据格式和交互变化时的文档同步要求。
8. 提交前清理调试输出、临时脚本、假数据和未引用代码的要求。

## 10. 迁移顺序

1. 建立基线：确认当前测试和构建通过，记录现有职责和数据格式。
2. 拆分 Core：拆出领域模型、快照模型和协议；保持 Codable 字段和 UserDefaults 键名不变。
3. 迁移 Data：移动采集器、App Server、监听器和快照存储，新增 Codex/Kimi adapter。
4. 拆分 Features：抽出刷新协调器和设置仓库，让 DashboardModel 通过依赖注入工作。
5. 拆分 UI：按菜单栏、详情和通用组件拆分 `Views.swift`，不改变视觉和交互。
6. 在 App 中集中组装依赖，新增 `AGENTS.md`，同步 README。
7. 做完整测试、构建、打包和临时残留清理。

每一步都应保持可编译、可测试、可回退；目录移动、协议迁移和 UI 拆分不与新的功能混合提交。

## 11. 测试与验收

### 自动化测试

- Core 模型编码/解码和旧快照兼容。
- Codex App Server 解析，包括仅周窗口和多窗口返回。
- Codex/Kimi 日志采集 fixture。
- Provider adapter 的本地刷新、账号刷新和账号失败回退。
- RefreshCoordinator 的取消、防抖和 `includeAccount` 分流。
- SnapshotRepository 的 30 天裁剪和原子写入。
- DashboardModel 使用 fake Provider、Repository、Watcher 的编排测试。
- 导航设置的读写和禁用当前 Provider 后的选择回退。

### 验收条件

- `swift test` 全部通过。
- `swift build` 成功。
- `./Scripts/package-app.sh` 能生成菜单栏 App。
- Codex/Kimi 数据口径、刷新时机、数据路径和 UI 行为无意外变化。
- 不产生固定轮询、CLI 常驻进程或新的敏感数据落盘。
- README、AGENTS.md 与实际目录、命令和数据边界一致。
- 提交前没有调试打印、临时验证脚本、假数据或未引用代码残留。

## 12. 风险与缓解

| 风险 | 缓解方式 |
| --- | --- |
| 单 target 无法强制模块访问 | 用 AGENTS.md、测试和审查约束依赖方向；未来确有需要再拆 target |
| 文件移动造成 SwiftUI 可见性或预览问题 | 先拆 Core/Data，再拆 UI；每步编译和测试 |
| Provider 协议过早抽象 | 只抽当前已有的本地刷新、账号刷新和错误回退能力，不引入动态插件生命周期 |
| 并发迁移引入状态竞争 | 保持 DashboardModel 主 actor；adapter 无 UI 状态；刷新任务集中由协调器管理 |
| 旧快照无法读取 | 保留 Codable 字段和日期策略，增加兼容 fixture 测试 |

## 13. 参考

菜单栏应用的目录职责、设置页面和轻量运行方式参考了以下公开项目的组织思路；未直接复制其实现：

- [SaneBar](https://github.com/sane-apps/SaneBar)
- [FineTune](https://github.com/ronitsingh10/FineTune)
