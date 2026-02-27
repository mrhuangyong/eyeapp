//
//  ErrorView.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import SwiftUI
import Combine

/// 错误类型
struct AppError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let canRetry: Bool
    let icon: String
    let color: Color
    let action: ErrorAction

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.id == rhs.id
    }
}

/// 错误操作
enum ErrorAction {
    case requestPermission
    case openSettings
    case restartCamera
    case dismiss
}

// MARK: - Error Factory

extension AppError {

    /// 摄像头权限被拒绝
    static func cameraPermissionDenied() -> AppError {
        AppError(
            title: "需要摄像头权限",
            message: "EyeApp 需要访问摄像头来检测眨眼频率。\n请在系统设置中允许摄像头访问。",
            canRetry: true,
            icon: "camera.fill",
            color: .red,
            action: .openSettings
        )
    }

    /// 摄像头不可用
    static func cameraUnavailable() -> AppError {
        AppError(
            title: "摄像头不可用",
            message: "无法访问摄像头设备。\n请检查摄像头是否连接或被其他应用占用。",
            canRetry: true,
            icon: "video.slash",
            color: .orange,
            action: .restartCamera
        )
    }

    /// 未找到摄像头
    static func cameraNotFound() -> AppError {
        AppError(
            title: "未找到摄像头",
            message: "您的 Mac 没有可用的摄像头设备。\n请连接外部摄像头后重试。",
            canRetry: true,
            icon: "video.badge.exclamationmark",
            color: .orange,
            action: .restartCamera
        )
    }

    /// 低光环境
    static func lowLightCondition() -> AppError {
        AppError(
            title: "光线不足",
            message: "当前环境光线较弱，检测精度可能下降。\n建议改善照明条件以获得更好的检测效果。",
            canRetry: false,
            icon: "lightbulb.slash",
            color: .yellow,
            action: .dismiss
        )
    }

    /// 人脸检测失败
    static func faceDetectionFailed() -> AppError {
        AppError(
            title: "人脸检测失败",
            message: "无法检测到人脸。\n请确保您正对摄像头，并且脸部清晰可见。",
            canRetry: true,
            icon: "person.crop.circle.badge.questionmark",
            color: .yellow,
            action: .dismiss
        )
    }

    /// 通用错误
    static func generic(_ message: String) -> AppError {
        AppError(
            title: "发生错误",
            message: message,
            canRetry: true,
            icon: "exclamationmark.triangle",
            color: .red,
            action: .dismiss
        )
    }
}

// MARK: - Error View

struct ErrorView: View {

    let error: AppError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: error.icon)
                .font(.system(size: 50))
                .foregroundColor(error.color)

            // 标题
            Text(error.title)
                .font(.headline)

            // 消息
            Text(error.message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // 操作按钮
            HStack(spacing: 10) {
                if error.canRetry && onRetry != nil {
                    Button(action: {
                        onRetry?()
                        onDismiss()
                    }) {
                        Text("重试")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button(action: onDismiss) {
                    Text("关闭")
                }
                .buttonStyle(.bordered)

                if error.action == .openSettings {
                    Button("打开设置") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                            NSWorkspace.shared.open(url)
                        }
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

// MARK: - Error Alert Modifier

struct ErrorAlert: ViewModifier {

    @Binding var error: AppError?
    let onRetry: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .alert(item: $error) { error in
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    primaryButton: error.canRetry && onRetry != nil
                        ? .default(Text("重试"), action: {
                            onRetry?()
                        })
                        : .cancel(),
                    secondaryButton: .cancel(Text("关闭"))
                )
            }
    }
}

extension View {
    func errorAlert(error: Binding<AppError?>, onRetry: (() -> Void)? = nil) -> some View {
        modifier(ErrorAlert(error: error, onRetry: onRetry))
    }
}

// MARK: - Error Manager

/// 错误管理器 - 统一处理应用错误
class ErrorManager: ObservableObject {

    @Published var currentError: AppError?

    private var onRetryAction: (() -> Void)?

    /// 显示错误
    func show(_ error: AppError, onRetry: (() -> Void)? = nil) {
        self.onRetryAction = onRetry
        self.currentError = error
    }

    /// 显示摄像头权限错误
    func showCameraPermissionError() {
        show(.cameraPermissionDenied())
    }

    /// 显示摄像头不可用错误
    func showCameraUnavailableError(onRetry: (() -> Void)? = nil) {
        show(.cameraUnavailable(), onRetry: onRetry)
    }

    /// 显示低光警告
    func showLowLightWarning() {
        show(.lowLightCondition())
    }

    /// 显示人脸检测失败
    func showFaceDetectionError() {
        show(.faceDetectionFailed())
    }

    /// 清除错误
    func clear() {
        currentError = nil
        onRetryAction = nil
    }

    /// 执行重试
    func retry() {
        onRetryAction?()
        clear()
    }
}

// MARK: - Preview

#Preview {
    ErrorView(
        error: .cameraPermissionDenied(),
        onRetry: { print("Retry") },
        onDismiss: { print("Dismiss") }
    )
}

#Preview("Low Light") {
    ErrorView(
        error: .lowLightCondition(),
        onRetry: nil,
        onDismiss: { print("Dismiss") }
    )
}
