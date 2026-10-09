import SwiftUI
import AppKit

@main
struct AutoShoterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    @StateObject private var settings: AppSettings
    @StateObject private var catalog: ScreenCatalog
    @StateObject private var session: SessionController
    @StateObject private var estimator: PreviewEstimator

    init() {
        let settings = AppSettings.shared
        let catalog = ScreenCatalog()
        _settings = StateObject(wrappedValue: settings)
        _catalog = StateObject(wrappedValue: catalog)
        _session = StateObject(wrappedValue: SessionController(settings: settings, catalog: catalog))
        _estimator = StateObject(wrappedValue: PreviewEstimator(settings: settings, catalog: catalog))
    }

    var body: some Scene {
        Window("AutoShoter", id: "main") {
            ContentView()
                .environmentObject(settings)
                .environmentObject(catalog)
                .environmentObject(session)
                .environmentObject(estimator)
        }
        .defaultSize(width: 560, height: 780)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra {
            MenuBarContent(session: session, settings: settings)
        } label: {
            Image(systemName: session.isPaused ? "pause.circle" : (session.isRunning ? "camera.fill" : "camera"))
        }
    }
}

private struct MenuBarContent: View {
    @ObservedObject var session: SessionController
    @ObservedObject var settings: AppSettings
    @Environment(\.openWindow) private var openWindow

    private var menuTitle: String {
        guard session.isRunning else { return "Остановлено" }
        let head = session.isPaused ? "Пауза" : "Идёт съёмка"
        return "\(head) · \(session.shotCount) шт · \(session.totalBytesText) · \(SessionPlan.durationText(session.elapsed))"
    }

    var body: some View {
        Text(menuTitle)

        Divider()

        Button(session.isRunning ? "Остановить" : "Начать съёмку") {
            session.toggle()
        }

        Button(session.isPaused ? "Продолжить" : "Пауза") {
            session.togglePause()
        }
        .disabled(!session.isRunning)

        Button("Показать в Finder") { session.revealInFinder() }
            .disabled(session.sessionDirectory == nil)

        Button("Открыть окно AutoShoter") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }

        Divider()

        Button("Выйти") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
