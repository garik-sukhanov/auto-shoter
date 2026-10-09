import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum EncodeError: LocalizedError {
    case destinationFailed(ImageFormat)
    case writeFailed(ImageFormat)

    var errorDescription: String? {
        switch self {
        case .destinationFailed(let f): return "Система не умеет писать \(f.title) на этой машине."
        case .writeFailed(let f): return "Не удалось закодировать снимок в \(f.title)."
        }
    }
}

enum ImageEncoder {
    static func encode(_ image: CGImage, format: ImageFormat, quality: Double) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            format.utType.identifier as CFString,
            1,
            nil
        ) else {
            throw EncodeError.destinationFailed(format)
        }

        var options: [CFString: Any] = [:]
        if format.supportsQuality {
            options[kCGImageDestinationLossyCompressionQuality] = min(max(quality, 0.05), 1.0)
        }

        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw EncodeError.writeFailed(format)
        }
        return data as Data
    }
}
