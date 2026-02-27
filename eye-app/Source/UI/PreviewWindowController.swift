//
//  PreviewWindowController.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import SwiftUI
import AVFoundation

/// 独立预览窗口控制器
class PreviewWindowController: NSWindowController {

    // MARK: - Properties

    private let session: AVCaptureSession
    private var hostingView: NSHostingView<CameraPreviewView>?
    private var currentMirrored: Bool

    // MARK: - Initialization

    init(session: AVCaptureSession, isMirrored: Bool) {
        self.session = session
        self.currentMirrored = isMirrored

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 520),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "摄像头预览"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 320, height: 280)

        let previewView = CameraPreviewView(session: session, isMirrored: isMirrored)
        let hostingView = NSHostingView(rootView: previewView)
        window.contentView = hostingView
        self.hostingView = hostingView

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    /// 更新镜像设置
    func updateMirrored(_ isMirrored: Bool) {
        guard isMirrored != currentMirrored else { return }
        currentMirrored = isMirrored
        hostingView?.rootView = CameraPreviewView(session: session, isMirrored: isMirrored)
    }

    /// 显示窗口
    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
