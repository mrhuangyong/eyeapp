//
//  MainPanelViewModel.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import SwiftUI
import Combine

/// 主面板视图模型
class MainPanelViewModel: ObservableObject {

    // MARK: - Dependencies

    let statsEngine: StatsEngine
    let alertManager: AlertManager
    let dataStorage: DataStorage

    // MARK: - Published Properties

    @Published var currentBlinkRate: Int = 0
    @Published var todayTotalBlinks: Int = 0
    @Published var fatigueStatus: FatigueStatus?
    @Published var isMonitoring: Bool = false

    @Published var trendData: [TrendDataPoint] = []
    @Published var historyStats: HistoryStats = .empty

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    // MARK: - Initialization

    init(statsEngine: StatsEngine, alertManager: AlertManager, dataStorage: DataStorage) {
        self.statsEngine = statsEngine
        self.alertManager = alertManager
        self.dataStorage = dataStorage

        setupBindings()
        startUpdateTimer()
    }

    deinit {
        updateTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupBindings() {
        // 监听眨眼事件
        NotificationCenter.default.publisher(for: .blinkDetected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCurrentStats()
            }
            .store(in: &cancellables)

        // 监听疲劳提醒
        NotificationCenter.default.publisher(for: .fatigueAlertTriggered)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let status = notification.object as? FatigueStatus {
                    self?.fatigueStatus = status
                }
            }
            .store(in: &cancellables)
    }

    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCurrentStats()
        }
    }

    // MARK: - Public Methods

    /// 加载数据
    func loadData() {
        loadTodayData()
        loadTrendData()
    }

    /// 加载历史统计
    func loadHistory(for range: TimeRange) {
        let (startDate, endDate) = calculateDateRange(for: range)
        let dailyData = dataStorage.loadData(from: startDate, to: endDate)

        historyStats = calculateHistoryStats(from: dailyData)
    }

    /// 切换监测状态
    func toggleMonitoring() {
        isMonitoring.toggle()

        if isMonitoring {
            NotificationCenter.default.post(name: .startMonitoring, object: nil)
        } else {
            NotificationCenter.default.post(name: .stopMonitoring, object: nil)
        }
    }

    /// 清除今日数据
    func clearTodayData() {
        statsEngine.reset()
        trendData = []
        todayTotalBlinks = 0
        currentBlinkRate = 0
        fatigueStatus = nil
    }

    // MARK: - Private Methods

    private func updateCurrentStats() {
        let rate = statsEngine.getBlinkRate(for: Date())
        currentBlinkRate = Int(rate)

        let todayStats = statsEngine.getTodayStats()
        todayTotalBlinks = todayStats.totalBlinks

        fatigueStatus = FatigueStatus(blinkRate: rate)
    }

    private func loadTodayData() {
        let todayStats = statsEngine.getTodayStats()
        todayTotalBlinks = todayStats.totalBlinks

        if let dailyData = dataStorage.loadDailyData(date: Date()) {
            todayTotalBlinks = dailyData.summary.totalBlinks
        }
    }

    private func loadTrendData() {
        let trend = statsEngine.getTrend(for: Date(), duration: .minutes(60))
        trendData = trend.map { stat in
            TrendDataPoint(minute: stat.minute, blinkCount: stat.blinkCount)
        }
    }

    private func calculateDateRange(for range: TimeRange) -> (Date, Date) {
        let calendar = Calendar.current
        let now = Date()

        switch range {
        case .today:
            let start = calendar.startOfDay(for: now)
            return (start, now)

        case .thisWeek:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            return (start, now)

        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            return (start, now)

        case .all:
            let start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            return (start, now)
        }
    }

    private func calculateHistoryStats(from dailyData: [DailyBlinkData]) -> HistoryStats {
        guard !dailyData.isEmpty else { return .empty }

        let totalBlinks = dailyData.reduce(0) { $0 + $1.summary.totalBlinks }
        let totalDuration = dailyData.reduce(0.0) { $0 + $1.summary.monitorDuration }
        let avgRate = totalDuration > 0 ? Double(totalBlinks) / (totalDuration / 60.0) : 0
        let avgConfidence = dailyData.reduce(0.0) { $0 + ($1.summary.avgBlinkRate) } / Double(dailyData.count)

        return HistoryStats(
            avgBlinkRate: avgRate,
            fatigueAlerts: dailyData.reduce(0) { $0 + $1.summary.fatigueAlerts },
            totalDuration: totalDuration,
            avgConfidence: avgConfidence
        )
    }
}

// MARK: - Supporting Types

/// 趋势数据点
struct TrendDataPoint: Identifiable {
    let id = UUID()
    let minute: Date
    let blinkCount: Int
}

/// 历史统计
struct HistoryStats {
    let avgBlinkRate: Double
    let fatigueAlerts: Int
    let totalDuration: TimeInterval
    let avgConfidence: Double

    static let empty = HistoryStats(avgBlinkRate: 0, fatigueAlerts: 0, totalDuration: 0, avgConfidence: 0)

    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let blinkDetected = Notification.Name("com.eyeapp.blinkDetected")
    static let startMonitoring = Notification.Name("com.eyeapp.startMonitoring")
    static let stopMonitoring = Notification.Name("com.eyeapp.stopMonitoring")
}
