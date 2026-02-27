//
//  DailyBlinkData.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import Foundation

/// 每日眨眼数据
struct DailyBlinkData: Codable, Identifiable {
    let id: UUID
    let date: Date
    var events: [BlinkEvent]
    var minuteStats: [MinuteStats]
    var summary: DailySummary

    init(date: Date, events: [BlinkEvent], minuteStats: [MinuteStats], summary: DailySummary) {
        self.id = UUID()
        self.date = date
        self.events = events
        self.minuteStats = minuteStats
        self.summary = summary
    }
}

/// 每日统计摘要
struct DailySummary: Codable {
    let totalBlinks: Int
    let avgBlinkRate: Double
    let fatigueAlerts: Int
    let monitorDuration: TimeInterval

    /// 格式化监测时长
    var formattedDuration: String {
        let hours = Int(monitorDuration) / 3600
        let minutes = (Int(monitorDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
