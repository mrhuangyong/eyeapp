# 菜单栏图标和通知控制改进设计

**日期:** 2026-02-27
**类型:** 功能增强 + 用户体验改进
**复杂度:** 中等

## 问题背景

### 问题 1: 菜单栏图标在全屏时不可见
用户报告：当前菜单栏图标是黑色，当有其他应用全屏时看不到图标。

**根本原因:**
- 当前使用模板图像（`isTemplate = true`）+ `contentTintColor` 设置颜色
- 全屏应用时菜单栏变暗，黑色图标在深色背景上不可见

### 问题 2: 无法控制通知方式
用户需求：避免打扰，希望可以控制通知方式。

**当前问题:**
- 疲劳提醒时同时触发弹窗（NSAlert）和系统通知（UNUserNotificationCenter）
- 用户无法选择通知方式
- 没有开关可以关闭某种通知

---

## 解决方案

### 功能 1: 菜单栏图标改进

**方案:** 白色图标 + 彩色背景圆圈

**设计理念:**
- 图标始终显示为白色，确保在任何背景下都清晰可见
- 通过背景颜色表示状态（绿色=正常，黄色=疲劳，红色=严重疲劳）
- 视觉效果类似现代应用的状态指示器

**实现方式:**
- 移除当前的 `contentTintColor` 逻辑
- 创建复合图像：彩色圆形背景 + 白色 SF Symbol 图标
- 使用 `NSImage` 的图像合成功能

### 功能 2: 通知开关

**方案:** 一个总开关 + 通知方式子选项

**设计理念:**
- 保持现有的"启用疲劳提醒"总开关
- 在其下添加两个子选项：弹窗提醒、系统通知
- 用户可以自由组合通知方式
- 至少需要启用一种通知方式（或给出警告）

---

## 架构设计

### 功能 1: 菜单栏图标

**修改文件:**
- `StatusBarController.swift`

**关键方法:**

```swift
// 更新图标（主方法）
private func updateIcon() {
    if let button = statusItem.button {
        let compositeImage = createCompositeIcon()
        button.image = compositeImage
        button.toolTip = status.tooltip
    }
}

// 创建复合图标
private func createCompositeIcon() -> NSImage? {
    let iconSize = NSSize(width: 18, height: 18)

    // 创建图像
    let image = NSImage(size: iconSize)
    image.lockFocus()

    // 1. 绘制彩色背景圆圈
    let backgroundColor = getBackgroundColor()
    let circlePath = NSBezierPath(ovalIn: NSRect(origin: .zero, size: iconSize))
    backgroundColor.setFill()
    circlePath.fill()

    // 2. 绘制白色图标
    if let symbolImage = NSImage(systemSymbolName: status.icon, accessibilityDescription: "EyeApp") {
        let symbolSize = NSSize(width: 14, height: 14)
        let symbolOrigin = NSPoint(
            x: (iconSize.width - symbolSize.width) / 2,
            y: (iconSize.height - symbolSize.height) / 2
        )

        // 配置为白色
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let configuredImage = symbolImage.withSymbolConfiguration(config) ?? symbolImage

        // 设置为白色（使用模板图像）
        let whiteImage = configuredImage.tinted(with: .white)
        whiteImage.draw(at: symbolOrigin, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    image.unlockFocus()
    return image
}

// 获取背景颜色
private func getBackgroundColor() -> NSColor {
    // 根据疲劳状态返回对应颜色
    if let fatigueStatus = fatigueStatus {
        return NSColor(fatigueStatus.color)
    }

    // 根据系统状态返回颜色
    switch status {
    case .ready: return .systemGray
    case .running: return .systemGreen
    case .paused: return .systemOrange
    case .noFace: return .systemYellow
    case .noPermission, .noCamera: return .systemRed
    case .error: return .systemRed
    }
}
```

**图标状态映射:**

| 状态 | 图标 SF Symbol | 背景色 | 十六进制 | 说明 |
|------|----------------|--------|----------|------|
| 准备就绪 | `eye` | 灰色 | #8E8E93 | 半透明效果 |
| 监测中 | `eye.fill` | 绿色 | #34C759 | 正常状态 |
| 已暂停 | `eye.slash` | 橙色 | #FF9500 | 暂停状态 |
| 未检测到人脸 | `person.crop.circle.badge.questionmark` | 黄色 | #FFCC00 | 警告 |
| 无权限/无摄像头 | `eye.slash.fill` | 红色 | #FF3B30 | 错误 |

