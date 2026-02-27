//
//  SessionManager.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import Foundation
import Combine
import AVFoundation

/// 会话状态
enum SessionState: Equatable {
    case idle
    case running
    case paused
    case stopped
    case error(SessionError)

    static func == (lhs: SessionState, rhs: SessionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.running, .running),
             (.paused, .paused),
             (.stopped, .stopped):
            return true
        case (.error(let l), .error(let r)):
            return l.localizedDescription == r.localizedDescription
        default:
            return false
        }
    }
}

/// 会话错误
enum SessionError: Error, LocalizedError {
    case cameraPermissionDenied
    case cameraUnavailable
    case faceDetectionFailed
    case sessionNotRunning

    var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied: return "摄像头权限被拒绝"
        case .cameraUnavailable: return "摄像头不可用"
        case .faceDetectionFailed: return "人脸检测失败"
        case .sessionNotRunning: return "会话未运行"
        }
    }
}

/// 会话管理器 - 统一管理监测会话的完整生命周期
class SessionManager: ObservableObject {

    // MARK: - Dependencies

    private var cameraManager: CameraManagerProtocol
    private var visionService: VisionServiceProtocol
    private let blinkDetector: BlinkDetectorProtocol
    private let statsEngine: StatsEngine
    private let alertManager: AlertManager

    // MARK: - Published Properties

    @Published private(set) var state: SessionState = .idle
    @Published private(set) var sessionDuration: TimeInterval = 0

    // MARK: - Callbacks

    var onStateChanged: ((SessionState) -> Void)?
    var onBlinkDetected: ((BlinkEvent) -> Void)?
    var onError: ((Error) -> Void)?
    var onNoFaceDetected: (() -> Void)?

    // MARK: - Private Properties

    private var sessionStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private let minimumConfidence: Double = 0.5

    /// 未检测到人脸的连续帧数
    private var noFaceDetectedCount: Int = 0
    /// 自动暂停阈值（连续帧数，约 1 秒）
    private let autoPauseThreshold: Int = 30
    /// 是否因未检测到人脸而自动暂停
    private var isAutoPaused: Bool = false

    // MARK: - Initialization

    init(
        cameraManager: CameraManagerProtocol,
        visionService: VisionServiceProtocol,
        blinkDetector: BlinkDetectorProtocol,
        statsEngine: StatsEngine,
        alertManager: AlertManager
    ) {
        self.cameraManager = cameraManager
        self.visionService = visionService
        self.blinkDetector = blinkDetector
        self.statsEngine = statsEngine
        self.alertManager = alertManager

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // 摄像头帧回调
        cameraManager.onFrame = { [weak self] buffer in
            self?.handleCameraFrame(buffer)
        }

        // 摄像头错误回调
        cameraManager.onError = { [weak self] error in
            self?.handleCameraError(error)
        }

        // 视觉服务回调 - 人脸检测成功
        visionService.onFaceDetected = { [weak self] leftEye, rightEye, confidence in
            self?.handleFaceDetected(leftEye: leftEye, rightEye: rightEye, confidence: confidence)
        }

        // 视觉服务回调 - 未检测到人脸
        visionService.onNoFaceDetected = { [weak self] in
            self?.handleNoFaceDetected()
        }
    }

    // MARK: - Public Methods - Session Control

    /// 开始监测会话
    func start() {
        guard state == .idle || state == .stopped else { return }

        sessionStartTime = Date()
        cameraManager.start()
        alertManager.startMonitoring()
        updateState(.running)
    }

    /// 停止监测会话
    func stop() {
        guard state == .running || state == .paused else { return }

        cameraManager.stop()
        alertManager.stopMonitoring()
        sessionDuration = calculateDuration()
        updateState(.stopped)
    }

    /// 暂停监测
    func pause() {
        guard state == .running else { return }
        updateState(.paused)
    }

    /// 恢复监测
    func resume() {
        guard state == .paused else { return }
        updateState(.running)
    }

    /// 切换暂停/恢复
    func togglePause() {
        if state == .running {
            pause()
        } else if state == .paused {
            resume()
        }
    }

    // MARK: - Public Methods - Vision Processing

    /// 处理视觉检测结果
    func processVisionResult(leftEye: [CGPoint], rightEye: [CGPoint], confidence: Double) {
        guard state == .running else { return }

        // 检查置信度
        guard confidence >= minimumConfidence else { return }

        // 使用眨眼检测器处理
        let result = blinkDetector.process(
            leftEye: leftEye,
            rightEye: rightEye,
            confidence: confidence
        )

        handleBlinkResult(result, confidence: confidence)
    }

    // MARK: - Private Methods - Frame Handling

    private func handleCameraFrame(_ buffer: CMSampleBuffer) {
        guard state == .running else { return }
        visionService.process(sampleBuffer: buffer)
    }

