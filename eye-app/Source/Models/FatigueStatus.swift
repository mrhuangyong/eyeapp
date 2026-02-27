//
//  FatigueStatus.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import Foundation
import SwiftUI

/// 疲劳等级
enum FatigueLevel: String, Codable, CaseIterable {
    case normal    // > 15 blinks/min
    case mild      // 10-15 blinks/min
    case moderate  // 5-10 blinks/min
    case severe    // < 5 blinks/min
}

/// 疲劳状态
struct FatigueStatus: Equatable {
    let level: FatigueLevel
    let blinkRate: Double
    let recommendation: String
    let color: Color

    init(blinkRate: Double) {
        self.blinkRate = blinkRate

        if blinkRate > 15 {
            self.level = .normal
            self.recommendation = "状态良好"
            self.color = .green
        } else if blinkRate >= 10 {
            self.level = .mild
            self.recommendation = "注意休息"
            self.color = .yellow
        } else if blinkRate >= 5 {
            self.level = .moderate
            self.recommendation = "建议休息一下"
            self.color = .orange
        } else {
            self.level = .severe
            self.recommendation = "请立即休息"
            self.color = .red
        }
    }
}

// MARK: - FatigueLevel Extensions

extension FatigueLevel {
    /// 疲劳等级对应的图标名称
    var iconName: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .mild: return "exclamationmark.triangle.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .severe: return "xmark.octagon.fill"
        }
    }

    /// 疲劳等级描述
    var description: String {
        switch self {
        case .normal: return "正常"
        case .mild: return "轻度疲劳"
        case .moderate: return "中度疲劳"
        case .severe: return "严重疲劳"
        }
    }
}