**疲劳状态背景色:**

| 疲劳等级 | 背景色 | 十六进制 | 说明 |
|---------|--------|----------|------|
| 正常 | 绿色 | #34C759 | 眨眼率 > 15 次/分 |
| 轻度疲劳 | 黄色 | #FFCC00 | 眨眼率 10-15 次/分 |
| 中度疲劳 | 橙色 | #FF9500 | 眨眼率 5-10 次/分 |
| 严重疲劳 | 红色 | #FF3B30 | 眨眼率 < 5 次/分 |

**视觉效果:**
- 图标尺寸：18x18 pt（标准状态栏图标大小）
- 背景圆圈：18x18 pt
- 白色图标：14x14 pt（居中）
- 圆角：完全圆形

### 功能 2: 通知开关

**修改文件:**
- `AppConfig.swift` - 添加配置字段
- `SettingsPanelView.swift` - 添加 UI 控件
- `AlertManager.swift` - 通知逻辑控制
- `StatusBarController.swift` - 弹窗逻辑控制

**新增配置字段:**

```swift
// AppConfig.swift
struct AppConfig: Codable, Equatable {
    // ... 现有字段 ...

    /// 是否启用弹窗提醒
    var alertModalEnabled: Bool = true

    /// 是否启用系统通知
    var alertNotificationEnabled: Bool = true

    // CodingKeys 枚举需要添加新字段
    enum CodingKeys: String, CodingKey {
        // ... 现有键 ...
        case alertModalEnabled
        case alertNotificationEnabled
    }
}
```

**UI 布局:**

```swift
// SettingsPanelView.swift - AlertSettingsView
Section("🔔 提醒设置") {
    Toggle("启用疲劳提醒", isOn: $viewModel.config.alertEnabled)
        .help("当眨眼频率过低时发送提醒")

    VStack(alignment: .leading, spacing: 8) {
        Text("提醒阈值: \(viewModel.config.alertThreshold) 次/分")
            .font(.subheadline)

        Slider(value: $viewModel.config.alertThresholdDouble, in: 5...30, step: 1)

        Text("低于此频率时触发提醒")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .disabled(!viewModel.config.alertEnabled)

    VStack(alignment: .leading, spacing: 8) {
        Text("提醒间隔: \(viewModel.config.alertInterval) 分钟")
            .font(.subheadline)

        Slider(value: $viewModel.config.alertIntervalDouble, in: 5...60, step: 5)

        Text("两次提醒之间的最小间隔")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .disabled(!viewModel.config.alertEnabled)

    Toggle("启用声音提醒", isOn: $viewModel.config.soundEnabled)
        .disabled(!viewModel.config.alertEnabled)

    // 🆕 新增：通知方式
    VStack(alignment: .leading, spacing: 12) {
        Text("通知方式")
            .font(.subheadline)
            .fontWeight(.medium)

        Toggle("弹窗提醒", isOn: $viewModel.config.alertModalEnabled)
            .help("显示模态对话框提醒")

        Toggle("系统通知", isOn: $viewModel.config.alertNotificationEnabled)
            .help("发送系统通知到通知中心")

        if !viewModel.config.alertModalEnabled && !viewModel.config.alertNotificationEnabled {
            Text("⚠️ 建议至少启用一种通知方式")
                .font(.caption)
                .foregroundColor(.orange)
        } else {
            Text("至少选择一种通知方式")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .disabled(!viewModel.config.alertEnabled)
}
```

**通知逻辑控制:**

```swift
// AlertManager.swift
func triggerAlert() {
    guard shouldTriggerAlert() else { return }

    let status = checkFatigueStatus()
    triggerAlertSilent()

    // 通知回调（让 StatusBarController 决定是否显示弹窗）
    onAlertTriggered?(status)
}

// StatusBarController.swift
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

// AlertManager.swift
func sendNotification(status: FatigueStatus) {
    // 检查配置：是否启用系统通知
    // 注意：这个检查需要在调用方进行，因为 AlertManager 不知道完整的 AppConfig
    // 或者我们可以将配置传递给 AlertManager

    let content = UNMutableNotificationContent()
    content.title = "👁️ EyeApp - 疲劳提醒"
    content.body = "\(status.recommendation)\n当前眨眼频率: \(Int(status.blinkRate)) 次/分钟"
    content.sound = .default
    content.badge = 1

    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
    )

    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Notification error: \(error)")
        }
    }
}
```

