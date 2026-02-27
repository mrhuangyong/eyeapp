//
//  AlertManager.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import Foundation
import UserNotifications

/// 提醒配置
struct AlertConfig: Codable, Equatable {
    var enabled: Bool = true
    var threshold: Int = 10          // 每分钟眨眼次数阈值
    var intervalMinutes: Int = 15    // 提醒间隔（分钟）

    static let `default` = AlertConfig()
}

/// 提醒管理器 - 负责疲劳检测和提醒
class AlertManager {

    // MARK: - Properties

    private let statsEngine: StatsEngine

    /// 提醒配置
    var config = AlertConfig.default

    /// 上次提醒时间
    var lastAlertTime: Date?

    /// 监测开始时间（用于预热期判断）
    var monitoringStartTime: Date?

    /// 预热期（秒）- 在此时间内不触发提醒
    private let warmupPeriod: TimeInterval = 60

    /// 提醒回调
    var onAlertTriggered: ((FatigueStatus) -> Void)?

    // MARK: - Initialization

    init(statsEngine: StatsEngine) {
        self.statsEngine = statsEngine
        requestNotificationPermission()
    }

    // MARK: - Fatigue Detection

    /// 检查疲劳状态
    /// - Returns: 当前疲劳状态
    func checkFatigueStatus() -> FatigueStatus {
        let blinkRate = statsEngine.getBlinkRate(for: Date())
        return FatigueStatus(blinkRate: blinkRate)
    }

    /// 检查疲劳状态（指定眨眼率）
    func checkFatigueStatus(blinkRate: Double) -> FatigueStatus {
        return FatigueStatus(blinkRate: blinkRate)
    }

    // MARK: - Alert Logic

    /// 开始监测（重置预热期计时器）
    func startMonitoring() {
        monitoringStartTime = Date()
    }

    /// 停止监测
    func stopMonitoring() {
        monitoringStartTime = nil
    }

    /// 是否应该触发提醒
    /// - Returns: 是否应该提醒
    func shouldTriggerAlert() -> Bool {
        // 检查是否启用
        guard config.enabled else { return false }

        // 检查是否在预热期内
        if let startTime = monitoringStartTime {
            let elapsedTime = Date().timeIntervalSince(startTime)
            if elapsedTime < warmupPeriod {
                return false
            }
        } else {
            // 未开始监测，不提醒
            return false
        }

        // 检查疲劳状态
        let status = checkFatigueStatus()

        // 只有中度或严重疲劳才提醒
        guard status.level == .moderate || status.level == .severe else {
            return false
        }

        // 检查提醒间隔
        if let lastAlert = lastAlertTime {
            let timeSinceLastAlert = Date().timeIntervalSince(lastAlert)
            let minimumInterval = TimeInterval(config.intervalMinutes * 60)

            if timeSinceLastAlert < minimumInterval {
                return false
            }
        }

        return true
    }

    /// 触发提醒
    func triggerAlert() {
        guard shouldTriggerAlert() else { return }

        let status = checkFatigueStatus()
        triggerAlertSilent()
        sendNotification(status: status)
        onAlertTriggered?(status)
    }

    /// 静默触发（不发送通知，只更新状态）
    func triggerAlertSilent() {
        lastAlertTime = Date()
        statsEngine.incrementFatigueAlert()
    }

    // MARK: - Notifications

    /// 发送系统通知
    func sendNotification(status: FatigueStatus) {
        let content = UNMutableNotificationContent()
        content.title = "👁️ EyeApp - 疲劳提醒"
        content.body = "\(status.recommendation)\n当前眨眼频率: \(Int(status.blinkRate)) 次/分钟"
        content.sound = .default
        content.badge = 1

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // 立即发送
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }

    /// 请求通知权限
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    // MARK: - Reset

    /// 重置提醒状态
    func reset() {
        lastAlertTime = nil
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let fatigueAlertTriggered = Notification.Name("com.eyeapp.fatigueAlertTriggered")
    static let blinkRateUpdated = Notification.Name("com.eyeapp.blinkRateUpdated")
}

// MARK: - AlertType

/// 提醒类型
enum AlertType {
    case lowBlinkRate
    case eyeStrain
    case breakReminder

    var title: String {
        switch self {
        case .lowBlinkRate: return "眨眼频率过低"
        case .eyeStrain: return "眼睛疲劳"
        case .breakReminder: return "休息提醒"
        }
    }

    var message: String {
        switch self {
        case .lowBlinkRate: return "您的眨眼频率较低，请注意眨眼"
        case .eyeStrain: return "您可能已经用眼过久，建议休息"
        case .breakReminder: return "该休息一下了，让眼睛放松放松"
        }
    }
}

// MARK: - Advanced Alerts

extension AlertManager {

    /// 发送自定义提醒
    func sendCustomAlert(type: AlertType) {
        let content = UNMutableNotificationContent()
        content.title = "👁️ EyeApp - \(type.title)"
        content.body = type.message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "custom-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// 发送定时提醒（例如每 20 分钟提醒休息）
    func scheduleBreakReminder(intervalMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "👁️ EyeApp - 休息提醒"
        content.body = "您已经工作了一段时间，该让眼睛休息一下了"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(intervalMinutes * 60),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "break-reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// 取消所有定时提醒
    func cancelAllScheduledAlerts() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
