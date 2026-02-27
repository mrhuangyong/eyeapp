//
//  MinuteStats.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import Foundation

/// 分钟级统计
struct MinuteStats: Codable, Identifiable, Equatable {
    let id: UUID
    let minute: Date        // 精确到分钟
    let blinkCount: Int
    let avgConfidence: Double

    init(minute: Date, blinkCount: Int, avgConfidence: Double) {
        self.id = UUID()
        self.minute = minute
        self.blinkCount = blinkCount
        self.avgConfidence = avgConfidence
    }
}