**修改后的调用流程:**

```swift
// SessionManager.swift 或调用方
private func checkFatigueAlert() {
    if alertManager.shouldTriggerAlert() {
        let status = alertManager.checkFatigueStatus()

        // 根据配置决定发送哪些通知
        if config.alertModalEnabled {
            // 弹窗通过回调触发
            alertManager.onAlertTriggered?(status)
        }

        if config.alertNotificationEnabled {
            // 系统通知直接发送
            alertManager.sendNotification(status: status)
        }

        alertManager.triggerAlertSilent()
    }
}
```

---

## 数据流和状态管理

### 功能 1: 图标更新流程

```
状态变化:
SessionManager → StatusBarController.updateStatus(_ newStatus)
  ↓
updateIcon()
  ↓
createCompositeIcon()
  ├─ getBackgroundColor() (根据状态或疲劳等级)
  ├─ 绘制彩色圆形背景
  ├─ 加载白色 SF Symbol
  └─ 合成图像
  ↓
button.image = compositeImage

眨眼率更新:
StatsEngine → StatusBarController.updateBlinkRate(_ rate, status)
  ↓
根据 status.level 获取背景色
  ↓
updateIcon() (使用新的背景色)
```

### 功能 2: 通知控制流程

```
配置保存:
用户修改 Toggle
  ↓
绑定到 $viewModel.config.alertModalEnabled / alertNotificationEnabled
  ↓
onChange 验证（可选：至少一种启用）
  ↓
viewModel.saveConfig()
  ↓
dataStorage.saveConfig(config)
  ↓
持久化到 JSON 文件

通知触发:
眨眼频率过低
  ↓
SessionManager.checkFatigueAlert()
  ↓
alertManager.shouldTriggerAlert() (检查总开关)
  ↓
if config.alertModalEnabled:
    alertManager.onAlertTriggered?(status)
    → StatusBarController.showFatigueAlert(status)
  ↓
if config.alertNotificationEnabled:
    alertManager.sendNotification(status: status)
```

---

## 错误处理和边界情况

### 功能 1: 图标生成

**1. SF Symbol 加载失败**
```swift
guard let symbolImage = NSImage(systemSymbolName: status.icon, accessibilityDescription: "EyeApp") else {
    // Fallback: 使用基本的眼睛图标
    let fallback = NSImage(systemSymbolName: "eye", accessibilityDescription: "EyeApp")
    // 继续处理...
}
```

**2. 图像合成失败**
```swift
guard let compositeImage = createCompositeIcon() else {
    // 降级方案：使用纯模板图像
    let fallbackImage = NSImage(systemSymbolName: status.icon, accessibilityDescription: "EyeApp")
    fallbackImage?.isTemplate = true
    button.image = fallbackImage
    return
}
```

**3. 状态栏按钮不存在**
```swift
guard let button = statusItem.button else {
    print("Warning: Status bar button is nil")
    return
}
```

### 功能 2: 通知控制

**1. 两种通知方式都禁用**
```swift
// UI 层面：显示警告
if !config.alertModalEnabled && !config.alertNotificationEnabled {
    // 显示黄色警告文字
    Text("⚠️ 建议至少启用一种通知方式")
}

// 运行时层面：不触发任何通知
func shouldTriggerAlert() -> Bool {
    guard config.enabled else { return false }

    // 如果两种通知都禁用，不触发提醒
    guard config.alertModalEnabled || config.alertNotificationEnabled else {
        return false
    }

    // ... 其他检查 ...
}
```

**2. 配置迁移**
```swift
// 使用 Codable 默认值自动处理
var alertModalEnabled: Bool = true  // 旧版本配置没有这个字段时使用默认值
var alertNotificationEnabled: Bool = true
```

