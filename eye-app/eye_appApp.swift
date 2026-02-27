//
//  eye_appApp.swift
//  eye-app
//
//  Created by mrhua on 2026/2/27.
//

import SwiftUI
import Combine

@main
struct EyeAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 菜单栏应用不需要主窗口
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Services

    private var cameraManager: CameraManager!
    private var visionService: VisionService!
    private var blinkDetector: BlinkDetector!
    private var statsEngine: StatsEngine!
    private var alertManager: AlertManager!
    private var dataStorage: DataStorage!
    private var sessionManager: SessionManager!
    private var autoSaveService: AutoSaveService!

    // MARK: - UI

    private var statusBarController: StatusBarController?

    // MARK: - State

    private var config: AppConfig = .default
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置为菜单栏应用（不显示 Dock 图标）
        NSApp.setActivationPolicy(.accessory)

        // 初始化服务
        setupServices()

        // 创建 SessionManager
        setupSessionManager()

        // 创建状态栏控制器
        setupStatusBar()

        // 设置自动保存
        setupAutoSave()

        // 请求摄像头权限并启动
        requestCameraPermission()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 停止会话
        sessionManager?.stop()

        // 停止自动保存
        autoSaveService?.stop()

        // 最后保存数据
        saveCurrentData()
    }

    // MARK: - Setup

    private func setupServices() {
        // 初始化数据存储
        let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
            .appendingPathComponent("EyeApp", isDirectory: true)

        dataStorage = DataStorage(storageURL: supportURL)

        // 加载配置
        config = dataStorage.loadConfig() ?? .default

        // 初始化统计引擎
        statsEngine = StatsEngine()

        // 加载历史数据到统计引擎
        loadHistoricalData()

        // 初始化摄像头管理器
        cameraManager = CameraManager()
        cameraManager.frameRate = 30

        // 初始化视觉服务
        visionService = VisionService()
        visionService.confidenceThreshold = 0.5

        // 初始化眨眼检测器
        blinkDetector = BlinkDetector(
            threshold: config.sensitivity.earThreshold,
            debounceTime: 0.3
        )

        // 初始化提醒管理器
        alertManager = AlertManager(statsEngine: statsEngine)
        alertManager.config = AlertConfig(
            enabled: config.alertEnabled,
            threshold: config.alertThreshold,
            intervalMinutes: config.alertInterval
        )
    }

    private func setupSessionManager() {
        sessionManager = SessionManager(
            cameraManager: cameraManager,
            visionService: visionService,
            blinkDetector: blinkDetector,
            statsEngine: statsEngine,
            alertManager: alertManager
        )

        // 订阅会话状态变化
        sessionManager.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleSessionState(state)
            }
            .store(in: &cancellables)

        // 设置眨眼检测回调
        sessionManager.onBlinkDetected = { [weak self] event in
            self?.handleBlinkDetected(event)
        }

        // 设置错误回调
        sessionManager.onError = { [weak self] error in
            self?.handleSessionError(error)
        }
    }

    private func setupStatusBar() {
        statusBarController = StatusBarController(
            statsEngine: statsEngine,
            alertManager: alertManager,
            dataStorage: dataStorage
        )

        statusBarController?.onStartMonitoring = { [weak self] in
            self?.sessionManager.start()
        }

        statusBarController?.onStopMonitoring = { [weak self] in
            self?.sessionManager.stop()
        }

        statusBarController?.onPauseMonitoring = { [weak self] in
            self?.sessionManager.pause()
        }

        statusBarController?.onResumeMonitoring = { [weak self] in
            self?.sessionManager.resume()
        }
    }

    private func setupAutoSave() {
        autoSaveService = AutoSaveService(
            statsEngine: statsEngine,
            dataStorage: dataStorage,
            interval: 60 // 每分钟保存一次
        )
        autoSaveService.start()
    }

    private func loadHistoricalData() {
        // 加载最近30天的数据
        let calendar = Calendar.current
        let today = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today

        let historicalData = dataStorage.loadData(from: thirtyDaysAgo, to: today)

        for dailyData in historicalData {
            for event in dailyData.events {
                statsEngine.recordBlink(event)
            }
        }
    }

    // MARK: - Camera Permission

    private func requestCameraPermission() {
        cameraManager.requestPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.statusBarController?.updateStatus(.ready)
                    // 自动开始监测
                    if self?.config.autoStartMonitoring == true {
                        self?.sessionManager.start()
                    }
                } else {
                    self?.statusBarController?.updateStatus(.noPermission)
                }
            }
        }
    }

    // MARK: - Session Event Handlers

    private func handleSessionState(_ state: SessionState) {
        switch state {
        case .idle:
            statusBarController?.updateStatus(.ready)
        case .running:
            statusBarController?.updateStatus(.running)
        case .paused:
            statusBarController?.updateStatus(.paused)
        case .stopped:
            statusBarController?.updateStatus(.ready)
        case .error(let error):
            statusBarController?.updateStatus(.error(error.localizedDescription))
        }
    }

    private func handleBlinkDetected(_ event: BlinkEvent) {
        // 更新 UI
        let currentRate = statsEngine.getBlinkRate(for: Date())
        let status = FatigueStatus(blinkRate: currentRate)
        statusBarController?.updateBlinkRate(Int(currentRate), status: status)

        // 检查是否需要提醒
        if alertManager.shouldTriggerAlert() {
            alertManager.triggerAlert()
            statusBarController?.showFatigueAlert(status)
        }
    }

    private func handleSessionError(_ error: Error) {
        guard let sessionError = error as? SessionError else { return }

        switch sessionError {
        case .cameraPermissionDenied:
            statusBarController?.updateStatus(.noPermission)
        case .cameraUnavailable:
            statusBarController?.updateStatus(.noCamera)
        default:
            statusBarController?.updateStatus(.error(sessionError.localizedDescription))
        }
    }

    // MARK: - Data Persistence

    private func saveCurrentData() {
        let events = statsEngine.getAllEvents()
        dataStorage.saveDailyData(date: Date(), events: events)

        // 保存配置
        dataStorage.saveConfig(config)
    }
}
