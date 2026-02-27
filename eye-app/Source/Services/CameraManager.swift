//
//  CameraManager.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import Foundation
import AVFoundation

/// 摄像头状态
enum CameraState: Equatable {
    case idle
    case starting
    case running
    case stopped
    case error(CameraError)

    var description: String {
        switch self {
        case .idle: return "空闲"
        case .starting: return "启动中"
        case .running: return "运行中"
        case .stopped: return "已停止"
        case .error(let error): return "错误: \(error.localizedDescription)"
        }
    }

    static func == (lhs: CameraState, rhs: CameraState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.starting, .starting),
             (.running, .running),
             (.stopped, .stopped):
            return true
        case (.error(let l), .error(let r)):
            return l.localizedDescription == r.localizedDescription
        default:
            return false
        }
    }
}

/// 摄像头错误
enum CameraError: Error, LocalizedError {
    case cameraNotFound
    case cannotAddInput
    case cannotAddOutput
    case permissionDenied
    case sessionNotRunning

    var errorDescription: String? {
        switch self {
        case .cameraNotFound: return "未找到摄像头设备"
        case .cannotAddInput: return "无法添加摄像头输入"
        case .cannotAddOutput: return "无法添加视频输出"
        case .permissionDenied: return "摄像头权限被拒绝"
        case .sessionNotRunning: return "摄像头会话未运行"
        }
    }
}

/// 摄像头管理器 - 负责摄像头生命周期和帧捕获
class CameraManager: NSObject {

    // MARK: - Properties

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let sessionQueue = DispatchQueue(label: "com.eyeapp.camera", qos: .userInteractive)

    /// 当前状态
    private(set) var state: CameraState = .idle {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.onStateChanged?(self.state)
            }
        }
    }

    /// 帧率 (FPS)
    var frameRate: Int = 30

    // MARK: - Callbacks

    /// 收到视频帧时的回调
    var onFrame: ((CMSampleBuffer) -> Void)?

    /// 发生错误时的回调
    var onError: ((Error) -> Void)?

    /// 状态变化时的回调
    var onStateChanged: ((CameraState) -> Void)?

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// 请求摄像头权限
    /// - Parameter completion: 权限请求完成回调
    func requestPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    /// 启动摄像头
    func start() {
        guard state == .idle || state == .stopped else { return }

        state = .starting

        requestPermission { [weak self] granted in
            guard let self = self else { return }

            if granted {
                self.sessionQueue.async {
                    self.setupCaptureSession()
                }
            } else {
                DispatchQueue.main.async {
                    self.state = .error(.permissionDenied)
                    self.onError?(CameraError.permissionDenied)
                }
            }
        }
    }

    /// 停止摄像头
    func stop() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()

            DispatchQueue.main.async {
                self?.state = .stopped
            }
        }
    }

    // MARK: - Private Methods

    private func setupCaptureSession() {
        let session = AVCaptureSession()

        // 配置会话预设
        if session.canSetSessionPreset(.medium) {
            session.sessionPreset = .medium
        }

        // 获取摄像头设备
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified) else {
            DispatchQueue.main.async {
                self.state = .error(.cameraNotFound)
                self.onError?(CameraError.cameraNotFound)
            }
            return
        }

        do {
            // 配置摄像头输入
            let input = try AVCaptureDeviceInput(device: camera)

            guard session.canAddInput(input) else {
                throw CameraError.cannotAddInput
            }
            session.addInput(input)

            // 配置视频输出
            let output = AVCaptureVideoDataOutput()

            // 配置帧格式
            let pixelFormat: OSType = kCVPixelFormatType_32BGRA
            let availableFormats = output.availableVideoPixelFormatTypes
            var formatFound = false
            for format in availableFormats {
                if format == pixelFormat {
                    output.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: pixelFormat
                    ]
                    formatFound = true
                    break
                }
            }

            if !formatFound && !availableFormats.isEmpty {
                output.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: availableFormats[0]
                ]
            }

            // 设置代理和队列
            output.setSampleBufferDelegate(self, queue: sessionQueue)
            output.alwaysDiscardsLateVideoFrames = true

            guard session.canAddOutput(output) else {
                throw CameraError.cannotAddOutput
            }
            session.addOutput(output)

            // 配置帧率
            configureFrameRate(for: camera, session: session)

            // 保存引用
            self.videoOutput = output
            self.captureSession = session

            // 启动会话
            session.startRunning()

            DispatchQueue.main.async {
                self.state = .running
            }

        } catch {
            DispatchQueue.main.async {
                if let cameraError = error as? CameraError {
                    self.state = .error(cameraError)
                } else {
                    self.state = .error(.cannotAddInput)
                }
                self.onError?(error)
            }
        }
    }

    private func configureFrameRate(for device: AVCaptureDevice, session: AVCaptureSession) {
        do {
            try device.lockForConfiguration()

            let targetFrameRate = Double(frameRate)
            var bestFormat: AVCaptureDevice.Format?
            var bestFrameRateRange: AVFrameRateRange?

            for format in device.formats {
                for range in format.videoSupportedFrameRateRanges {
                    if range.maxFrameRate >= targetFrameRate && range.minFrameRate <= targetFrameRate {
                        // Prefer formats that exactly match or are closest to target
                        if bestFrameRateRange == nil ||
                           abs(range.maxFrameRate - targetFrameRate) < abs(bestFrameRateRange!.maxFrameRate - targetFrameRate) {
                            bestFormat = format
                            bestFrameRateRange = range
                        }
                    }
                }
            }

            if let format = bestFormat {
                device.activeFormat = format
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
            }

            device.unlockForConfiguration()
        } catch {
            print("Failed to configure frame rate: \(error)")
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 验证帧有效性
        guard CMSampleBufferIsValid(sampleBuffer) else { return }

        // 通知主线程
        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(sampleBuffer)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 帧被丢弃，可以记录日志
        #if DEBUG
        let reason = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_DroppedFrameReason, attachmentModeOut: nil)
        print("Frame dropped: \(String(describing: reason))")
        #endif
    }
}