**3. 通知权限被拒绝**
```swift
func checkNotificationPermission() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
        DispatchQueue.main.async {
            if settings.authorizationStatus == .denied {
                // 在设置界面显示警告
                self.showNotificationPermissionWarning = true
            }
        }
    }
}

// UI 中显示
if showNotificationPermissionWarning {
    HStack {
        Image(systemName: "exclamationmark.triangle")
        Text("系统通知权限未授予")
        Button("打开系统设置") {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    .foregroundColor(.orange)
}
```

---

## 测试策略

### 功能 1: 菜单栏图标测试

**手动测试清单:**

1. **基本显示**
   - [ ] 启动应用，图标显示为白色眼睛 + 灰色圆形背景
   - [ ] 开始监测，图标变为白色眼睛 + 绿色圆形背景
   - [ ] 暂停监测，图标变为白色斜眼 + 橙色圆形背景

2. **全屏应用**
   - [ ] 打开全屏应用（如 Safari 全屏）
   - [ ] 确认菜单栏图标清晰可见（白色在深色背景上）
   - [ ] 切换不同状态，确认背景颜色变化

3. **外观模式**
   - [ ] 浅色模式：图标清晰可见
   - [ ] 深色模式：图标清晰可见
   - [ ] 自动模式：跟随系统切换

4. **疲劳状态**
   - [ ] 正常状态：绿色背景
   - [ ] 轻度疲劳：黄色背景
   - [ ] 中度疲劳：橙色背景
   - [ ] 严重疲劳：红色背景

5. **分辨率**
   - [ ] Retina 显示器：图标清晰
   - [ ] 非 Retina 显示器：图标清晰

### 功能 2: 通知开关测试

**手动测试清单:**

1. **总开关**
   - [ ] 关闭总开关，所有子选项禁用
   - [ ] 开启总开关，子选项可操作

2. **单独通知**
   - [ ] 只开启弹窗：疲劳时显示弹窗，无系统通知
   - [ ] 只开启系统通知：疲劳时发送通知，无弹窗
   - [ ] 两种都开启：两种通知都触发

3. **边界情况**
   - [ ] 关闭两种通知：显示警告文字
   - [ ] 保存配置：配置持久化
   - [ ] 重启应用：配置保持

4. **权限**
   - [ ] 拒绝通知权限：显示警告
   - [ ] 跳转系统设置：正确跳转
   - [ ] 授权后：通知正常

---

## 实现清单

**代码修改:**

1. `StatusBarController.swift`
   - 修改 `updateIcon()` 方法
   - 添加 `createCompositeIcon()` 方法
   - 添加 `getBackgroundColor()` 方法
   - 修改 `updateIconColor()` 逻辑

2. `AppConfig.swift`
   - 添加 `alertModalEnabled` 字段
   - 添加 `alertNotificationEnabled` 字段
   - 更新 `CodingKeys` 枚举
   - 更新 `encode()` 方法

3. `SettingsPanelView.swift`
   - 在 `AlertSettingsView` 中添加通知方式选项
   - 添加配置验证逻辑

4. `AlertManager.swift`（可选）
   - 添加通知方式检查方法
   - 或在调用方检查配置

5. `StatusBarController.swift`
   - 修改 `showFatigueAlert()` 添加配置检查

**代码量估算:**
- StatusBarController.swift: +80 行
- AppConfig.swift: +10 行
- SettingsPanelView.swift: +30 行
- 总计: ~120 行新增代码

---

## 影响范围

**修改文件:** 3-4 个
**风险等级:** 中等
- 图标生成逻辑变化，可能影响用户体验
- 新增配置字段，需要迁移测试
- 通知逻辑变化，需要全面测试

**不影响:**
- 核心监测逻辑
- 数据存储格式（向后兼容）
- 其他 UI 组件

---

## 成功标准

1. ✅ 菜单栏图标在全屏应用时清晰可见
2. ✅ 图标颜色正确反映状态
3. ✅ 用户可以独立控制弹窗和系统通知
4. ✅ 配置持久化正常
5. ✅ 升级后旧配置自动迁移
6. ✅ 无权限时给出清晰提示
7. ✅ 不影响核心功能

---

## 未来增强（可选）

- 自定义图标颜色（允许用户选择背景色）
- 图标动画效果（状态变化时的过渡动画）
- 更多通知方式（邮件、短信等）
- 通知历史记录
- 静音时段（特定时间不发送通知）
