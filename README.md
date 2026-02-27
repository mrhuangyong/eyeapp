# EyeApp - 眨眼检测与疲劳提醒

一款 macOS 原生菜单栏应用，通过摄像头实时检测眨眼频率，帮助预防用眼疲劳。

## 功能特点

- **实时眨眼检测** - 使用 Apple Vision 框架进行高精度检测
- **摄像头实时预览** - 主面板小预览 + 独立窗口预览
- **智能暂停** - 未检测到人脸时自动暂停监测
- **疲劳提醒** - 60秒预热期后智能检测低眨眼频率并发出提醒
- **数据可视化** - 每分钟/小时/天的趋势图表
- **本地存储** - 所有数据仅存储在本地，保护隐私
- **开机启动** - 支持开机自动启动 (macOS 13.0+)
- **可自定义** - 调整检测灵敏度、提醒阈值和预览设置
- **菜单栏应用** - 轻量级，不占用 Dock 位置

## 系统要求

- macOS 13.0 (Ventura) 或更高版本（完整功能支持）
- macOS 14.0 (Sonoma) 或更高版本（推荐）
- 带有摄像头的 Mac 设备
- 摄像头使用权限

> **注意**: 开机自动启动功能需要 macOS 13.0 或更高版本

## 安装

### 下载预编译版本

从 [Releases](https://github.com/mrhuangyong/eyeapp/releases) 页面下载最新的 `EyeApp-macOS.zip`，解压后将 `EyeApp.app` 拖入 Applications 文件夹。

### 从源码构建

```bash
# 克隆仓库
git clone https://github.com/mrhuangyong/eyeapp.git
cd eyeapp

# 使用 Xcode 构建
open EyeApp.xcodeproj
# 按 Cmd + R 运行，或 Cmd + B 构建
```

## 使用说明

### 首次启动

1. 启动应用后，系统会请求摄像头权限
2. 授权后，点击菜单栏的眼睛图标
3. 点击"开始监测"开始眨眼检测

### 菜单栏图标状态

| 颜色 | 状态 | 眨眼频率 |
|------|------|----------|
| 绿色 | 正常 | > 15 次/分 |
| 黄色 | 轻度疲劳 | 10-15 次/分 |
| 橙色 | 中度疲劳 | 5-10 次/分 |
| 红色 | 严重疲劳 | < 5 次/分 |

### 主面板功能

点击菜单栏图标打开主面板：

- **摄像头预览** - 240x180 实时画面，点击放大按钮可打开独立窗口
- **实时眨眼频率** - 当前每分钟眨眼次数
- **今日总次数** - 今日累计眨眼次数
- **趋势图表** - 最近 60 分钟的眨眼趋势

### 设置选项

通过菜单栏 → 设置 打开设置面板：

#### 提醒设置
- 启用/禁用疲劳提醒
- 调整提醒阈值（5-30 次/分）
- 设置提醒间隔（5-60 分钟）

#### 检测设置
- 检测灵敏度（低/中/高）
- 数据保留期限（7/14/30/90 天）

#### 预览设置
- 启用/禁用主面板预览
- 镜像显示

#### 隐私设置
- 摄像头权限状态
- 开机自启动

## 技术架构

### 技术栈

| 组件 | 技术 |
|------|------|
| 语言 | Swift 5.9 |
| UI 框架 | SwiftUI |
| 人脸检测 | Vision Framework |
| 摄像头 | AVFoundation |
| 数据存储 | JSON |
| 图表 | Swift Charts |

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
│   │   └── DataStorage.swift        # 数据存储
│   ├── Models/
│   │   ├── BlinkEvent.swift         # 眨眼事件
│   │   ├── AppConfig.swift          # 应用配置
│   │   └── FatigueStatus.swift      # 疲劳状态
│   └── UI/
│       ├── StatusBarController.swift # 状态栏
│       ├── MainPanelView.swift       # 主面板
│       ├── CameraPreviewView.swift   # 摄像头预览
│       ├── PreviewWindowController.swift # 预览窗口
│       └── SettingsPanelView.swift   # 设置面板
├── .github/workflows/
│   ├── build.yml                    # 构建工作流
│   └── release.yml                  # 发布工作流
└── Assets.xcassets/
```

## 贡献

欢迎贡献代码！请遵循以下步骤：

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'feat: add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 联系方式

- 问题反馈: [GitHub Issues](https://github.com/mrhuangyong/eyeapp/issues)

---

**注意**: 本应用仅供健康参考，不构成医疗建议。如有眼部不适，请咨询专业医生。
