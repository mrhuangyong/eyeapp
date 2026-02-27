//
//  StatsEngine.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import Foundation

/// 时间范围
enum TrendDuration {
    case minutes(Int)
    case hours(Int)
    case days(Int)

    var seconds: TimeInterval {
        switch self {
        case .minutes(let m): return Double(m * 60)
        case .hours(let h): return Double(h * 3600)
        case .days(let d): return Double(d * 86400)
        }
    }
}

/// 分钟统计数据
struct MinuteStatsData {
    let minute: Date
    var blinkCount: Int
    var totalConfidence: Double
    var events: [BlinkEvent]

    var avgConfidence: Double {
        guard events.count > 0 else { return 0 }
        return totalConfidence / Double(events.count)
    }
}

/// 今日统计摘要
struct TodayStats {
    let totalBlinks: Int
    let avgBlinkRate: Double
    let avgConfidence: Double
    let monitorDuration: TimeInterval
    let fatigueAlerts: Int
}

/// 统计引擎 - 负责眨眼数据聚合和分析
class StatsEngine {

    // MARK: - Properties

    private var blinkEvents: [BlinkEvent] = []
    private var minuteCache: [Date: MinuteStatsData] = [:]
    private var fatigueAlertCount: Int = 0

    private let calendar = Calendar.current

    // MARK: - Current State

    /// 当前分钟的眨眼次数
    var currentMinuteBlinks: Int {
        let now = Date()
        let key = minuteKey(for: now)
        return minuteCache[key]?.blinkCount ?? 0
    }

    // MARK: - Recording

    /// 记录眨眼事件
    func recordBlink(_ event: BlinkEvent) {
        blinkEvents.append(event)
        updateMinuteCache(for: event.timestamp)
    }

    private func updateMinuteCache(for timestamp: Date) {
        let key = minuteKey(for: timestamp)

        if var existing = minuteCache[key] {
            existing.blinkCount += 1
            existing.totalConfidence += blinkEvents.last?.confidence ?? 0.9
            if let lastEvent = blinkEvents.last {
                existing.events.append(lastEvent)
            }
            minuteCache[key] = existing
        } else {
            minuteCache[key] = MinuteStatsData(
                minute: key,
                blinkCount: 1,
                totalConfidence: blinkEvents.last?.confidence ?? 0.9,
                events: blinkEvents.suffix(1).map { $0 }
            )
        }
    }

    // MARK: - Statistics Queries

    /// 获取指定分钟的统计
    func getStatsForMinute(_ date: Date) -> MinuteStats? {
        let key = minuteKey(for: date)
        guard let data = minuteCache[key] else { return nil }

        return MinuteStats(
            minute: data.minute,
            blinkCount: data.blinkCount,
            avgConfidence: data.avgConfidence
        )
    }

    /// 获取眨眼频率（每分钟次数）
    func getBlinkRate(for date: Date) -> Double {
        let minuteStart = calendar.date(bySetting: .second, value: 0, of: date) ?? date
        let oneMinuteAgo = date.addingTimeInterval(-60)

        // 计算最近 60 秒内的眨眼次数
        let recentBlinks = blinkEvents.filter { $0.timestamp >= oneMinuteAgo && $0.timestamp <= date }

        return Double(recentBlinks.count)
    }

    /// 获取今日统计
    func getTodayStats() -> TodayStats {
        let today = calendar.startOfDay(for: Date())
        let todayEnd = today.addingTimeInterval(86400)

        let todayEvents = blinkEvents.filter { $0.timestamp >= today && $0.timestamp < todayEnd }

        let totalBlinks = todayEvents.count

        // 计算平均眨眼率
        let duration = calculateMonitorDuration(events: todayEvents)
        let avgRate = duration > 0 ? Double(totalBlinks) / (duration / 60.0) : 0

        // 计算平均置信度
        let avgConfidence = todayEvents.isEmpty ? 0 : todayEvents.reduce(0.0) { $0 + $1.confidence } / Double(todayEvents.count)

        return TodayStats(
            totalBlinks: totalBlinks,
            avgBlinkRate: avgRate,
            avgConfidence: avgConfidence,
            monitorDuration: duration,
            fatigueAlerts: fatigueAlertCount
        )
    }

    /// 获取趋势数据
    func getTrend(for date: Date, duration: TrendDuration) -> [MinuteStats] {
        let startTime = date.addingTimeInterval(-duration.seconds)
        var result: [MinuteStats] = []

        // 按分钟遍历
        var currentTime = minuteKey(for: startTime)
        let endTime = minuteKey(for: date)

        while currentTime <= endTime {
            if let stats = minuteCache[currentTime] {
                result.append(MinuteStats(
                    minute: stats.minute,
                    blinkCount: stats.blinkCount,
                    avgConfidence: stats.avgConfidence
                ))
            }
            currentTime = calendar.date(byAdding: .minute, value: 1, to: currentTime) ?? currentTime
        }

        return result
    }

    // MARK: - Data Management

    /// 获取所有事件
    func getAllEvents() -> [BlinkEvent] {
        return blinkEvents
    }

    /// 清除旧数据
    func clearOldData(olderThan days: Int) {
        let cutoff = Date().addingTimeInterval(-Double(days * 86400))
        blinkEvents.removeAll { $0.timestamp < cutoff }
        rebuildCache()
    }

    /// 增加疲劳提醒计数
    func incrementFatigueAlert() {
        fatigueAlertCount += 1
    }

    /// 重置引擎
    func reset() {
        blinkEvents.removeAll()
        minuteCache.removeAll()
        fatigueAlertCount = 0
    }

    // MARK: - Private Methods

    private func minuteKey(for date: Date) -> Date {
        return calendar.date(bySetting: .second, value: 0, of: date) ?? date
    }

    private func rebuildCache() {
        minuteCache.removeAll()
        for event in blinkEvents {
            updateMinuteCache(for: event.timestamp)
        }
    }

    private func calculateMonitorDuration(events: [BlinkEvent]) -> TimeInterval {
        guard let first = events.first, let last = events.last else { return 0 }
        return last.timestamp.timeIntervalSince(first.timestamp)
    }
}

// MARK: - Data Import/Export

extension StatsEngine {

    /// 导入事件数据
    func importEvents(_ events: [BlinkEvent]) {
        for event in events {
            blinkEvents.append(event)
            updateMinuteCache(for: event.timestamp)
        }
    }

    /// 获取指定日期范围的事件
    func getEvents(from startDate: Date, to endDate: Date) -> [BlinkEvent] {
        return blinkEvents.filter { $0.timestamp >= startDate && $0.timestamp < endDate }
    }
}
