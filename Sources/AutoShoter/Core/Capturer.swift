import Foundation
import ScreenCaptureKit
import CoreGraphics

enum Capturer {
    /// Один кадр по готовому фильтру. scale — доля от нативного разрешения (0.25…1.0).
    static func capture(filter: SCContentFilter, scale: Double, showsCursor: Bool) async throws -> CGImage {
        let config = SCStreamConfiguration()
        let pixelScale = CGFloat(filter.pointPixelScale)
        let rect = filter.contentRect

        config.width = max(1, Int((rect.width * pixelScale * scale).rounded()))
        config.height = max(1, Int((rect.height * pixelScale * scale).rounded()))
        config.showsCursor = showsCursor
        config.captureResolution = .best
        config.scalesToFit = true
        config.colorSpaceName = CGColorSpace.sRGB

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
}
