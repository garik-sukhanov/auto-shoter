import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var catalog: ScreenCatalog
    @EnvironmentObject private var session: SessionController
    @EnvironmentObject private var estimator: PreviewEstimator

    var body: some View {
        VStack(spacing: 0) {
            if catalog.permission != .granted {
                permissionBanner
            }

            Form {
                Group {
                    TargetSection(settings: settings, catalog: catalog) {
                        estimator.request()
                    }
                    ScheduleSection(settings: settings) {
                        // вес часа съёмки зависит от интервала — пересчитывать кадр не нужно
                    }
                    StorageSection(settings: settings)
                    QualitySection(settings: settings, estimator: estimator)
                }
                .disabled(session.isRunning)

                // Журнал остаётся живым во время съёмки, иначе его не пролистать.
                LogSection(session: session)
            }
            .formStyle(.grouped)

            Divider()

            RunPanel(session: session)
                .padding(12)
        }
        .frame(minWidth: 520, minHeight: 640)
        .task {
            await catalog.refresh()
            estimator.request(debounce: .milliseconds(100))
        }
    }

    private var permissionBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: catalog.permission == .needsRestart ? "arrow.clockwise.circle" : "lock.shield")
                .foregroundStyle(.orange)
                .imageScale(.large)

            VStack(alignment: .leading, spacing: 6) {
                Text(bannerTitle)
                    .fontWeight(.semibold)

                Text(bannerDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    switch catalog.permission {
                    case .needsRestart:
                        Button("Перезапустить") { catalog.restartApp() }
                            .buttonStyle(.borderedProminent)
                    case .denied where catalog.promptSuppressed:
                        Button("Открыть настройки") { catalog.openScreenRecordingSettings() }
                            .buttonStyle(.borderedProminent)
                        Button("Перезапустить") { catalog.restartApp() }
                    case .denied, .granted:
                        Button("Запросить доступ") {
                            Task { await catalog.requestAccess() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(catalog.isRequesting)
                        Button("Открыть настройки") { catalog.openScreenRecordingSettings() }
                    }

                    Button("Проверить снова") {
                        Task {
                            await catalog.refresh()
                            estimator.request()
                        }
                    }
                    .disabled(catalog.isRefreshing || catalog.isRequesting)

                    if catalog.isRefreshing || catalog.isRequesting {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.orange.opacity(0.12))
    }

    private var bannerTitle: String {
        switch catalog.permission {
        case .granted: return ""
        case .needsRestart: return "Доступ выдан — нужен перезапуск"
        case .denied: return catalog.promptSuppressed
            ? "macOS больше не спросит — нужно включить вручную"
            : "Нет доступа к записи экрана"
        }
    }

    private var bannerDescription: String {
        switch catalog.permission {
        case .granted:
            return ""
        case .needsRestart:
            return "Система уже разрешила запись, но ScreenCaptureKit узнает об этом только в новом процессе."
        case .denied where catalog.promptSuppressed:
            return """
            Решение по AutoShoter у системы уже записано, поэтому диалог не появляется. \
            Откройте «Запись экрана», выключите и снова включите переключатель у AutoShoter \
            (если приложение пересобиралось — удалите его кнопкой «−» и добавьте заново), затем перезапустите AutoShoter.
            """
        case .denied:
            return "Нажмите «Запросить доступ» — macOS покажет диалог. Если диалога нет, включите AutoShoter вручную в настройках."
        }
    }
}
