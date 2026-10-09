import Foundation
import UniformTypeIdentifiers

enum ImageFormat: String, CaseIterable, Identifiable {
    case jpeg
    case heic
    case png

    var id: String { rawValue }

    var title: String {
        switch self {
        case .jpeg: return "JPEG"
        case .heic: return "HEIC"
        case .png: return "PNG"
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .heic: return "heic"
        case .png: return "png"
        }
    }

    var utType: UTType {
        switch self {
        case .jpeg: return .jpeg
        case .heic: return .heic
        case .png: return .png
        }
    }

    /// PNG сжимается без потерь — ползунок качества к нему неприменим.
    var supportsQuality: Bool { self != .png }

    var hint: String {
        switch self {
        case .jpeg: return "Универсально, открывается везде."
        case .heic: return "Примерно вдвое легче JPEG при том же качестве, но не везде открывается."
        case .png: return "Без потерь: текст идеально чёткий, вес в разы больше."
        }
    }
}
