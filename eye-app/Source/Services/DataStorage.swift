//
//  DataStorage.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import Foundation

/// 数据存储服务 - 负责配置和眨眼数据的持久化
class DataStorage {

    // MARK: - Properties

    private let storageURL: URL
    private let configFileName = "config.json"
    private let dataFolderName = "blink_data"

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Initialization

    init(storageURL: URL) {
        self.storageURL = storageURL
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        createDirectoryIfNeeded()
    }

    // MARK: - Directory Management

    private func createDirectoryIfNeeded() {
        let dataURL = storageURL.appendingPathComponent(dataFolderName)
        if !fileManager.fileExists(atPath: dataURL.path) {
            try? fileManager.createDirectory(at: dataURL, withIntermediateDirectories: true)
        }
    }

    // MARK: - Config Management

    /// 保存配置
    func saveConfig(_ config: AppConfig) {
        let url = storageURL.appendingPathComponent(configFileName)
        saveJSON(config, to: url)
    }

    /// 加载配置
    func loadConfig() -> AppConfig? {
        let url = storageURL.appendingPathComponent(configFileName)

        if let config: AppConfig = loadJSON(from: url) {
            return config
        }

        // Return default config if not found
        return .default
    }

    // MARK: - Daily Data Management

    /// 保存每日数据
    func saveDailyData(date: Date, events: [BlinkEvent]) {
        let fileName = dateFormatter.string(from: date) + ".json"
        let url = storageURL.appendingPathComponent(dataFolderName).appendingPathComponent(fileName)

        // Aggregate minute stats
        let minuteStats = aggregateMinuteStats(from: events)

        // Calculate summary
        let summary = DailySummary(
            totalBlinks: events.count,
            avgBlinkRate: calculateAvgRate(events: events),
            fatigueAlerts: 0,
            monitorDuration: calculateDuration(events: events)
        )

        let dailyData = DailyBlinkData(
            date: calendar.startOfDay(for: date),
            events: events,
            minuteStats: minuteStats,
            summary: summary
        )

        saveJSON(dailyData, to: url)
    }

    /// 加载每日数据
    func loadDailyData(date: Date) -> DailyBlinkData? {
        let fileName = dateFormatter.string(from: date) + ".json"
        let url = storageURL.appendingPathComponent(dataFolderName).appendingPathComponent(fileName)
        return loadJSON(from: url)
    }

    /// 加载日期范围内的数据
    func loadData(from startDate: Date, to endDate: Date) -> [DailyBlinkData] {
        var result: [DailyBlinkData] = []
        var currentDate = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        while currentDate <= end {
            if let data = loadDailyData(date: currentDate) {
                result.append(data)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return result
    }

    /// 删除旧数据
    func deleteData(olderThan days: Int) {
        let cutoff = calendar.startOfDay(for: Date())
            .addingTimeInterval(-TimeInterval(days * 86400))

        let dataURL = storageURL.appendingPathComponent(dataFolderName)

        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: dataURL,
            includingPropertiesForKeys: nil
        ) else { return }

        for fileURL in fileURLs {
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            guard let fileDate = dateFormatter.date(from: fileName),
                  fileDate < cutoff else {
                continue
            }

            try? fileManager.removeItem(at: fileURL)
        }
    }

    // MARK: - Private Helpers

    private func saveJSON<T: Codable>(_ value: T, to url: URL) {
        do {
            let data = try encoder.encode(value)
            try data.write(to: url)
        } catch {
            print("Failed to save JSON to \(url): \(error)")
        }
    }

    private func loadJSON<T: Codable>(from url: URL) -> T? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Failed to load JSON from \(url): \(error)")
            return nil
        }
    }

    private func aggregateMinuteStats(from events: [BlinkEvent]) -> [MinuteStats] {
        var grouped: [Date: [BlinkEvent]] = [:]

        for event in events {
            let minute = calendar.date(bySetting: .second, value: 0, of: event.timestamp) ?? event.timestamp
            grouped[minute, default: []].append(event)
        }

        return grouped.map { minute, events in
            let avgConfidence = events.reduce(0.0) { $0 + $1.confidence } / Double(events.count)
            return MinuteStats(minute: minute, blinkCount: events.count, avgConfidence: avgConfidence)
        }.sorted { $0.minute < $1.minute }
    }

    private func calculateAvgRate(events: [BlinkEvent]) -> Double {
        guard let first = events.first, let last = events.last else { return 0 }
        let duration = last.timestamp.timeIntervalSince(first.timestamp)
        return duration > 0 ? Double(events.count) / (duration / 60.0) : 0
    }

    private func calculateDuration(events: [BlinkEvent]) -> TimeInterval {
        guard let first = events.first, let last = events.last else { return 0 }
        return last.timestamp.timeIntervalSince(first.timestamp)
    }

    private var dateFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay]
        return formatter
    }

    private var calendar: Calendar {
        return Calendar.current
    }
}

// MARK: - Data Export

extension DataStorage {

    /// 导出所有数据为 JSON
    func exportAllData() -> URL? {
        let dataURL = storageURL.appendingPathComponent(dataFolderName)
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("eyeapp_export_\(dateFormatter.string(from: Date())).json")

        guard let files = try? fileManager.contentsOfDirectory(
            at: dataURL,
            includingPropertiesForKeys: nil
        ) else { return nil }

        var allData: [DailyBlinkData] = []
        for fileURL in files where fileURL.pathExtension == "json" {
            if let data: DailyBlinkData = loadJSON(from: fileURL) {
                allData.append(data)
            }
        }

        do {
            let exportData = try encoder.encode(allData)
            try exportData.write(to: exportURL)
            return exportURL
        } catch {
            print("Export failed: \(error)")
            return nil
        }
    }

    /// 获取存储大小（字节）
    func getStorageSize() -> Int64 {
        var totalSize: Int64 = 0

        if let files = try? fileManager.contentsOfDirectory(
            at: storageURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for file in files {
                if let attrs = try? file.resourceValues(forKeys: [.fileSizeKey]),
                   let size = attrs.fileSize {
                    totalSize += Int64(size)
                }
            }
        }

        return totalSize
    }
}
