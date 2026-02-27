//
//  StatusBarController.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import SwiftUI
import AppKit
import Combine

/// 状态栏状态
enum StatusBarStatus: Equatable {
    case ready
    case running
    case paused
    case noFace
    case noPermission
    case noCamera
    case error(String)

    static func == (lhs: StatusBarStatus, rhs: StatusBarStatus) -> Bool {
        switch (lhs, rhs) {
        case (.ready, .ready),
             (.running, .running),
             (.paused, .paused),
             (.noFace, .noFace),
             (.noPermission, .noPermission),
             (.noCamera, .noCamera):
            return true
        case (.error(let l), .error(let r)):
            return l == r
        default:
            return false
        }
    }

    var icon: String {
        switch self {
        case .ready: return "eye"
        case .running: return "eye.fill"
        case .paused: return "eye.slash"
        case .noFace: return "person.crop.circle.badge.questionmark"
        case .noPermission: return "eye.slash.fill"
        case .noCamera: return "video.slash"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var color: NSColor {
        switch self {
        case .ready: return .systemGray
        case .running: return .systemGreen
        case .paused: return .systemOrange
        case .noFace: return .systemYellow
        case .noPermission, .noCamera: return .systemRed
        case .error: return .systemRed
        }
    }

    var tooltip: String {
        switch self {
        case .ready: return "EyeApp - 准备就绪"
        case .running: return "EyeApp - 监测中"
        case .paused: return "EyeApp - 已暂停"
        case .noFace: return "EyeApp - 未检测到人脸"
        case .noPermission: return "EyeApp - 无摄像头权限"
        case .noCamera: return "EyeApp - 未找到摄像头"
        case .error(let msg): return "EyeApp - 错误: \(msg)"
        }
    }
}

/// 状态栏控制器
class StatusBarController: ObservableObject {

    // MARK: - Properties

    private var statusItem: NSStatusItem
    private var popover: NSPopover?

    private let statsEngine: StatsEngine
    private let alertManager: AlertManager
    private let dataStorage: DataStorage

    @Published private(set) var status: StatusBarStatus = .ready
    @Published private(set) var blinkRate: Int = 0
    @Published private(set) var fatigueStatus: FatigueStatus?

    // MARK: - Callbacks

    var onStartMonitoring: (() -> Void)?
    var onStopMonitoring: (() -> Void)?
    var onPauseMonitoring: (() -> Void)?
    var onResumeMonitoring: (() -> Void)?

    // MARK: - Initialization

    init(statsEngine: StatsEngine, alertManager: AlertManager, dataStorage: DataStorage) {
        self.statsEngine = statsEngine
        self.alertManager = alertManager
        self.dataStorage = dataStorage

        // 创建状态栏项目
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        setupStatusItem()
        setupMenu()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: status.icon, accessibilityDescription: "EyeApp")
            button.imagePosition = .imageOnly
            button.toolTip = status.tooltip
        }
    }

    private func setupMenu() {
        let menu = NSMenu()

        // 状态信息
        let statusItem = NSMenuItem(title: "眨眼率: 0 次/分", action: nil, keyEquivalent: "")
        statusItem.tag = 100
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // 开始/停止监测
        let toggleItem = NSMenuItem(
            title: "开始监测",
            action: #selector(toggleMonitoring),
            keyEquivalent: "m"
        )
        toggleItem.tag = 101
        menu.addItem(toggleItem)

        // 暂停/恢复
        let pauseItem = NSMenuItem(
            title: "暂停",
            action: #selector(togglePause),
            keyEquivalent: "p"
        )
        pauseItem.tag = 102
        menu.addItem(pauseItem)

        menu.addItem(NSMenuItem.separator())

        // 显示主面板
        menu.addItem(NSMenuItem(
            title: "显示统计",
            action: #selector(showMainPanel),
            keyEquivalent: "s"
        ))

        // 设置
        menu.addItem(NSMenuItem(
            title: "设置...",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))

        menu.addItem(NSMenuItem.separator())

        // 退出
        menu.addItem(NSMenuItem(
            title: "退出 EyeApp",
            action: #selector(quitApp),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
    }

    // MARK: - Public Methods

    /// 更新状态
    func updateStatus(_ newStatus: StatusBarStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.status = newStatus
            self?.updateIcon()
        }
    }

    /// 更新眨眼率
    func updateBlinkRate(_ rate: Int, status: FatigueStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.blinkRate = rate
            self?.fatigueStatus = status
            self?.updateMenuItems()
            self?.updateIconColor(status.color)
        }
    }

    /// 显示疲劳提醒
    func showFatigueAlert(_ status: FatigueStatus) {
        let alert = NSAlert()
        alert.messageText = "👁️ 疲劳提醒"
        alert.informativeText = "\(status.recommendation)\n\n当前眨眼频率: \(Int(status.blinkRate)) 次/分钟"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "休息一下")
        alert.addButton(withTitle: "稍后提醒")

        alert.runModal()
    }

    // MARK: - Private Methods

    private func updateIcon() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: status.icon, accessibilityDescription: "EyeApp")
            button.toolTip = status.tooltip
        }
    }

    private func updateIconColor(_ color: Color) {
        if let button = statusItem.button {
            button.contentTintColor = NSColor(color)
        }
    }

    private func updateMenuItems() {
        guard let menu = statusItem.menu else { return }

        for item in menu.items {
            switch item.tag {
            case 100:
                item.title = "眨眼率: \(blinkRate) 次/分"
            case 101:
                item.title = status == .running ? "停止监测" : "开始监测"
            case 102:
                item.title = status == .paused ? "恢复" : "暂停"
                item.isEnabled = status == .running || status == .paused
            default:
                break
            }
        }
    }

    // MARK: - Actions

    @objc private func toggleMonitoring() {
        if status == .running {
            onStopMonitoring?()
            updateStatus(.ready)
        } else {
            onStartMonitoring?()
            updateStatus(.running)
        }
    }

    @objc private func togglePause() {
        if status == .paused {
            onResumeMonitoring?()
            updateStatus(.running)
        } else if status == .running {
            onPauseMonitoring?()
            updateStatus(.paused)
        }
    }

    @objc private func showMainPanel() {
        let mainPanel = MainPanelView(
            statsEngine: statsEngine,
            alertManager: alertManager,
            dataStorage: dataStorage
        )

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: mainPanel)

        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }

        self.popover = popover
    }

    @objc private func openSettings() {
        let settingsPanel = SettingsPanelView(
            dataStorage: dataStorage,
            alertManager: alertManager
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "EyeApp 设置"
        window.contentView = NSHostingView(rootView: settingsPanel)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
