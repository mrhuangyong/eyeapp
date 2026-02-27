# 菜单栏图标和通知控制改进实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 改进菜单栏图标（白色图标 + 彩色背景）并添加通知控制开关，让用户可以选择通知方式。

**Architecture:** 修改 StatusBarController 的图标生成逻辑，使用图像合成技术创建复合图标；在 AppConfig 中添加通知控制字段，在设置界面添加对应的 UI 控件。

**Tech Stack:** Swift, SwiftUI, AppKit (NSImage, NSStatusBar), UserNotifications

---

## Task 1: 添加通知控制配置字段

**Files:**
- Modify: `eye-app/Source/Models/AppConfig.swift:40-50` (在 alertInterval 后添加)

**Step 1: 添加新配置字段**

在 `AppConfig.swift` 的 `// MARK: - Alert Settings` 部分，在 `soundEnabled` 之后添加：

```swift
/// 声音提醒
var soundEnabled: Bool = true

/// 是否启用弹窗提醒
var alertModalEnabled: Bool = true

/// 是否启用系统通知
var alertNotificationEnabled: Bool = true
```

**Step 2: 更新 CodingKeys 枚举**

在 `AppConfig.swift` 的 `CodingKeys` 枚举中添加新字段（约第 102-115 行）：

```swift
enum CodingKeys: String, CodingKey {
    case alertEnabled
    case alertThreshold
    case alertInterval
    case soundEnabled
    case alertModalEnabled       // 🆕 新增
    case alertNotificationEnabled // 🆕 新增
    case sensitivity
    case dataRetentionDays
    case recordRawEvents
    case previewEnabled
    case previewMirrored
    case launchAtLogin
    case autoStartMonitoring
    case showMenuBarIcon
}
```

**Step 3: 更新 encode 方法**

在 `AppConfig.swift` 的 `encode` 方法中添加新字段编码（约第 118-133 行）：

```swift
func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(alertEnabled, forKey: .alertEnabled)
    try container.encode(alertThreshold, forKey: .alertThreshold)
    try container.encode(alertInterval, forKey: .alertInterval)
    try container.encode(soundEnabled, forKey: .soundEnabled)
    try container.encode(alertModalEnabled, forKey: .alertModalEnabled)        // 🆕 新增
    try container.encode(alertNotificationEnabled, forKey: .alertNotificationEnabled) // 🆕 新增
    try container.encode(sensitivity, forKey: .sensitivity)
    try container.encode(dataRetentionDays, forKey: .dataRetentionDays)
    try container.encode(recordRawEvents, forKey: .recordRawEvents)
    try container.encode(previewEnabled, forKey: .previewEnabled)
    try container.encode(previewMirrored, forKey: .previewMirrored)
    try container.encode(launchAtLogin, forKey: .launchAtLogin)
    try container.encode(autoStartMonitoring, forKey: .autoStartMonitoring)
    try container.encode(showMenuBarIcon, forKey: .showMenuBarIcon)
}
```

**Step 4: 验证编译**

```bash
cd eye-app && xcodebuild -scheme eye-app -configuration Debug clean build
```

Expected: BUILD SUCCEEDED

**Step 5: 提交更改**

```bash
git add eye-app/Source/Models/AppConfig.swift
git commit -m "feat: add notification control config fields"
```

---

## Task 2: 添加 NSImage 扩展方法

**Files:**
- Create: `eye-app/Source/Extensions/NSImage+Tint.swift`

**Step 1: 创建 Extensions 目录**

```bash
mkdir -p eye-app/Source/Extensions
```

**Step 2: 创建 NSImage+Tint.swift 文件**

创建文件 `eye-app/Source/Extensions/NSImage+Tint.swift`：

```swift
//
//  NSImage+Tint.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import AppKit

extension NSImage {
    /// 为图像着色
    /// - Parameter color: 目标颜色
    /// - Returns: 着色后的图像
    func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }

    /// 创建复合图像（背景 + 图标）
    /// - Parameters:
    ///   - backgroundColor: 背景颜色
    ///   - iconSize: 图标尺寸
    /// - Returns: 复合图像
    func composite(withBackgroundColor backgroundColor: NSColor, iconSize: NSSize) -> NSImage {
        let totalSize = iconSize

        let compositeImage = NSImage(size: totalSize)
        compositeImage.lockFocus()

        // 1. 绘制圆形背景
        let circleRect = NSRect(origin: .zero, size: totalSize)
        let circlePath = NSBezierPath(ovalIn: circleRect)
        backgroundColor.setFill()
        circlePath.fill()

        // 2. 绘制白色图标（居中）
        let icon = self.tinted(with: .white)
        let iconDrawSize = NSSize(width: totalSize.width * 0.78, height: totalSize.height * 0.78)
        let iconOrigin = NSPoint(
            x: (totalSize.width - iconDrawSize.width) / 2,
            y: (totalSize.height - iconDrawSize.height) / 2
        )
        icon.draw(at: iconOrigin, from: NSRect(origin: .zero, size: self.size), operation: .sourceOver, fraction: 1.0)

        compositeImage.unlockFocus()

        return compositeImage
    }
}
```

