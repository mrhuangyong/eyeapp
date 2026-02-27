//
//  CameraPreviewView.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import SwiftUI
import AVFoundation

/// 摄像头预览视图 - 使用 NSViewController
struct CameraPreviewView: NSViewControllerRepresentable {

    let session: AVCaptureSession
    var isMirrored: Bool = true

    func makeNSViewController(context: Context) -> CameraPreviewViewController {
        let controller = CameraPreviewViewController()
        controller.configure(session: session, isMirrored: isMirrored)
        return controller
    }

    func updateNSViewController(_ controller: CameraPreviewViewController, context: Context) {
        controller.updateMirrored(isMirrored)
    }
}

// MARK: - View Controller

class CameraPreviewViewController: NSViewController {

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureSession: AVCaptureSession?
    private var isMirrored: Bool = true

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupPreviewLayer()
    }

    func configure(session: AVCaptureSession, isMirrored: Bool) {
        self.captureSession = session
        self.isMirrored = isMirrored
    }

    private func setupPreviewLayer() {
        guard let session = captureSession else { return }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds

        // 先禁用自动镜像调整，再设置镜像
        if let connection = layer.connection {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
        }

        view.layer = layer
        previewLayer = layer
    }

    func updateMirrored(_ isMirrored: Bool) {
        guard isMirrored != self.isMirrored else { return }
        self.isMirrored = isMirrored

        if let connection = previewLayer?.connection {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        previewLayer?.frame = view.bounds
    }
}

// MARK: - Preview Placeholder

/// 预览占位视图 - 当摄像头不可用时显示
struct CameraPreviewPlaceholder: View {

    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.1))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        CameraPreviewPlaceholder(message: "摄像头未授权\n请在系统设置中允许访问摄像头")
            .frame(width: 240, height: 180)
            .cornerRadius(8)

        CameraPreviewPlaceholder(message: "未找到摄像头设备")
            .frame(width: 640, height: 480)
            .cornerRadius(8)
    }
    .padding()
}
