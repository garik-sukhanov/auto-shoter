import Foundation
import ScreenCaptureKit
import AppKit
import CoreGraphics

/// Строчка в списке «что снимаем» — лёгкая обёртка, чтобы SwiftUI не таскал объекты ScreenCaptureKit.
struct CaptureTargetInfo: Identifiable, Hashable {
    enum Kind: Hashable { case display, window }

    let id: String
    let kind: Kind
    let title: String
    let detail: String
}

enum CaptureError: LocalizedError {
    case noPermission
    case targetNotFound
    case noTargetSelected

    var errorDescription: String? {
        switch self {
        case .noPermission:
            return "Нет доступа к записи экрана. Разрешите его в Системных настройках."
        case .targetNotFound:
            return "Выбранный экран или окно сейчас недоступны (окно закрыто или свёрнуто)."
        case .noTargetSelected:
            return "Не выбрано, что снимать."
        }
    }
}

/// Состояние доступа к записи экрана.
/// ScreenCaptureKit запоминает отказ на весь процесс: если права выдали уже после запуска,
/// система их подтверждает, а SCShareableContent всё равно отказывает — нужен перезапуск.
enum ScreenPermission: Equatable {
    case granted
    case denied
    case needsRestart
}

@MainActor
final class ScreenCatalog: ObservableObject {
    @Published private(set) var displayTargets: [CaptureTargetInfo] = []
    @Published private(set) var windowTargets: [CaptureTargetInfo] = []
    @Published private(set) var permission: ScreenPermission = .granted
    @Published private(set) var lastError: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isRequesting = false
    /// macOS показывает запрос на запись экрана один раз на решение.
    /// Если после нажатия ничего не изменилось — диалога уже не будет, помогут только настройки.
    @Published private(set) var promptSuppressed = false

    private var ownBundleID: String { Bundle.main.bundleIdentifier ?? "me.garik.autoshoter" }

    var allTargets: [CaptureTargetInfo] { displayTargets + windowTargets }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        // Запрос прав обязан идти ДО первого SCShareableContent: после первого отказа
        // система кэширует его на весь процесс и диалог уже не покажет.
        if !CGPreflightScreenCaptureAccess() {
            _ = await Task.detached { CGRequestScreenCaptureAccess() }.value
        }

        do {
            let content = try await Self.shareableContent()
            permission = .granted
            promptSuppressed = false
            lastError = nil

            displayTargets = content.displays.enumerated().map { index, display in
                CaptureTargetInfo(
                    id: Self.displayID(display),
                    kind: .display,
                    title: Self.displayName(display, index: index),
                    detail: "\(display.width) × \(display.height) pt"
                )
            }

            windowTargets = Self.usableWindows(in: content, excluding: ownBundleID).map { window in
                CaptureTargetInfo(
                    id: Self.windowID(window),
                    kind: .window,
                    title: window.title ?? "Без названия",
                    detail: window.owningApplication?.applicationName ?? "Неизвестное приложение"
                )
            }
        } catch {
            // Система уже говорит «доступ есть», а ScreenCaptureKit — нет: помогает только перезапуск.
            permission = CGPreflightScreenCaptureAccess() ? .needsRestart : .denied
            displayTargets = []
            windowTargets = []
            lastError = CaptureError.noPermission.localizedDescription
        }
    }

    /// Показывает системный запрос. Если решение уже принято, macOS просто вернёт его без диалога.
    func requestAccess() async {
        isRequesting = true
        _ = await Task.detached { CGRequestScreenCaptureAccess() }.value
        isRequesting = false
        await refresh()
        if permission == .denied { promptSuppressed = true }
    }

    /// Перезапуск — единственный надёжный способ подхватить только что выданное разрешение.
    func restartApp() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    /// Собирает фильтр для съёмки прямо перед снимком — список окон меняется на лету.
    func contentFilter(for targetID: String, excludeOwnApp: Bool) async throws -> SCContentFilter {
        guard !targetID.isEmpty else { throw CaptureError.noTargetSelected }

        let content: SCShareableContent
        do {
            content = try await Self.shareableContent()
        } catch {
            throw CaptureError.noPermission
        }

        if targetID.hasPrefix("display:") {
            guard let display = content.displays.first(where: { Self.displayID($0) == targetID }) else {
                throw CaptureError.targetNotFound
            }
            let excluded = excludeOwnApp
                ? content.applications.filter { $0.bundleIdentifier == ownBundleID }
                : []
            return SCContentFilter(display: display, excludingApplications: excluded, exceptingWindows: [])
        }

        guard let window = Self.matchWindow(targetID, in: content, excluding: ownBundleID) else {
            throw CaptureError.targetNotFound
        }
        return SCContentFilter(desktopIndependentWindow: window)
    }

    func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Идентификаторы

    private static func shareableContent() async throws -> SCShareableContent {
        try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
    }

    private static func displayID(_ display: SCDisplay) -> String {
        "display:\(display.displayID)"
    }

    private static func displayName(_ display: SCDisplay, index: Int) -> String {
        let screen = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID
        }
        return screen?.localizedName ?? "Экран \(index + 1)"
    }

    /// windowID меняется при пересоздании окна, поэтому храним ещё bundleID и заголовок как запасной ключ.
    private static func windowID(_ window: SCWindow) -> String {
        let bundle = window.owningApplication?.bundleIdentifier ?? "?"
        let title = window.title ?? ""
        return "window:\(window.windowID)|\(bundle)|\(title)"
    }

    private static func usableWindows(in content: SCShareableContent, excluding ownBundleID: String) -> [SCWindow] {
        content.windows
            .filter { window in
                guard let app = window.owningApplication, app.bundleIdentifier != ownBundleID else { return false }
                guard let title = window.title, !title.isEmpty else { return false }
                return window.frame.width >= 100 && window.frame.height >= 100
            }
            .sorted {
                let left = ($0.owningApplication?.applicationName ?? "", $0.title ?? "")
                let right = ($1.owningApplication?.applicationName ?? "", $1.title ?? "")
                return left < right
            }
    }

    private static func matchWindow(_ targetID: String, in content: SCShareableContent, excluding ownBundleID: String) -> SCWindow? {
        let parts = targetID.dropFirst("window:".count).split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        let rawID = CGWindowID(parts[0]) ?? 0
        let bundle = String(parts[1])
        let title = String(parts[2])

        let candidates = usableWindows(in: content, excluding: ownBundleID)
        if let exact = candidates.first(where: { $0.windowID == rawID }) { return exact }
        if let byTitle = candidates.first(where: {
            $0.owningApplication?.bundleIdentifier == bundle && $0.title == title
        }) { return byTitle }
        return candidates.first { $0.owningApplication?.bundleIdentifier == bundle }
    }
}
