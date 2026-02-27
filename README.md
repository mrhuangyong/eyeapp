# 👁️ EyeApp - 眨眼检测与疲劳提醒

一款 macOS 原生菜单栏应用，通过摄像头实时检测眨眼频率，用于健康监测和疲劳提醒。

## ✨ 功能特点

- 📹 **实时眨眼检测** - 使用 Apple Vision 框架进行高精度检测
- 📊 **数据可视化** - 每分钟/小时/天的趋势图表
- 🔔 **疲劳提醒** - 智能检测低眨眼频率并发出提醒
- 💾 **本地存储** - 所有数据仅存储在本地，保护隐私
- 🎯 **可自定义** - 调整检测灵敏度和提醒阈值
- 🖥️ **菜单栏应用** - 轻量级，不占用 Dock 位置

## 📋 系统要求

- macOS 14.0 (Sonoma) 或更高版本
- 带有摄像头的 Mac 设备
- 摄像头使用权限

## 🚀 安装

### 从源码构建

1. 克隆仓库
```bash
git clone https://github.com/your-username/eye-app.git
cd eye-app
```

2. 打开 Xcode 项目
```bash
open eye-app.xcodeproj
```

3. 构建并运行
- 选择 "My Mac" 作为目标设备
- 按 `Cmd + R` 运行应用

### 下载预编译版本

从 [Releases](https://github.com/your-username/eye-app/releases) 页面下载最新的 `.app` 文件。

## 📖 使用说明

### 首次启动

1. 启动应用后，系统会请求摄像头权限
2. 授权后，点击菜单栏的眼睛图标
3. 监测会自动开始

### 菜单栏图标状态

| 图标颜色 | 状态 | 眨眼频率 |
|---------|------|---------|
| 🟢 绿色 | 正常 | > 15 次/分 |
| 🟡 黄色 | 轻度疲劳 | 10-15 次/分 |
| 🟠 橙色 | 中度疲劳 | 5-10 次/分 |
| 🔴 红色 | 严重疲劳 | < 5 次/分 |

### 主面板功能

点击菜单栏图标打开主面板：

- **实时眨眼频率** - 当前每分钟眨眼次数
- **今日总次数** - 今日累计眨眼次数
- **趋势图表** - 最近 60 分钟的眨眼趋势
- **历史统计** - 今天/本周/本月/全部统计数据

### 设置选项

通过菜单栏 → 设置 打开设置面板：

#### 提醒设置
- 启用/禁用疲劳提醒
- 调整提醒阈值（5-30 次/分）
- 设置提醒间隔（5-60 分钟）
- 启用/禁用声音提醒

#### 检测设置
- 检测灵敏度（低/中/高）
- 数据保留期限（7/14/30/90 天）

#### 隐私设置
- 摄像头权限状态
- 开机自启动
- 数据导出和清除

## 🏗️ 技术架构

### 技术栈

| 组件 | 技术 |
|------|------|
| 语言 | Swift 5.9 |
| UI 框架 | SwiftUI |
| 人脸检测 | Vision Framework |
| 摄像头 | AVFoundation |
| 数据存储 | JSON + SwiftData |
| 图表 | Swift Charts |

### 核心算法

**EAR (Eye Aspect Ratio)**

眨眼检测使用 EAR 算法计算眼睛纵横比：

```
EAR = (|p2-p6| + |p3-p5|) / (2 * |p1-p4|)
```

- EAR > 0.2: 眼睛睁开
- EAR < 0.2: 眼睛闭合（眨眼）

### 项目结构

```
eye-app/
├── Source/
│   ├── Core/
│   │   ├── BlinkDetector.swift      # EAR 算法
│   │   ├── SessionManager.swift     # 会话管理
│   │   ├── StatsEngine.swift        # 统计引擎
│   │   └── AlertManager.swift       # 提醒管理
│   ├── Services/
│   │   ├── CameraManager.swift      # 摄像头管理
│   │   ├── VisionService.swift      # Vision 服务
│   │   ├── DataStorage.swift        # 数据存储
│   │   └── AutoSaveService.swift    # 自动保存
│   ├── Models/
│   │   ├── BlinkEvent.swift         # 眨眼事件
│   │   ├── MinuteStats.swift        # 分钟统计
│   │   ├── FatigueStatus.swift      # 疲劳状态
│   │   ├── AppConfig.swift          # 应用配置
│   │   └── DailyBlinkData.swift     # 每日数据
│   └── UI/
│       ├── StatusBarController.swift # 状态栏
│       ├── MainPanelView.swift       # 主面板
│       ├── SettingsPanelView.swift   # 设置面板
│       └── ErrorView.swift           # 错误视图
├── Tests/
│   ├── Core/
│   ├── Services/
│   └── Models/
└── Assets.xcassets/
```

## 🔬 测试

运行测试套件：

```bash
xcodebuild test -scheme eye-app -destination 'platform=macOS'
```

### 测试覆盖率目标

| 模块 | 目标覆盖率 |
|------|-----------|
| BlinkDetector | 95% |
| StatsEngine | 90% |
| AlertManager | 90% |
| DataStorage | 85% |

## 🤝 贡献

欢迎贡献！请查看 [CONTRIBUTING.md](CONTRIBUTING.md) 了解详情。

### 开发环境设置

1. 安装 Xcode 15.0+
2. 安装 Xcode Command Line Tools
```bash
xcode-select --install
```

### 代码风格

- 遵循 [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- 使用 SwiftLint 进行代码检查
- 所有公共 API 需要文档注释

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 🙏 致谢

- Apple Vision Framework - 提供强大的人脸检测能力
- [Swift Charts](https://developer.apple.com/documentation/charts) - 数据可视化

## 📮 联系方式

- 问题反馈: [GitHub Issues](https://github.com/your-username/eye-app/issues)
- 功能建议: [GitHub Discussions](https://github.com/your-username/eye-app/discussions)

---

**注意**: 本应用仅供健康参考，不构成医疗建议。如有眼部不适，请咨询专业医生。
