import Foundation
import AppKit
import SwiftUI

@MainActor
final class SessionController: ObservableObject {
    struct LogEntry: Identifiable {
        let id = UUID()
        let date: Date
        let text: String
        let isError: Bool
    }

    /// Сессия активна (идёт съёмка или стоит на паузе).
    @Published private(set) var isRunning = false
    /// Пауза — это остановка цикла без закрытия сессии: папка, счётчики и нумерация сохраняются.
    @Published private(set) var isPaused = false
    @Published private(set) var shotCount = 0
    @Published private(set) var totalBytes: Int64 = 0
    @Published private(set) var lastShotURL: URL?
    @Published private(set) var sessionDirectory: URL?
    @Published private(set) var nextShotDate: Date?
    @Published private(set) var log: [LogEntry] = []

    private var loop: Task<Void, Never>?
    private let settings: AppSettings
    private let catalog: ScreenCatalog

    /// Время считаем по отрезкам работы: пауза в длительность сессии не входит.
    private var accumulated: TimeInterval = 0
    private var segmentStart: Date?
    /// Момент остановки для режима «в заданное время» — фиксируем на старте, чтобы не плыл.
    private var clockDeadline: Date?

    init(settings: AppSettings, catalog: ScreenCatalog) {
        self.settings = settings
        self.catalog = catalog
    }

    var totalBytesText: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    var elapsed: TimeInterval {
        accumulated + (segmentStart.map { Date().timeIntervalSince($0) } ?? 0)
    }

    // MARK: - Управление

    func toggle() { isRunning ? stop() : start() }

    func start() {
        guard !isRunning else { return }
        guard !settings.targetID.isEmpty else {
            append(CaptureError.noTargetSelected.localizedDescription, isError: true)
            return
        }

        let startDate = Date()
        let directory = StorageLayout.sessionDirectory(
            base: settings.baseFolderURL,
            useRootFolder: settings.useRootFolder,
            groupByDate: settings.groupByDate,
            useSessionFolder: settings.useSessionFolder,
            sessionName: settings.sessionName,
            start: startDate
        )

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            append("Не удалось создать папку: \(error.localizedDescription)", isError: true)
            return
        }

        sessionDirectory = directory
        shotCount = 0
        totalBytes = 0
        lastShotURL = nil
        log = []
        accumulated = 0
        segmentStart = startDate
        clockDeadline = settings.stopMode == .clock
            ? SessionPlan.nextOccurrence(minuteOfDay: settings.stopAtMinuteOfDay, from: startDate)
            : nil
        isPaused = false
        isRunning = true

        append("Сессия начата → \(directory.path)")
        if let deadline = clockDeadline {
            append("Остановка запланирована на \(Self.timeFormatter.string(from: deadline)).")
        }