**Step 3: 将文件添加到 Xcode 项目**

在 Xcode 中：
1. 右键点击 `eye-app/Source` 文件夹
2. 选择 "Add Files to 'eye-app'"
3. 选择 `Extensions` 文件夹
4. 确保勾选 "Copy items if needed" 和 target "eye-app"

**Step 4: 验证编译**

```bash
cd eye-app && xcodebuild -scheme eye-app -configuration Debug clean build
```

Expected: BUILD SUCCEEDED

**Step 5: 提交更改**

```bash
git add eye-app/Source/Extensions/
git commit -m "feat: add NSImage tint and composite extensions"
```

---

## Task 3: 修改 StatusBarController 图标生成逻辑

**Files:**
- Modify: `eye-app/Source/UI/StatusBarController.swift:221-248` (updateIcon 和 updateIconColor 方法)

**Step 1: 添加 getBackgroundColor 方法**

在 `StatusBarController.swift` 的 `// MARK: - Private Methods` 部分，在 `updateIcon()` 方法之前添加：

```swift
/// 获取图标背景颜色
private func getBackgroundColor() -> NSColor {
    // 优先使用疲劳状态的颜色
    if let fatigueStatus = fatigueStatus {
        return NSColor(fatigueStatus.color)
    }

    // 根据 StatusBarStatus 返回颜色
    switch status {
    case .ready:
        return .systemGray
    case .running:
        return .systemGreen
    case .paused:
        return .systemOrange
    case .noFace:
        return .systemYellow
    case .noPermission, .noCamera:
        return .systemRed
    case .error:
        return .systemRed
    }
}
```

**Step 2: 修改 updateIcon 方法**

替换现有的 `updateIcon()` 方法（第 221-229 行）：

```swift
private func updateIcon() {
    if let button = statusItem.button {
        // 加载 SF Symbol
        guard let symbolImage = NSImage(systemSymbolName: status.icon, accessibilityDescription: "EyeApp") else {
            // Fallback: 使用基本的眼睛图标
            let fallbackImage = NSImage(systemSymbolName: "eye", accessibilityDescription: "EyeApp")
            button.image = fallbackImage
            button.toolTip = status.tooltip
            return
        }

        // 获取背景颜色
        let backgroundColor = getBackgroundColor()

        // 创建复合图像：彩色背景 + 白色图标
        let iconSize = NSSize(width: 18, height: 18)
        let compositeImage = symbolImage.composite(withBackgroundColor: backgroundColor, iconSize: iconSize)

        button.image = compositeImage
        button.toolTip = status.tooltip
    }
}
```

**Step 3: 简化 updateIconColor 方法**

替换现有的 `updateIconColor()` 方法（第 231-247 行）：

```swift
private func updateIconColor(_ color: Color) {
    // 重新绘制图标以更新背景颜色
    updateIcon()
}
```

**Step 4: 验证编译**

```bash
cd eye-app && xcodebuild -scheme eye-app -configuration Debug clean build
```

Expected: BUILD SUCCEEDED

**Step 5: 提交更改**

```bash
git add eye-app/Source/UI/StatusBarController.swift
git commit -m "feat: implement white icon with colored background for status bar"
```

---

## Task 4: 在设置界面添加通知控制 UI

**Files:**
- Modify: `eye-app/Source/UI/SettingsPanelView.swift:63-110` (AlertSettingsView)

**Step 1: 在 AlertSettingsView 中添加通知方式选项**

在 `SettingsPanelView.swift` 的 `AlertSettingsView` 中，在声音提醒 Toggle 之后添加：

```swift
Toggle("启用声音提醒", isOn: $viewModel.config.soundEnabled)
    .disabled(!viewModel.config.alertEnabled)

// 🆕 新增：通知方式
VStack(alignment: .leading, spacing: 12) {
    Divider()

    Text("通知方式")
        .font(.subheadline)
        .fontWeight(.medium)

    Toggle("弹窗提醒", isOn: $viewModel.config.alertModalEnabled)
        .help("显示模态对话框提醒")

    Toggle("系统通知", isOn: $viewModel.config.alertNotificationEnabled)
        .help("发送系统通知到通知中心")

    if !viewModel.config.alertModalEnabled && !viewModel.config.alertNotificationEnabled {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text("建议至少启用一种通知方式")
                .font(.caption)
                .foregroundColor(.orange)
        }
    } else {
        Text("至少选择一种通知方式")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
.disabled(!viewModel.config.alertEnabled)
```

