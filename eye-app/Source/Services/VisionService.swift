//
//  VisionService.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import Foundation
import Vision
import AVFoundation
import CoreImage

/// Vision 服务 - 负责人脸和眼睛特征点检测
class VisionService {

    // MARK: - Properties

    private(set) var faceDetectionRequest: VNDetectFaceLandmarksRequest!
    private let processingQueue = DispatchQueue(label: "com.eyeapp.vision", qos: .userInteractive)

    /// 处理状态
    private(set) var isProcessing: Bool = false

    /// 置信度阈值
    var confidenceThreshold: Double = 0.5

    // MARK: - Callbacks

    /// 检测到人脸时的回调 (leftEye, rightEye, confidence)
    var onFaceDetected: (([CGPoint], [CGPoint], Double) -> Void)?

    /// 未检测到人脸时的回调
    var onNoFaceDetected: (() -> Void)?

    // MARK: - Initialization

    init() {
        setupFaceDetection()
    }

    // MARK: - Setup

    private func setupFaceDetection() {
        faceDetectionRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            self?.handleFaceDetection(request: request, error: error)
        }

        // 使用最新的检测版本
        faceDetectionRequest.revision = VNDetectFaceLandmarksRequestRevision3
    }

    // MARK: - Public Methods

    /// 处理 CVPixelBuffer
    /// - Parameter pixelBuffer: 来自摄像头的像素缓冲区
    func process(pixelBuffer: CVPixelBuffer) {
        guard !isProcessing else { return }
        isProcessing = true

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        processingQueue.async { [weak self] in
            do {
                try handler.perform([self?.faceDetectionRequest].compactMap { $0 })
            } catch {
                print("Vision request failed: \(error)")
                DispatchQueue.main.async {
                    self?.isProcessing = false
                    self?.onNoFaceDetected?()
                }
            }
        }
    }

    /// 处理 CMSampleBuffer
    /// - Parameter sampleBuffer: 来自摄像头的采样缓冲区
    func process(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            onNoFaceDetected?()
            return
        }
        process(pixelBuffer: pixelBuffer)
    }

    // MARK: - Private Methods

    private func handleFaceDetection(request: VNRequest, error: Error?) {
        defer {
            DispatchQueue.main.async { [weak self] in
                self?.isProcessing = false
            }
        }

        if let error = error {
            print("Face detection error: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.onNoFaceDetected?()
            }
            return
        }

        guard let observations = request.results as? [VNFaceObservation],
              let faceObservation = observations.first else {
            DispatchQueue.main.async { [weak self] in
                self?.onNoFaceDetected?()
            }
            return
        }

        // 检查置信度
        let confidence = Double(faceObservation.confidence)
        guard confidence >= confidenceThreshold else {
            DispatchQueue.main.async { [weak self] in
                self?.onNoFaceDetected?()
            }
            return
        }

        // 提取眼睛特征点
        guard let landmarks = faceObservation.landmarks else {
            DispatchQueue.main.async { [weak self] in
                self?.onNoFaceDetected?()
            }
            return
        }

        var leftEyePoints: [CGPoint] = []
        var rightEyePoints: [CGPoint] = []

        // 获取左眼特征点
        if let leftEye = landmarks.leftEye {
            leftEyePoints = convertNormalizedPoints(
                leftEye.normalizedPoints,
                in: faceObservation.boundingBox
            )
        }

        // 获取右眼特征点
        if let rightEye = landmarks.rightEye {
            rightEyePoints = convertNormalizedPoints(
                rightEye.normalizedPoints,
                in: faceObservation.boundingBox
            )
        }

        // 确保有足够的特征点
        guard leftEyePoints.count >= 6 && rightEyePoints.count >= 6 else {
            DispatchQueue.main.async { [weak self] in
                self?.onNoFaceDetected?()
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.onFaceDetected?(leftEyePoints, rightEyePoints, confidence)
        }
    }

    /// 将归一化坐标转换为实际坐标
    /// - Parameters:
    ///   - normalizedPoints: 归一化的特征点 (0-1)
    ///   - boundingBox: 人脸边界框
    /// - Returns: 转换后的坐标点数组
    private func convertNormalizedPoints(_ normalizedPoints: [CGPoint], in boundingBox: CGRect) -> [CGPoint] {
        return normalizedPoints.map { point in
            CGPoint(
                x: boundingBox.origin.x + point.x * boundingBox.width,
                y: boundingBox.origin.y + point.y * boundingBox.height
            )
        }
    }

    // MARK: - Reset

    /// 重置服务状态
    func reset() {
        isProcessing = false
    }
}
