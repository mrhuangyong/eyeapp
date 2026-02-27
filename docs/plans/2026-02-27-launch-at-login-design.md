# 开机启动自动注册功能设计

**日期:** 2026-02-27
**类型:** 功能增强
**复杂度:** 低

## 问题背景

用户报告:虽然应用设置中有"开机自动启动"开关,但在 macOS "系统设置 > 登录项与扩展"中找不到该应用。

### 根本原因

1. **配置存在但未使用** - `AppConfig.launchAtLogin` 字段已存在,但应用启动时未根据配置注册 ServiceManagement
2. **仅在切换时注册** - 只有用户手动切换开关时才调用 `setLaunchAtLogin` 方法
3. **结果** - 即使配置为 `true`,应用也不会出现在系统登录项中

## 解决方案

在应用启动时自动检查配置并注册/注销开机启动服务。

### 架构设计

**修改位置:** `eye_appApp.swift` - `AppDelegate` 类

**实现策略:** 在 `applicationDidFinishLaunching` 方法中,加载配置后立即检查并注册开机启动。

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // 现有代码...
    NSApp.setActivationPolicy(.accessory)
    setupServices()

    // 🆕 新增: 根据配置注册开机启动
    setupLaunchAtLogin()

    setupSessionManager()
    setupStatusBar()
    setupAutoSave()
    requestCameraPermission()
}
```

### 核心实现

新增方法 `setupLaunchAtLogin()`:

```swift
// MARK: - Launch at Login

private func setupLaunchAtLogin() {
    #if os(macOS)
    if #available(macOS 13.0, *) {
        let service = SMAppService.mainApp

        if config.launchAtLogin {
            // 注册开机启动
            do {
                try service.register()
                print("✅ 开机启动已注册")
            } catch {
                print("❌ 注册开机启动失败: \(error.localizedDescription)")
            }
        } else {
            // 确保未注册(处理用户之前关闭的情况)
            do {
                try service.unregister()
                print("ℹ️ 开机启动已注销")
            } catch {
                // 忽略注销失败(可能本来就没注册)
            }
        }
    } else {
        // macOS 13 以下的兼容性提示
        print("⚠️ 开机启动需要 macOS 13.0 或更高版本")
    }
    #endif
}
```

**关键设计点:**

1. **条件编译** - 使用 `#if os(macOS)` 确保跨平台兼容
2. **版本检查** - 使用 `@available(macOS 13.0, *)`
3. **双向同步** - 既注册也注销,确保与配置完全一致
4. **错误处理** - 注册失败打印日志,注销失败静默处理
5. **用户反馈** - 控制台日志便于调试

### 数据流

**启动流程:**

```
AppDelegate.applicationDidFinishLaunching
  ↓
dataStorage.loadConfig() → 读取配置
  ↓
config.launchAtLogin (true/false)
  ↓
setupLaunchAtLogin() → 注册/注销 ServiceManagement
  ↓
SMAppService.mainApp.register()/unregister()
  ↓
macOS 系统登录项更新
```

**状态同步:**

```
用户修改设置:
  ↓
Toggle 绑定到 $viewModel.config.launchAtLogin
  ↓
onChange 触发 viewModel.setLaunchAtLogin(newValue)
  ↓
调用 SMAppService.mainApp.register()/unregister()
  ↓
配置保存到磁盘 (通过 AutoSaveService)
  ↓
下次启动时,setupLaunchAtLogin() 读取最新配置
```

### 错误处理

1. **注册失败**
   - 原因: 权限问题、系统策略限制
   - 处理: 打印错误日志,不阻塞应用启动
   - 用户提示: 设置界面的开关状态仍然保存,用户可重试

2. **注销失败**
   - 原因: 本来就没有注册
   - 处理: 静默忽略(不打印错误)

3. **macOS 版本过低**
   - 条件: macOS 13.0 以下
   - 处理: 打印警告,功能不启用

4. **配置文件损坏**
   - 原因: 配置文件丢失或格式错误
   - 处理: `dataStorage.loadConfig() ?? .default` 已有默认值处理
   - 结果: 使用默认值(launchAtLogin = true)

### 实现清单

**代码修改:**

- 文件: `eye-app/Source/eye_appApp.swift`
- 位置: `AppDelegate` 类
- 新增: `setupLaunchAtLogin()` 方法(约20行代码)
- 修改: `applicationDidFinishLaunching` 添加一行调用

**测试验证:**

1. 启动应用,检查"系统设置 > 登录项与扩展"
2. 切换设置中的开关,验证实时生效
3. 重启应用,验证配置持久化
4. 重启 macOS,验证应用自动启动

**兼容性:**

- macOS 13.0+: 完全支持
- macOS 13.0以下: 静默降级(不影响应用运行)

**不需要修改:**

- ❌ Info.plist - SMAppService 不需要特殊配置
- ❌ Entitlements - 无需额外权限
- ❌ 设置界面 - 已存在且工作正常

## 影响范围

- **修改文件:** 1个 (`eye_appApp.swift`)
- **代码量:** 约25行新增代码,1行修改
- **风险等级:** 低(仅影响启动流程,不涉及核心功能)

## 成功标准

1. ✅ 应用启动后,如果配置为 `true`,出现在"系统设置 > 登录项与扩展"中
2. ✅ 用户切换开关后,系统登录项立即更新
3. ✅ 重启 macOS 后,应用自动启动(如果配置为 `true`)
4. ✅ 不影响应用其他功能
5. ✅ 兼容 macOS 13.0 以下版本

## 未来增强(可选)

- 在设置界面显示当前注册状态
- 为 macOS 13.0 以下版本提供替代方案(如使用 LaunchAgent)
- 添加用户引导,首次启动时询问是否开机启动
