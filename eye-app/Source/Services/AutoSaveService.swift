//
//  AutoSaveService.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import Foundation
import Combine

/// 自动保存服务 - 定期保存数据到磁盘
class AutoSaveService {

    // MARK: - Properties

    private let statsEngine: StatsEngine
    private let dataStorage: DataStorage

    private var saveTimer: Timer?
    private var lastSaveTime: Date = Date()

    /// 保存间隔（秒）
    var interval: TimeInterval

    /// 是否正在运行
    private(set) var isRunning: Bool = false

    // MARK: - Callbacks

    var onSave: (() -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Initialization

    init(statsEngine: StatsEngine, dataStorage: DataStorage, interval: TimeInterval = 60) {
        self.statsEngine = statsEngine
        self.dataStorage = dataStorage
        self.interval = interval
    }

    deinit {
        stop()
    }

    // MARK: - Public Methods

    /// 启动自动保存
    func start() {
        guard !isRunning else { return }

        isRunning = true

        saveTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            self?.performSave()
        }

        // 立即执行一次保存
        performSave()
    }

    /// 停止自动保存
    func stop() {
        saveTimer?.invalidate()
        saveTimer = nil
        isRunning = false
    }

    /// 手动触发保存
    func saveNow() {
        performSave()
    }

    // MARK: - Private Methods

    private func performSave() {
        do {
            try saveCurrentData()
            lastSaveTime = Date()
            onSave?()
        } catch {
            print("Auto-save failed: \(error)")
            onError?(error)
        }
    }

    private func saveCurrentData() throws {
        // 获取所有事件
        let events = statsEngine.getAllEvents()

        // 按日期分组
        let calendar = Calendar.current
        var grouped: [Date: [BlinkEvent]] = [:]

        for event in events {
            let day = calendar.startOfDay(for: event.timestamp)
            grouped[day, default: []].append(event)
        }

        // 保存每天的数据
        for (date, dayEvents) in grouped {
            dataStorage.saveDailyData(date: date, events: dayEvents)
        }
    }
}