    private func handleFaceDetected(leftEye: [CGPoint], rightEye: [CGPoint], confidence: Double) {
        // 重置未检测到人脸的计数器
        noFaceDetectedCount = 0

        // 如果是自动暂停状态，恢复监测
        if isAutoPaused {
            isAutoPaused = false
            updateState(.running)
            print("✅ 检测到人脸，恢复监测")
        }

        processVisionResult(leftEye: leftEye, rightEye: rightEye, confidence: confidence)
    }

    /// 处理未检测到人脸的情况
    private func handleNoFaceDetected() {
        guard state == .running else { return }

        noFaceDetectedCount += 1

        // 达到阈值时自动暂停
        if noFaceDetectedCount >= autoPauseThreshold && !isAutoPaused {
            isAutoPaused = true
            updateState(.paused)
            print("⚠️ 连续未检测到人脸，自动暂停监测")
        }
    }

    // MARK: - Private Methods - Blink Handling

    private func handleBlinkResult(_ result: BlinkResult, confidence: Double) {
        switch result {
        case .blinkDetected:
            let event = BlinkEvent(timestamp: Date(), confidence: confidence)
            recordBink(event)
            onBlinkDetected?(event)

            // 检查是否需要疲劳提醒
            checkFatigueAlert()

        case .noBlink:
            // 更新眨眼率但不记录事件
            break

        case .debounced:
            // 忽略防抖的眨眼
            break
        }
    }

    private func recordBink(_ event: BlinkEvent) {
        statsEngine.recordBlink(event)

        // 发送通知
        NotificationCenter.default.post(
            name: .blinkDetected,
            object: event
        )
    }

    private func checkFatigueAlert() {
        if alertManager.shouldTriggerAlert() {
            alertManager.triggerAlert()

            // 发送疲劳提醒通知
            let status = alertManager.checkFatigueStatus()
            NotificationCenter.default.post(
                name: .fatigueAlertTriggered,
                object: status
            )
        }
    }

    // MARK: - Private Methods - Error Handling

    private func handleCameraError(_ error: Error) {
        guard let cameraError = error as? CameraError else {
            updateState(.error(.cameraUnavailable))
            onError?(error)
            return
        }

        let sessionError: SessionError
        switch cameraError {
        case .permissionDenied:
            sessionError = .cameraPermissionDenied
        default:
            sessionError = .cameraUnavailable
        }

        updateState(.error(sessionError))
        onError?(sessionError)
    }

    // MARK: - Private Methods - State Management

    private func updateState(_ newState: SessionState) {
        let oldState = state
        state = newState

        if oldState != newState {
            onStateChanged?(newState)

            // 发送状态变化通知
            NotificationCenter.default.post(
                name: .sessionStateChanged,
                object: newState
            )
        }
    }

    private func calculateDuration() -> TimeInterval {
        guard let startTime = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }

    // MARK: - Public Methods - Statistics

    /// 获取当前会话统计
    func getSessionStats() -> SessionStats {
        let todayStats = statsEngine.getTodayStats()
        let currentRate = statsEngine.getBlinkRate(for: Date())
        let duration = state == .running ? calculateDuration() : sessionDuration

        return SessionStats(
            currentBlinkRate: Int(currentRate),
            totalBlinks: todayStats.totalBlinks,
            sessionDuration: duration,
            fatigueStatus: FatigueStatus(blinkRate: currentRate)
        )
    }
}

// MARK: - Supporting Types

/// 会话统计
struct SessionStats {
    let currentBlinkRate: Int
    let totalBlinks: Int
    let sessionDuration: TimeInterval
    let fatigueStatus: FatigueStatus
}

/// 眨眼检测器协议
protocol BlinkDetectorProtocol {
    func process(leftEye: [CGPoint], rightEye: [CGPoint], confidence: Double) -> BlinkResult
}

/// 视觉服务协议
protocol VisionServiceProtocol {
    var onFaceDetected: (([CGPoint], [CGPoint], Double) -> Void)? { get set }
    var onNoFaceDetected: (() -> Void)? { get set }
    func process(sampleBuffer: CMSampleBuffer)
}

/// 摄像头管理器协议
protocol CameraManagerProtocol {
    var onFrame: ((CMSampleBuffer) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }
    func start()
    func stop()
    func requestPermission(completion: @escaping (Bool) -> Void)
}

// MARK: - Notification Names

extension Notification.Name {
    static let sessionStateChanged = Notification.Name("com.eyeapp.sessionStateChanged")
}

// MARK: - BlinkDetector Protocol Conformance

extension BlinkDetector: BlinkDetectorProtocol {}

// MARK: - CameraManager Protocol Conformance

extension CameraManager: CameraManagerProtocol {}

// MARK: - VisionService Protocol Conformance

extension VisionService: VisionServiceProtocol {}
