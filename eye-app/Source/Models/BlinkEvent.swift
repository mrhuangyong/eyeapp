//
//  BlinkEvent.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import Foundation

/// 眨眼事件
struct BlinkEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let confidence: Double

    init(timestamp: Date, confidence: Double) {
        self.id = UUID()
        self.timestamp = timestamp
        self.confidence = confidence
    }

    // 简化的初始化方法
    init(timestamp: Date) {
        self.init(timestamp: timestamp, confidence: 1.0)
    }
}