        loop = Task { [weak self] in await self?.run() }
    }

    func pause() {
        guard isRunning, !isPaused else { return }
        loop?.cancel()
        loop = nil
        closeSegment()
        isPaused = true
        nextShotDate = nil
        append("Пауза. Снято \(shotCount), объём \(totalBytesText).")
    }

    func resume() {
        guard isRunning, isPaused else { return }
        isPaused = false
        segmentStart = Date()
        append("Съёмка продолжена.")
        loop = Task { [weak self] in await self?.run() }
    }

    func togglePause() { isPaused ? resume() : pause() }

    func stop(reason: String? = nil) {
        loop?.cancel()
        loop = nil
        guard isRunning else { return }
        closeSegment()
        isRunning = false
        isPaused = false
        nextShotDate = nil
        clockDeadline = nil
        append(reason ?? "Сессия остановлена. Снимков: \(shotCount), объём: \(totalBytesText), длительность: \(SessionPlan.durationText(elapsed)).")
    }

    func revealInFinder() {
        guard let directory = sessionDirectory ?? existingBaseFolder() else { return }
        if let last = lastShotURL, FileManager.default.fileExists(atPath: last.path) {
            NSWorkspace.shared.activateFileViewerSelecting([last])
        } else {
            NSWorkspace.shared.open(directory)
        }
    }

    private func closeSegment() {
        if let start = segmentStart {
            accumulated += Date().timeIntervalSince(start)
            segmentStart = nil
        }
    }

    private func existingBaseFolder() -> URL? {
        let base = settings.baseFolderURL
        return FileManager.default.fileExists(atPath: base.path) ? base : nil
    }

    // MARK: - Цикл

    private func run() async {
        var next = Date()
        while !Task.isCancelled {
            await shoot()
            guard isRunning, !isPaused else { return }

            if let reason = limitReached() {
                stop(reason: reason)
                return
            }

            let interval = max(1, settings.intervalSeconds)
            next = next.addingTimeInterval(interval)
            if next.timeIntervalSinceNow < 0 { next = Date().addingTimeInterval(interval) }

            // Дедлайн раньше следующего кадра — ждём именно его, а не лишний снимок.
            if let deadline = deadline(), deadline < next {
                nextShotDate = nil
                await sleep(until: deadline)
                guard !Task.isCancelled else { return }
                stop(reason: limitReached() ?? "Сессия остановлена по расписанию.")
                return
            }

            nextShotDate = next
            await sleep(until: next)
        }
    }

    private func sleep(until date: Date) async {
        let delay = date.timeIntervalSinceNow
        guard delay > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    /// Момент, когда сессия должна закончиться, если он известен заранее.
    private func deadline() -> Date? {
        switch settings.stopMode {
        case .never, .shots:
            return nil
        case .duration:
            let left = max(0, settings.stopAfterMinutes * 60) - elapsed
            return Date().addingTimeInterval(max(0, left))
        case .clock:
            return clockDeadline
        }
    }

    /// Текст причины, если условие остановки выполнено.
    private func limitReached() -> String? {
        switch settings.stopMode {
        case .never:
            return nil
        case .shots:
            let limit = max(1, settings.maxShots)
            guard shotCount >= limit else { return nil }
            return "Готово: снято \(SessionPlan.shotsText(shotCount)) из \(limit). Объём: \(totalBytesText)."
        case .duration:
            guard elapsed >= max(0, settings.stopAfterMinutes * 60) else { return nil }
            return "Готово: прошло \(SessionPlan.durationText(elapsed)). Снимков: \(shotCount), объём: \(totalBytesText)."
        case .clock:
            guard let deadline = clockDeadline, Date() >= deadline else { return nil }
            return "Готово: наступило \(Self.timeFormatter.string(from: deadline)). Снимков: \(shotCount), объём: \(totalBytesText)."
        }
    }

    private func shoot() async {
        do {
            let filter = try await catalog.contentFilter(
                for: settings.targetID,
                excludeOwnApp: settings.excludeOwnWindow
            )
            let image = try await Capturer.capture(
                filter: filter,
                scale: settings.scalePercent / 100,
                showsCursor: settings.showsCursor
            )
            let data = try ImageEncoder.encode(image, format: settings.format, quality: settings.quality)

            guard let directory = sessionDirectory else { return }
            let now = Date()
            let url = directory.appendingPathComponent(
                StorageLayout.fileName(
                    index: shotCount + 1,
                    date: now,
                    prefix: settings.filePrefix,
                    ext: settings.format.fileExtension
                )
            )
            try data.write(to: url, options: .atomic)

            shotCount += 1
            totalBytes += Int64(data.count)
            lastShotURL = url
            let size = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
            append("\(url.lastPathComponent) · \(image.width)×\(image.height) · \(size)")
        } catch {
            append(error.localizedDescription, isError: true)
        }
    }

    private func append(_ text: String, isError: Bool = false) {
        log.insert(LogEntry(date: Date(), text: text, isError: isError), at: 0)
        if log.count > 200 { log.removeLast(log.count - 200) }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
