# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

CodexBar 是一个 macOS 14+ 菜单栏应用程序，用于跟踪多个 AI 提供商（Codex、Claude、Cursor、Gemini、Antigravity 等）的使用配额和会话限制。项目采用 Swift 6 严格并发模式，使用 SwiftPM 包管理。

### 项目背景

本项目是从 [steipete/CodexBar](https://github.com/steipete/CodexBar) fork 的。Fork 的主要目的是：
1. **扩展功能**：根据个人需求添加额外的功能支持
2. **安全性保证**：通过从源码构建确保二进制的可信性和安全性
3. **个人使用**：构建出的 app 仅限个人使用，不进行分发或发布

## 核心架构

### 模块结构

- **Sources/CodexBar**: 主应用程序（SwiftUI + AppKit），处理 UI、状态管理、菜单栏图标
  - `CodexBarApp.swift`: 应用入口点
  - `StatusItemController.swift`: 菜单栏图标控制器
  - `UsageStore.swift`: 使用数据管理
  - `SettingsStore.swift`: 用户偏好设置
  - `Providers/`: 各提供商的 UI 实现和设置钩子

- **Sources/CodexBarCore**: 共享业务逻辑，可跨平台使用
  - `Providers/`: 所有提供商的核心实现
    - 每个提供商有独立的文件夹，包含 Descriptor、Strategies、Probe、Fetcher、Models
    - `ProviderDescriptor.swift`: 提供商描述符（标签、URL、策略管道）
    - `Providers.swift`: 提供商枚举定义
  - `Vendored/`: 第三方集成（如 CostUsageScanner）
  - `Logging/`: 日志系统

- **Sources/CodexBarCLI**: 命令行工具（`codexbar` 命令）

- **Sources/CodexBarWidget**: WidgetKit 扩展

- **Sources/CodexBarMacros + CodexBarMacroSupport**: Swift 宏，用于提供商自动注册

### 数据流

```
后台刷新 → UsageFetcher/提供商探针 → UsageStore → 菜单/图标/Widget
设置切换 → SettingsStore → UsageStore 刷新频率 + 功能标志
```

### 提供商系统架构

**关键设计原则**：
- 每个提供商通过 `ProviderDescriptor` 定义，包含标签、URL、能力、获取管道
- 使用宏自动注册：`@ProviderDescriptorRegistration` + `@ProviderDescriptorDefinition`
- 获取策略（ProviderFetchStrategy）按优先级管道执行，支持失败回退
- 提供商数据必须隔离：提供商 A 的身份/计划字段绝不能显示在提供商 B 的 UI 中

**添加新提供商流程**：
1. 在 `Sources/CodexBarCore/Providers/Providers.swift` 添加 `UsageProvider` 枚举值
2. 创建 `Sources/CodexBarCore/Providers/<ProviderID>/` 文件夹：
   - `<ProviderID>Descriptor.swift`: 定义描述符和获取管道
   - `<ProviderID>Strategies.swift`: 实现获取策略
   - 其他必要的文件（Probe、Fetcher、Models、Parser）
3. 在 `Sources/CodexBar/Providers/<ProviderID>/` 创建 UI 实现
4. 添加图标资源：`ProviderIcon-<id>.svg`
5. 编写测试和文档

详见 `docs/provider.md`。

## 开发工作流

### 构建和运行

```bash
# 完整开发循环（推荐）：构建、测试、打包、启动
./Scripts/compile_and_run.sh

# 仅构建和打包（不运行测试）
./Scripts/package_app.sh

# 启动已存在的应用
./Scripts/launch.sh

# Swift 原生命令
swift build              # Debug 构建
swift build -c release   # Release 构建
swift test               # 运行测试套件
```

**重要**：修改代码后，必须运行 `./Scripts/compile_and_run.sh` 来确保应用反映最新更改。该脚本会：
1. 终止旧实例
2. 运行 `swift build` 和 `swift test`
3. 打包应用
4. 重新启动 `CodexBar.app`
5. 验证应用保持运行状态

### 代码风格

项目使用严格的代码格式化规则：
```bash
swiftformat Sources Tests
swiftlint --strict
```

- 4 空格缩进
- 120 字符行宽
- 显式 `self` 是有意的，不要移除
- 提交前必须运行格式化和 lint 检查

### SwiftUI 最佳实践

优先使用现代 SwiftUI/Observation 宏：
- 使用 `@Observable` 模型配合 `@State` 所有权
- 视图中使用 `@Bindable`
- 避免 `ObservableObject`、`@ObservedObject`、`@StateObject`

## 测试

```bash
# 运行所有测试
swift test

# 运行特定测试
swift test --filter test_functionName
```

测试位于 `Tests/CodexBarTests/`，使用 XCTest 框架。为新添加的解析逻辑或格式化场景添加测试用例。

## 平台和并发

- **目标平台**: macOS 14+ (Sonoma)
- **并发模式**: Swift 6 严格并发已启用
- 优先使用 Sendable 状态和显式 MainActor 跳转
- 重构时避免使用已弃用的 API

## 关键文件和文档

### 架构文档
- `docs/architecture.md`: 模块、入口点和数据流概述
- `docs/provider.md`: 提供商编写指南（必读）
- `docs/refresh-loop.md`: 刷新频率和后台更新
- `docs/DEVELOPMENT.md`: 开发工作流详解

### 提供商文档
- `docs/providers.md`: 所有提供商概述
- `docs/codex.md`, `docs/claude.md`, `docs/gemini.md` 等：各提供商详细文档

### 其他重要文档
- `docs/cli.md`: CLI 工具参考
- `docs/ui.md`: UI 和图标设计说明
- `docs/status.md`: 状态轮询机制
- `docs/RELEASING.md`: 发布检查清单

## 发布流程

```bash
# 签名和公证（创建分发包）
./Scripts/sign-and-notarize.sh

# 生成 appcast（Sparkle 更新源）
./Scripts/make_appcast.sh <zip-file> <feed-url>
```

详见 `docs/RELEASING.md`。

## 调试技巧

### 启用详细日志
1. 打开 Debug → Logging → "Enable file logging"
2. 日志写入 `~/Library/Logs/CodexBar/CodexBar.log`
3. 或在 Console.app 中过滤 "codexbar"

### Keychain 提示（开发环境）
首次启动后，会看到每个存储凭据的一次性 Keychain 提示。这是将现有 Keychain 项迁移到使用 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` 的一次性过程。后续重建不会提示。

重置迁移（测试用）：
```bash
defaults delete com.steipete.codexbar KeychainMigrationV1Completed
```

### Cookie 问题调试
```bash
# 启用调试日志
export CODEXBAR_LOG_LEVEL=debug
./Scripts/compile_and_run.sh

# 在 Console.app 中检查日志
# 过滤：subsystem:com.steipete.codexbar category:<provider>-cookie
```

## 依赖管理

主要依赖：
- **Sparkle**: 自动更新
- **Commander**: CLI 框架
- **swift-log**: 日志系统
- **swift-syntax**: 宏支持
- **KeyboardShortcuts**: 快捷键支持
- **SweetCookieKit**: 浏览器 Cookie 导入

使用本地 SweetCookieKit 开发：
```bash
export CODEXBAR_USE_LOCAL_SWEETCOOKIEKIT=1
```

## 常见任务

### 添加新提供商
参见上面的"提供商系统架构"部分和 `docs/provider.md`。

### 修复解析逻辑
1. 在 `Tests/CodexBarTests/` 添加/更新测试用例
2. 修改解析代码
3. 运行 `swift test` 验证
4. 运行 `./Scripts/compile_and_run.sh` 进行端到端测试

### 更新 UI
- SwiftUI 视图位于 `Sources/CodexBar/`
- 遵循现有的 `MARK` 组织结构
- 使用描述性符号，匹配当前提交风格

### 修改刷新逻辑
- 刷新循环在 `docs/refresh-loop.md` 中有详细说明
- `RefreshFrequency`: Manual, 1m, 2m, 5m（默认）, 15m, 30m
- 后台刷新在主线程外运行并更新 `UsageStore`

## 项目约束

- **无 Docker icon**: 应用是纯菜单栏应用（LSUIElement = true）
- **隐私优先**: 默认本地解析；浏览器 Cookie 是可选的
- **提供商隔离**: 严格保持各提供商数据分离
- **可靠性**: 提供商必须有超时限制；禁止对网络/PTY/UI 的无限等待
- **降级策略**: 优先使用缓存数据而不是抖动；显示清晰的错误提示

## 代码审查检查清单

提交代码前确保：
- [ ] 运行了 `swiftformat Sources Tests` 和 `swiftlint --strict`
- [ ] 运行了 `swift test` 或 `./Scripts/compile_and_run.sh`
- [ ] 为新逻辑添加了测试用例
- [ ] 遵循了 Swift 6 严格并发规则
- [ ] 保持了提供商数据隔离
- [ ] 提交信息使用简短的祈使句（如"Improve usage probe"）

## 本地 SweetCookieKit 开发

如需使用本地 SweetCookieKit 副本：
```bash
# 确保 SweetCookieKit 在同级目录
ls ../SweetCookieKit

# 设置环境变量后构建
export CODEXBAR_USE_LOCAL_SWEETCOOKIEKIT=1
./Scripts/compile_and_run.sh
```
