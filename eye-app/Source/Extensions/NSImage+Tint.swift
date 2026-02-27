//
//  NSImage+Tint.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import AppKit

// MARK: - Constants

/// 图标占圆形背景的比例，留出适当边距
private let iconToBackgroundRatio: CGFloat = 0.78

extension NSImage {
    /// 为图像着色
    /// - Parameter color: 目标颜色
    /// - Returns: 着色后的图像
    func tinted(with color: NSColor) -> NSImage {
        guard let image = self.copy() as? NSImage else {
            return self
        }
        image.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }

    /// 创建复合图像（彩色背景 + 白色图标）
    /// - Parameters:
    ///   - backgroundColor: 背景颜色
    ///   - iconSize: 图标尺寸
    /// - Returns: 复合图像
    func composite(withBackgroundColor backgroundColor: NSColor, iconSize: NSSize) -> NSImage {
        let totalSize = iconSize

        let compositeImage = NSImage(size: totalSize)
        compositeImage.lockFocus()

        // 1. 绘制圆形背景
        let circleRect = NSRect(origin: .zero, size: totalSize)
        let circlePath = NSBezierPath(ovalIn: circleRect)
        backgroundColor.setFill()
        circlePath.fill()

        // 2. 绘制白色图标（居中）
        let whiteIcon = self.tinted(with: .white)
        let iconDrawSize = NSSize(
            width: totalSize.width * iconToBackgroundRatio,
            height: totalSize.height * iconToBackgroundRatio
        )
        let iconOrigin = NSPoint(
            x: (totalSize.width - iconDrawSize.width) / 2,
            y: (totalSize.height - iconDrawSize.height) / 2
        )
        whiteIcon.draw(at: iconOrigin, from: NSRect(origin: .zero, size: self.size), operation: .sourceOver, fraction: 1.0)

        compositeImage.unlockFocus()

        return compositeImage
    }
}