**Step 2: 验证编译**

```bash
cd eye-app && xcodebuild -scheme eye-app -configuration Debug clean build
```

Expected: BUILD SUCCEEDED

**Step 3: 提交更改**

```bash
git add eye-app/Source/UI/SettingsPanelView.swift
git commit -m "feat: add notification control UI in settings"
```

---

## Task 5: 修改弹窗提醒逻辑

**Files:**
- Modify: `eye-app/Source/UI/StatusBarController.swift:208-218` (showFatigueAlert 方法)

**Step 1: 添加配置检查**

修改 `showFatigueAlert` 方法，在方法开头添加配置检查：

```swift
/// 显示疲劳提醒
func showFatigueAlert(_ status: FatigueStatus) {
    // 检查配置：是否启用弹窗提醒
    guard config.alertModalEnabled else { return }

    let alert = NSAlert()
    alert.messageText = "👁️ 疲劳提醒"
    alert.informativeText = "\(status.recommendation)\n\n当前眨眼频率: \(Int(status.blinkRate)) 次/分钟"
    alert.alertStyle = .warning
    alert.addButton(withTitle: "休息一下")
    alert.addButton(withTitle: "稍后提醒")

    alert.runModal()
}
```

**Step 2: 验证编译**

```bash
cd eye-app && xcodebuild -scheme eye-app -configuration Debug clean build
```

Expected: BUILD SUCCEEDED

**Step 3: 提交更改**

```bash
git add eye-app/Source/UI/StatusBarController.swift
git commit -m "feat: add config check for modal alert"
```

---

## Task 6: 修改系统通知逻辑

**Files:**
- Modify: `eye-app/Source/Core/AlertManager.swift:113-121` (triggerAlert 方法)
- Modify: `eye-app/Source/Core/SessionManager.swift:259-270` (checkFatigueAlert 方法)

**Step 1: 修改 AlertManager 的 triggerAlert 方法**

在 `AlertManager.swift` 中，修改 `triggerAlert` 方法，移除自动发送通知的逻辑：

```swift
/// 触发提醒
func triggerAlert() {
    guard shouldTriggerAlert() else { return }

    let status = checkFatigueStatus()
    triggerAlertSilent()

    // 通知回调（让调用方决定是否发送系统通知）
    onAlertTriggered?(status)
}
```

**Step 2: 在 SessionManager 中添加配置引用**

在 `SessionManager.swift` 中，确保有配置引用（如果没有则添加）：

```swift
class SessionManager: ObservableObject {
    // MARK: - Dependencies
    private var cameraManager: CameraManagerProtocol
    private var visionService: VisionServiceProtocol
    private let blinkDetector: BlinkDetectorProtocol
    private let statsEngine: StatsEngine
    private let alertManager: AlertManager

    // 🆕 添加配置引用（如果还没有）
    var config: AppConfig = .default

    // ... 其他代码 ...
}
```

**Step 3: 修改 SessionManager 的 checkFatigueAlert 方法**

在 `SessionManager.swift` 中，修改 `checkFatigueAlert` 方法，添加通知控制逻辑：

```swift
private func checkFatigueAlert() {
    if alertManager.shouldTriggerAlert() {
        let status = alertManager.checkFatigueStatus()

        // 🆕 根据配置决定发送哪些通知
        // 弹窗提醒：通过回调触发（由 StatusBarController 控制）
        if config.alertModalEnabled {
            alertManager.triggerAlert()
        }

        // 系统通知：直接发送（如果启用）
        if config.alertNotificationEnabled {
            alertManager.sendNotification(status: status)
        }
    }
}
```

**注意:** 如果 `SessionManager` 已经有 `config` 属性，确保它从外部设置（例如在 `AppDelegate` 中）。

**Step 4: 验证编译**

```bash
cd eye-app && xcodebuild -scheme eye-app -configuration Debug clean build
```

Expected: BUILD SUCCEEDED

**Step 5: 提交更改**

```bash
git add eye-app/Source/Core/AlertManager.swift eye-app/Source/Core/SessionManager.swift
git commit -m "feat: implement notification control logic based on config"
```

---

## Task 7: 更新 AppDelegate 配置传递

