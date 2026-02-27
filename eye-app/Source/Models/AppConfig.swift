//
//  AppConfig.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import Foundation

/// 检测灵敏度等级
enum SensitivityLevel: String, Codable, CaseIterable {
    case low
    case medium
    case high

    var description: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }

    /// 对应的 EAR 阈值
    var earThreshold: Double {
        switch self {
        case .low: return 0.15
        case .medium: return 0.2
        case .high: return 0.25
        }
    }
}

/// 应用配置
struct AppConfig: Codable, Equatable {

    // MARK: - Alert Settings

    /// 是否启用疲劳提醒
    var alertEnabled: Bool = true

    /// 提醒阈值（每分钟眨眼次数）
    var alertThreshold: Int = 10

    /// 提醒间隔（分钟）
    var alertInterval: Int = 15

    /// 声音提醒
    var soundEnabled: Bool = true

    // MARK: - Detection Settings

    /// 检测灵敏度
    var sensitivity: SensitivityLevel = .medium

    // MARK: - Data Settings

    /// 数据保留天数
    var dataRetentionDays: Int = 30

    /// 是否记录原始事件
    var recordRawEvents: Bool = true

    // MARK: - Preview Settings

    /// 是否启用主面板预览
    var previewEnabled: Bool = true

    /// 预览是否镜像显示
    var previewMirrored: Bool = true

    // MARK: - Startup Settings

    /// 开机自启动
    var launchAtLogin: Bool = true

    /// 自动开始监测
    var autoStartMonitoring: Bool = true

    /// 显示菜单栏图标
    var showMenuBarIcon: Bool = true

    // MARK: - Computed Properties for UI

    /// Slider 用的 Double 值
    var alertThresholdDouble: Double {
        get { Double(alertThreshold) }
        set { alertThreshold = Int(newValue) }
    }

    var alertIntervalDouble: Double {
        get { Double(alertInterval) }
        set { alertInterval = Int(newValue) }
    }

    // MARK: - Default

    static let `default` = AppConfig()

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case alertEnabled
        case alertThreshold
        case alertInterval
        case soundEnabled
        case sensitivity
        case dataRetentionDays
        case recordRawEvents
        case previewEnabled
        case previewMirrored
        case launchAtLogin
        case autoStartMonitoring
        case showMenuBarIcon
    }

    // Custom encoder to exclude computed properties
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(alertEnabled, forKey: .alertEnabled)
        try container.encode(alertThreshold, forKey: .alertThreshold)
        try container.encode(alertInterval, forKey: .alertInterval)
        try container.encode(soundEnabled, forKey: .soundEnabled)
        try container.encode(sensitivity, forKey: .sensitivity)
        try container.encode(dataRetentionDays, forKey: .dataRetentionDays)
        try container.encode(recordRawEvents, forKey: .recordRawEvents)
        try container.encode(previewEnabled, forKey: .previewEnabled)
        try container.encode(previewMirrored, forKey: .previewMirrored)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(autoStartMonitoring, forKey: .autoStartMonitoring)
        try container.encode(showMenuBarIcon, forKey: .showMenuBarIcon)
    }
}
