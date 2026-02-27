# 开机启动自动注册功能实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在应用启动时自动注册开机启动服务,使其出现在 macOS "系统设置 > 登录项与扩展"中。

**Architecture:** 在 AppDelegate 的 applicationDidFinishLaunching 方法中添加 setupLaunchAtLogin() 调用,根据配置自动注册或注销 SMAppService。

**Tech Stack:** Swift, SwiftUI, ServiceManagement framework (SMAppService), macOS 13.0+ API

---

## Task 1: 添加启动时注册逻辑

**Files:**
- Modify: `eye-app/Source/eye_appApp.swift:50-68` (applicationDidFinishLaunching 方法)

**Step 1: 在 applicationDidFinishLaunching 中添加调用**

在 `eye_appApp.swift` 文件的 `AppDelegate` 类中,找到 `applicationDidFinishLaunching` 方法。

在第 58 行 `setupSessionManager()` 之后,添加一行:

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // 设置为菜单栏应用(不显示 Dock 图标)
    NSApp.setActivationPolicy(.accessory)

    // 初始化服务
    setupServices()

    // 创建 SessionManager
    setupSessionManager()

    // 🆕 新增: 根据配置注册开机启动
    setupLaunchAtLogin()

    // 创建状态栏控制器
    setupStatusBar()

    // 设置自动保存
    setupAutoSave()

    // 请求摄像头权限并启动
    requestCameraPermission()
}
```

**Step 2: 提交更改**

```bash
git add eye-app/Source/eye_appApp.swift
git commit -m "feat: add setupLaunchAtLogin call in applicationDidFinishLaunching"
```

---

## Task 2: 实现 setupLaunchAtLogin 方法

**Files:**
- Modify: `eye-app/Source/eye_appApp.swift:280-289` (在 saveCurrentData 方法后添加)

**Step 1: 添加 setupLaunchAtLogin 方法**

在 `eye_appApp.swift` 文件的 `AppDelegate` 类中,在 `saveCurrentData()` 方法之后添加新方法:

```swift
// MARK: - Launch at Login

/// 根据配置注册或注销开机启动
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

**Step 2: 验证代码编译**

```bash
cd eye-app && xcodebuild -scheme eye-app -configuration Debug clean build
```

Expected: BUILD SUCCEEDED

**Step 3: 提交更改**

```bash
git add eye-app/Source/eye_appApp.swift
git commit -m "feat: implement setupLaunchAtLogin method with SMAppService"
```

---

## Task 3: 功能测试 - 验证注册成功

**Files:**
- Test: 手动测试

**Step 1: 构建并运行应用**

```bash
cd eye-app && xcodebuild -scheme eye-app -configuration Debug
open build/Debug/eye-app.app
```

**Step 2: 验证系统登录项**

1. 打开"系统设置" > "通用" > "登录项与扩展"
2. 检查列表中是否出现 "eye-app"
3. 确认开关状态为"开启"

Expected: eye-app 出现在登录项列表中

**Step 3: 查看控制台日志**

在 Xcode 控制台或 Console.app 中查找:

```
✅ 开机启动已注册
```

Expected: 看到注册成功的日志

---

## Task 4: 功能测试 - 验证配置切换

**Files:**
- Test: 手动测试

**Step 1: 打开应用设置**

1. 点击菜单栏图标
2. 选择"设置..."
3. 切换到"隐私"标签页

**Step 2: 关闭开机启动**

1. 找到"开机自动启动"开关
2. 切换为关闭状态
3. 打开"系统设置" > "登录项与扩展"
4. 验证 eye-app 已从列表中消失

Expected: 登录项列表中不再有 eye-app

**Step 3: 重新开启开机启动**

1. 再次切换"开机自动启动"开关为开启
2. 验证系统设置中重新出现 eye-app

Expected: eye-app 重新出现在登录项列表中

---

## Task 5: 功能测试 - 验证持久化

**Files:**
- Test: 手动测试

**Step 1: 关闭应用**

```bash
killall eye-app
```

**Step 2: 重新启动应用**

```bash
open build/Debug/eye-app.app
```

**Step 3: 验证配置持久化**

1. 检查控制台日志,应该看到 "✅ 开机启动已注册"
2. 打开"系统设置" > "登录项与扩展"
3. 确认 eye-app 仍然在列表中

Expected: 重启后配置保持不变

---