**Files:**
- Modify: `eye-app/Source/eye_appApp.swift` (AppDelegate)

**Step 1: 确保配置传递到 SessionManager**

在 `eye_appApp.swift` 的 `AppDelegate` 中，检查 `setupSessionManager` 方法，确保配置传递到 `SessionManager`：

```swift
private func setupSessionManager() {
    sessionManager = SessionManager(
        cameraManager: cameraManager,
        visionService: visionService,
        blinkDetector: blinkDetector,
        statsEngine: statsEngine,
        alertManager: alertManager
    )

    // 🆕 设置配置（如果 SessionManager 需要配置）
    sessionManager.config = config

    // ... 其他代码 ...
}
```

**注意:** 如果 `SessionManager` 的初始化方法已经接受 `config` 参数，则跳过此步骤。

**Step 2: 验证编译**

```bash
cd eye-app && xcodebuild -scheme eye-app -configuration Debug clean build
```

Expected: BUILD SUCCEEDED

**Step 3: 提交更改**

```bash
git add eye-app/Source/eye_appApp.swift
git commit -m "feat: ensure config is passed to SessionManager"
```

---

## Task 8: 功能测试 - 图标显示

**Files:**
- Test: 手动测试

**Step 1: 构建并运行应用**

```bash
cd eye-app && xcodebuild -scheme eye-app -configuration Debug
open build/Debug/eye-app.app
```

**Step 2: 测试基本图标显示**

1. 启动应用，观察菜单栏图标
   - Expected: 白色眼睛图标 + 灰色圆形背景
2. 开始监测
   - Expected: 图标变为白色眼睛 + 绿色圆形背景
3. 暂停监测
   - Expected: 图标变为白色斜眼 + 橙色圆形背景

**Step 3: 测试全屏应用**

1. 打开 Safari 或其他应用，进入全屏模式
2. 观察菜单栏图标
   - Expected: 图标清晰可见（白色在深色背景上）
3. 切换不同状态，确认颜色变化
   - Expected: 背景颜色正确变化

**Step 4: 测试外观模式**

1. 切换到浅色模式
   - Expected: 图标清晰可见
2. 切换到深色模式
   - Expected: 图标清晰可见

**Step 5: 记录测试结果**

在测试报告中记录：
- [ ] 基本图标显示正常
- [ ] 全屏应用时图标可见
- [ ] 外观模式切换正常
- [ ] 状态颜色变化正确

---

## Task 9: 功能测试 - 通知控制

**Files:**
- Test: 手动测试

**Step 1: 测试总开关**

1. 打开设置 > 提醒设置
2. 关闭"启用疲劳提醒"
   - Expected: 所有子选项禁用（灰色）
3. 开启"启用疲劳提醒"
   - Expected: 子选项可操作

**Step 2: 测试弹窗提醒**

1. 只开启"弹窗提醒"，关闭"系统通知"
2. 等待疲劳提醒触发
   - Expected: 显示弹窗对话框，无系统通知

**Step 3: 测试系统通知**

1. 只开启"系统通知"，关闭"弹窗提醒"
2. 等待疲劳提醒触发
   - Expected: 发送系统通知，无弹窗

**Step 4: 测试两种通知都启用**

1. 同时开启"弹窗提醒"和"系统通知"
2. 等待疲劳提醒触发
   - Expected: 同时显示弹窗和系统通知

**Step 5: 测试两种通知都禁用**

1. 同时关闭"弹窗提醒"和"系统通知"
   - Expected: 显示黄色警告文字
2. 保存设置，等待疲劳提醒
   - Expected: 不触发任何通知

**Step 6: 测试配置持久化**

1. 修改通知设置
2. 关闭并重新打开应用
3. 检查设置是否保持
   - Expected: 设置与关闭前一致

**Step 7: 记录测试结果**

在测试报告中记录：
- [ ] 总开关控制正常
- [ ] 弹窗提醒控制正常
- [ ] 系统通知控制正常
- [ ] 两种通知组合正常
- [ ] 都禁用时警告显示
- [ ] 配置持久化正常

---

## Task 10: 代码审查和清理

**Files:**
- Review: 所有修改的文件

**Step 1: 检查代码质量**

验证:
- ✅ 方法命名清晰（getBackgroundColor, composite）
- ✅ 错误处理适当（SF Symbol 加载失败有 fallback）
- ✅ 日志输出有用
- ✅ 代码符合项目风格
- ✅ 无硬编码值（使用系统颜色）
- ✅ 无重复代码

**Step 2: 检查安全性**

