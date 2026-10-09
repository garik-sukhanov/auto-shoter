import Foundation
import AppKit
import SwiftUI

/// Делает пробный кадр текущими настройками и показывает реальный вес файла.
/// «Примерный» он только в том смысле, что следующий кадр будет другим по содержимому.
@MainActor
final class PreviewEstimator: ObservableObject {
    @Published private(set) var thumbnail: NSImage?
    @Published private(set) var bytes: Int?
    @Published private(set) var pixelWidth: Int?
    @Published private(set) var pixelHeight: Int?
    @Published private(set) var isWorking = false
    @Published private(set) var error: String?

    private let settings: AppSettings
    private let catalog: ScreenCatalog
    private var pending: Task<Void, Never>?
    /// Последний захваченный кадр: при смене формата или качества хватит перекодировать его.
    private var cachedImage: CGImage?

    init(settings: AppSettings, catalog: ScreenCatalog) {
        self.settings = settings
        self.catalog = catalog
    }

    var sizeText: String {
        guard let bytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    var dimensionsText: String {
        guard let pixelWidth, let pixelHeight else { return "—" }
        return "\(pixelWidth) × \(pixelHeight) px"
    }

    /// Вес всей запланированной сессии.
    func totalText(shots: Int) -> String {
        guard let bytes, shots > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes) * Int64(shots), countStyle: .file)
    }

    /// Вес часа съёмки текущим интервалом — самое полезное число при выборе качества.
    func hourlyText(intervalSeconds: Double) -> String {
        guard let bytes, intervalSeconds >= 1 else { return "—" }
        let perHour = Int64(Double(bytes) * (3600.0 / intervalSeconds))
        return ByteCountFormatter.string(fromByteCount: perHour, countStyle: .file)
    }

    /// Дебаунс: пользователь возит ползунок качества, а мы не дёргаем захват на каждый пиксель.
    /// recapture = false — переиспользовать прошлый кадр (меняется только кодирование).
    func request(recapture: Bool = true, debounce: Duration = .milliseconds(400)) {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            await self?.run(recapture: recapture)
        }
    }

    func cancel() {
        pending?.cancel()
        pending = nil
    }

    private func run(recapture: Bool) async {
        guard !settings.targetID.isEmpty else {
            reset()
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            let image: CGImage
            if !recapture, let cached = cachedImage {
                image = cached
            } else {
                let filter = try await catalog.contentFilter(
                    for: settings.targetID,
                    excludeOwnApp: settings.excludeOwnWindow
                )
                image = try await Capturer.capture(
                    filter: filter,
                    scale: settings.scalePercent / 100,
                    showsCursor: settings.showsCursor
                )
                cachedImage = image
            }
            guard !Task.isCancelled else { return }

            let data = try ImageEncoder.encode(image, format: settings.format, quality: settings.quality)
            bytes = data.count
            pixelWidth = image.width
            pixelHeight = image.height
            thumbnail = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            error = nil
        } catch {
            self.error = error.localizedDescription
            reset()
        }
    }

    private func reset() {
        cachedImage = nil
        thumbnail = nil
        bytes = nil
        pixelWidth = nil
        pixelHeight = nil
    }
}
