//
//  BlinkDetector.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import Foundation
import CoreGraphics

/// 眨眼检测结果
enum BlinkResult: Equatable {
    case blinkDetected
    case noBlink
    case debounced
}

/// 眨眼检测器 - 使用 EAR (Eye Aspect Ratio) 算法
class BlinkDetector {

    // MARK: - Properties

    private let threshold: Double
    private let debounceTime: TimeInterval
    private let minimumConfidence: Double = 0.5

    private var lastBlinkTime: Date?

    // MARK: - Initialization

    init(threshold: Double = 0.2, debounceTime: TimeInterval = 0.3) {
        self.threshold = threshold
        self.debounceTime = debounceTime
    }

    // MARK: - Public Methods

    /// 处理眼睛特征点，检测眨眼
    /// - Parameters:
    ///   - landmarks: 6个眼睛特征点 [p1, p2, p3, p4, p5, p6]
    ///   - confidence: 检测置信度 (0-1)
    /// - Returns: 眨眼检测结果
    func process(landmarks: [CGPoint], confidence: Double) -> BlinkResult {
        // 检查置信度
        guard confidence >= minimumConfidence else {
            return .noBlink
        }

        // 计算 EAR
        let ear = calculateEAR(for: landmarks)

        // 判断是否眨眼
        if ear < threshold {
            // 检查防抖
            if let lastBlink = lastBlinkTime {
                let timeSinceLastBlink = Date().timeIntervalSince(lastBlink)
                if timeSinceLastBlink < debounceTime {
                    return .debounced
                }
            }

            // 记录眨眼时间
            lastBlinkTime = Date()
            return .blinkDetected
        }

        return .noBlink
    }

    /// 计算 Eye Aspect Ratio (EAR)
    /// EAR = (|p2-p6| + |p3-p5|) / (2 * |p1-p4|)
    /// - Parameter landmarks: 6个眼睛特征点
    /// - Returns: EAR 值 (通常在 0.1-0.4 之间)
    func calculateEAR(for landmarks: [CGPoint]) -> Double {
        guard landmarks.count == 6 else {
            return 1.0 // 默认返回睁眼状态
        }

        let p1 = landmarks[0]
        let p2 = landmarks[1]
        let p3 = landmarks[2]
        let p4 = landmarks[3]
        let p5 = landmarks[4]
        let p6 = landmarks[5]

        // 计算垂直距离
        let vertical1 = distance(p2, p6)
        let vertical2 = distance(p3, p5)

        // 计算水平距离
        let horizontal = distance(p1, p4)

        // 避免除零
        guard horizontal > 0 else {
            return 1.0
        }

        // 计算 EAR
        return (vertical1 + vertical2) / (2.0 * horizontal)
    }

    /// 重置检测器状态
    func reset() {
        lastBlinkTime = nil
    }

    // MARK: - Private Methods

    /// 计算两点之间的欧几里得距离
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> Double {
        let dx = Double(p1.x - p2.x)
        let dy = Double(p1.y - p2.y)
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - Multi-Eye Detection

extension BlinkDetector {

    /// 处理双眼特征点，计算平均 EAR
    /// - Parameters:
    ///   - leftEye: 左眼 6 个特征点
    ///   - rightEye: 右眼 6 个特征点
    ///   - confidence: 检测置信度
    /// - Returns: 眨眼检测结果
    func process(leftEye: [CGPoint], rightEye: [CGPoint], confidence: Double) -> BlinkResult {
        guard confidence >= minimumConfidence else {
            return .noBlink
        }

        let leftEAR = calculateEAR(for: leftEye)
        let rightEAR = calculateEAR(for: rightEye)
        let avgEAR = (leftEAR + rightEAR) / 2.0

        if avgEAR < threshold {
            if let lastBlink = lastBlinkTime {
                let timeSinceLastBlink = Date().timeIntervalSince(lastBlink)
                if timeSinceLastBlink < debounceTime {
                    return .debounced
                }
            }

            lastBlinkTime = Date()
            return .blinkDetected
        }

        return .noBlink
    }
}
