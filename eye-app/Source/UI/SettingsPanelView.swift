//
//  SettingsPanelView.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import SwiftUI
import Combine
import AVFoundation
import ServiceManagement

/// 设置面板视图
struct SettingsPanelView: View {

    // MARK: - Dependencies

    @ObservedObject private var viewModel: SettingsViewModel

    // MARK: - State

    @Environment(\.dismiss) private var dismiss

    // MARK: - Initialization

    init(dataStorage: DataStorage, alertManager: AlertManager) {
        self._viewModel = ObservedObject(wrappedValue: SettingsViewModel(
            dataStorage: dataStorage,
            alertManager: alertManager
        ))
    }

    // MARK: - Body

    var body: some View {
        TabView {
            AlertSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("提醒设置", systemImage: "bell")
                }

            DetectionSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("检测设置", systemImage: "eye")
                }

            PrivacySettingsView(viewModel: viewModel)
                .tabItem {
                    Label("隐私", systemImage: "lock")
                }

            AboutSettingsView()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Alert Settings View

struct AlertSettingsView: View {

    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("🔔 提醒设置") {
                Toggle("启用疲劳提醒", isOn: $viewModel.config.alertEnabled)
                    .help("当眨眼频率过低时发送提醒")

                VStack(alignment: .leading, spacing: 8) {
                    Text("提醒阈值: \(viewModel.config.alertThreshold) 次/分")
                        .font(.subheadline)

                    Slider(value: $viewModel.config.alertThresholdDouble, in: 5...30, step: 1)
                        .onChange(of: viewModel.config.alertThresholdDouble) { _, newValue in
                            viewModel.config.alertThreshold = Int(newValue)
                        }

                    Text("低于此频率时触发提醒")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .disabled(!viewModel.config.alertEnabled)

                VStack(alignment: .leading, spacing: 8) {
                    Text("提醒间隔: \(viewModel.config.alertInterval) 分钟")
                        .font(.subheadline)

                    Slider(value: $viewModel.config.alertIntervalDouble, in: 5...60, step: 5)
                        .onChange(of: viewModel.config.alertIntervalDouble) { _, newValue in
                            viewModel.config.alertInterval = Int(newValue)
                        }

                    Text("两次提醒之间的最小间隔")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .disabled(!viewModel.config.alertEnabled)

                Toggle("启用声音提醒", isOn: $viewModel.config.soundEnabled)
                    .disabled(!viewModel.config.alertEnabled)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Detection Settings View

struct DetectionSettingsView: View {

    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("📹 预览设置") {
                Toggle("启用主面板预览", isOn: $viewModel.config.previewEnabled)
                    .help("在主面板顶部显示摄像头实时画面")

                Toggle("镜像显示", isOn: $viewModel.config.previewMirrored)
                    .help("水平镜像摄像头画面（类似照镜子）")
            }

            Section("🎯 检测灵敏度") {
                Picker("灵敏度", selection: $viewModel.config.sensitivity) {
                    ForEach(SensitivityLevel.allCases, id: \.self) { level in
                        Text(level.description).tag(level)
                    }
                }
                .pickerStyle(.segmented)

                Text("灵敏度越高，检测越灵敏，但可能增加误检")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("当前 EAR 阈值: \(viewModel.config.sensitivity.earThreshold, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            Section("📊 统计设置") {
                Picker("数据保留期限", selection: $viewModel.config.dataRetentionDays) {
                    Text("7 天").tag(7)
                    Text("14 天").tag(14)
                    Text("30 天").tag(30)
                    Text("90 天").tag(90)
                }

                Toggle("记录原始事件", isOn: $viewModel.config.recordRawEvents)
                    .help("记录每次眨眼的详细信息（占用更多存储空间）")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Privacy Settings View

struct PrivacySettingsView: View {

    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("🔒 隐私") {
                HStack {
                    Text("摄像头权限")
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.cameraAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                        Text(viewModel.cameraAuthorized ? "已授权" : "未授权")
                    }
                    .foregroundColor(viewModel.cameraAuthorized ? .green : .red)
                }

                Button("打开系统隐私设置") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Text("所有数据仅存储在本地，不会上传到云端")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("📌 启动") {
                Toggle("开机自动启动", isOn: $viewModel.config.launchAtLogin)
                    .onChange(of: viewModel.config.launchAtLogin) { _, newValue in
                        viewModel.setLaunchAtLogin(newValue)
                    }

                Toggle("启动时自动开始监测", isOn: $viewModel.config.autoStartMonitoring)
            }

            Section("💾 数据管理") {
                HStack {
                    Text("存储大小")
                    Spacer()
                    Text(viewModel.storageSize)
                        .foregroundColor(.secondary)
                }

                Button("导出所有数据") {
                    viewModel.exportData()
                }

                Button("清除所有数据") {
                    viewModel.clearAllData()
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            viewModel.checkCameraPermission()
            viewModel.calculateStorageSize()
        }
    }
}

// MARK: - About Settings View

struct AboutSettingsView: View {

    var body: some View {
        Form {
            Section("👁️ EyeApp") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("构建")
                    Spacer()
                    Text("2026.02.27")
                        .foregroundColor(.secondary)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("关于 EyeApp")
                        .font(.headline)

                    Text("EyeApp 是一款 macOS 原生应用，通过检测眨眼频率来提醒您注意用眼健康，预防视疲劳。")
                        .font(.caption)

                    Text("数据仅存储在本地，保护您的隐私。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    Text("技术栈")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Swift + SwiftUI", systemImage: "swift")
                        Label("Vision Framework", systemImage: "eye")
                        Label("AVFoundation", systemImage: "video")
                        Label("EAR 算法", systemImage: "waveform.path")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            Section {
                Link("访问 GitHub", destination: URL(string: "https://github.com")!)
                Link("反馈问题", destination: URL(string: "mailto:feedback@eyeapp.local")!)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Settings View Model

class SettingsViewModel: ObservableObject {

    // MARK: - Dependencies

    private let dataStorage: DataStorage
    private let alertManager: AlertManager

    // MARK: - Published Properties

    @Published var config: AppConfig = .default
    @Published var cameraAuthorized: Bool = false
    @Published var storageSize: String = "0 KB"

    // MARK: - Initialization

    init(dataStorage: DataStorage, alertManager: AlertManager) {
        self.dataStorage = dataStorage
        self.alertManager = alertManager

        loadConfig()
    }

    // MARK: - Public Methods

    func loadConfig() {
        if let savedConfig = dataStorage.loadConfig() {
            config = savedConfig
        }
    }

    func saveConfig() {
        dataStorage.saveConfig(config)

        // 更新 AlertManager 配置
        alertManager.config = AlertConfig(
            enabled: config.alertEnabled,
            threshold: config.alertThreshold,
            intervalMinutes: config.alertInterval
        )
    }

    func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraAuthorized = (status == .authorized)
    }

    func calculateStorageSize() {
        let size = dataStorage.getStorageSize()
        storageSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        // 使用 ServiceManagement 框架
        // 简化实现 - 实际应用中需要配置 LaunchAtLogin
        #if os(macOS)
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if enabled {
                try? service.register()
            } else {
                try? service.unregister()
            }
        }
        #endif
    }

    func exportData() {
        guard let exportURL = dataStorage.exportAllData() else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "eyeapp_export.json"
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let destinationURL = panel.url else { return }

            do {
                try FileManager.default.copyItem(at: exportURL, to: destinationURL)
                try? FileManager.default.removeItem(at: exportURL)
            } catch {
                print("Export failed: \(error)")
            }
        }
    }

    func clearAllData() {
        let alert = NSAlert()
        alert.messageText = "确认清除所有数据？"
        alert.informativeText = "此操作不可撤销，所有历史数据将被删除。"
        alert.alertStyle = .critical
        alert.addButton(withTitle: "清除")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            dataStorage.deleteData(olderThan: 0)
            calculateStorageSize()
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsPanelView(
        dataStorage: DataStorage(storageURL: URL(fileURLWithPath: "/tmp")),
        alertManager: AlertManager(statsEngine: StatsEngine())
    )
}