- ✅ 无敏感信息泄露
- ✅ 配置检查正确
- ✅ 错误不会导致崩溃

**Step 3: 检查性能**

- 图标合成在主线程执行
- 图标尺寸合理（18x18）
- 无内存泄漏

**Step 4: 最终提交**

```bash
git add -A
git commit -m "feat: complete status bar icon and notification control improvements

- Add white icon with colored background for better visibility
- Add notification control switches (modal + system notification)
- Add NSImage extensions for tinting and compositing
- Update StatusBarController icon generation logic
- Add UI controls in settings panel
- Implement notification control based on config

Breaking changes: None
Backward compatible: Yes (new config fields have default values)"
```

---

## Task 11: 更新文档

**Files:**
- Update: `README.md`

**Step 1: 更新功能特点**

在 README.md 的功能特点部分添加：

```markdown
- **实时眨眼检测** - 使用 Apple Vision 框架进行高精度检测
- **摄像头实时预览** - 主面板小预览 + 独立窗口预览
- **智能暂停** - 未检测到人脸时自动暂停监测
- **疲劳提醒** - 60秒预热期后智能检测低眨眼频率并发出提醒
- **自定义通知** - 可选择弹窗提醒或系统通知，避免打扰
- **数据可视化** - 每分钟/小时/天的趋势图表
- **本地存储** - 所有数据仅存储在本地，保护隐私
- **开机启动** - 支持开机自动启动 (macOS 13.0+)
- **可自定义** - 调整检测灵敏度、提醒阈值和预览设置
- **菜单栏应用** - 轻量级，不占用 Dock 位置，全屏时也清晰可见
```

**Step 2: 更新设置说明**

在 README.md 的设置选项部分更新：

```markdown
#### 提醒设置
- 启用/禁用疲劳提醒
- 调整提醒阈值（5-30 次/分）
- 设置提醒间隔（5-60 分钟）
- 选择通知方式：
  - 弹窗提醒
  - 系统通知
  - 可自由组合或单独使用
```

**Step 3: 提交文档更新**

```bash
git add README.md
git commit -m "docs: update README with notification control features"
```

---

## 完成检查清单

实施完成后验证:

- [ ] 菜单栏图标在全屏应用时清晰可见
- [ ] 图标颜色正确反映状态（绿/黄/橙/红）
- [ ] 用户可以独立控制弹窗和系统通知
- [ ] 至少一种通知启用时正常触发
- [ ] 两种通知都禁用时显示警告
- [ ] 配置持久化正常
- [ ] 升级后旧配置自动迁移（使用默认值）
- [ ] 不影响核心功能
- [ ] 代码已提交到 Git
- [ ] 文档已更新

---

## 故障排除

### 问题: 图标显示为纯色方块

**检查:**
1. 确认 NSImage+Tint.swift 已正确添加到项目
2. 检查 SF Symbol 名称是否正确
3. 查看控制台是否有错误日志

### 问题: 通知设置不生效

**检查:**
1. 确认配置正确保存（检查 `~/Library/Application Support/EyeApp/config.json`）
2. 确认 SessionManager.config 已设置
3. 检查 AlertManager 和 StatusBarController 的配置引用

### 问题: 图标在某些状态下颜色不对

**检查:**
1. 检查 `getBackgroundColor()` 方法的逻辑
2. 确认 `fatigueStatus` 属性正确更新
3. 检查 `StatusBarStatus` 的状态映射

### 问题: 两种通知都禁用时仍收到提醒

**检查:**
1. 确认 `checkFatigueAlert()` 方法中的配置检查
2. 确认配置文件中的字段值正确
3. 检查是否有其他地方直接调用通知方法

---

## 代码变更总结

**新增文件:** 1 个
- `eye-app/Source/Extensions/NSImage+Tint.swift` (~50 行)

**修改文件:** 6 个
- `eye-app/Source/Models/AppConfig.swift` (+10 行)
- `eye-app/Source/UI/StatusBarController.swift` (+40 行, -20 行)
- `eye-app/Source/UI/SettingsPanelView.swift` (+30 行)
- `eye-app/Source/Core/AlertManager.swift` (-5 行)
- `eye-app/Source/Core/SessionManager.swift` (+10 行)
- `eye-app/Source/eye_appApp.swift` (+2 行)

**总计:** 约 +120 行新增代码，-25 行删除代码

**影响范围:**
- 菜单栏图标显示
- 提醒设置界面
- 通知控制逻辑

**风险等级:** 中等
- 图标生成逻辑变化，需要测试各种状态
- 新增配置字段，需要测试迁移
- 通知逻辑变化，需要全面测试