## Task 6: 功能测试 - 验证开机启动

**Files:**
- Test: 手动测试

**Step 1: 确保开机启动已启用**

在设置中确认"开机自动启动"开关为开启状态。

**Step 2: 重启 macOS**

```bash
sudo reboot
```

或通过苹果菜单选择"重新启动"。

**Step 3: 验证自动启动**

1. 登录后等待几秒
2. 检查菜单栏是否出现 eye-app 图标
3. 检查应用是否在运行

Expected: eye-app 自动启动并出现在菜单栏

---

## Task 7: 边界测试 - 验证错误处理

**Files:**
- Test: 手动测试

**Step 1: 测试 macOS 13.0 以下兼容性(如果可用)**

如果在 macOS 13.0 以下环境:

1. 启动应用
2. 查看控制台日志

Expected: 看到警告 "⚠️ 开机启动需要 macOS 13.0 或更高版本"

**Step 2: 测试配置文件损坏场景**

1. 关闭应用
2. 删除配置文件: `~/Library/Application Support/EyeApp/config.json`
3. 重新启动应用
4. 检查是否使用默认配置(launchAtLogin = true)
5. 验证系统登录项中出现 eye-app

Expected: 使用默认配置并成功注册

---

## Task 8: 代码审查和清理

**Files:**
- Review: `eye-app/Source/eye_appApp.swift`

**Step 1: 检查代码质量**

验证:
- ✅ 方法命名清晰(setupLaunchAtLogin)
- ✅ 错误处理适当
- ✅ 日志输出有用
- ✅ 代码符合项目风格
- ✅ 无硬编码值
- ✅ 无重复代码

**Step 2: 检查安全性**

- ✅ 无敏感信息泄露
- ✅ 权限检查正确
- ✅ 错误不会导致崩溃

**Step 3: 最终提交**

```bash
git add -A
git commit -m "feat: complete launch at login auto-registration feature

- Add setupLaunchAtLogin method to AppDelegate
- Auto-register on app launch based on config
- Support macOS 13.0+ with SMAppService API
- Add error handling and logging
- Test and verify functionality"
```

---

## Task 9: 更新文档

**Files:**
- Update: `README.md` (如果存在)

**Step 1: 添加功能说明**

在 README 的功能列表中添加:

```markdown
- 🔐 **开机启动** - 支持开机自动启动(macOS 13.0+)
```

**Step 2: 添加系统要求**

```markdown
## 系统要求

- macOS 13.0 或更高版本(完整功能支持)
- macOS 12.0 及以下(核心功能可用,开机启动不可用)
```

**Step 3: 提交文档更新**

```bash
git add README.md
git commit -m "docs: add launch at login feature to README"
```

---

## 完成检查清单

实施完成后验证:

- [ ] 应用启动时自动注册开机启动(如果配置为 true)
- [ ] 应用启动时自动注销开机启动(如果配置为 false)
- [ ] 用户切换设置开关后,系统登录项立即更新
- [ ] 重启应用后配置持久化
- [ ] 重启 macOS 后应用自动启动(如果配置为 true)
- [ ] macOS 13.0 以下版本优雅降级
- [ ] 错误处理适当,不影响应用启动
- [ ] 代码已提交到 Git
- [ ] 文档已更新

---

## 故障排除

### 问题: 应用未出现在登录项中

**检查:**
1. 确认 macOS 版本 >= 13.0
2. 查看控制台日志是否有错误
3. 检查配置文件中 `launchAtLogin` 是否为 `true`
4. 尝试手动切换设置中的开关

### 问题: 应用未自动启动

**检查:**
1. 确认登录项列表中 eye-app 开关为"开启"
2. 检查应用是否有崩溃日志
3. 验证应用路径未改变(开发期间路径可能变化)

### 问题: 设置切换后登录项未更新

**检查:**
1. 查看 `SettingsViewModel.setLaunchAtLogin` 方法是否正确实现
2. 检查 SMAppService API 调用是否成功
3. 查看控制台日志

---

## 代码变更总结

**修改文件:** 1 个
- `eye-app/Source/eye_appApp.swift`

**新增代码:** ~25 行
**修改代码:** 1 行(添加方法调用)

**影响范围:**
- 应用启动流程
- 设置界面(已存在,无需修改)

**风险等级:** 低
- 不影响核心功能
- 错误处理完善
- 可快速回滚
