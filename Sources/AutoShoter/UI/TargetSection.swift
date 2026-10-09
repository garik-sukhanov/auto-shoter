import SwiftUI

struct TargetSection: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var catalog: ScreenCatalog
    var onTargetChange: () -> Void

    @State private var kind: CaptureTargetInfo.Kind = .display

    private var targets: [CaptureTargetInfo] {
        kind == .display ? catalog.displayTargets : catalog.windowTargets
    }

    var body: some View {
        Section("Что снимаем") {
            Picker("", selection: $kind) {
                Text("Экран").tag(CaptureTargetInfo.Kind.display)
                Text("Окно").tag(CaptureTargetInfo.Kind.window)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack {
                Picker("Источник", selection: $settings.targetID) {
                    if targets.isEmpty {
                        Text(kind == .display ? "Экраны не найдены" : "Подходящих окон нет").tag("")
                    }
                    ForEach(targets) { target in
                        Text(verbatim: "\(target.title) — \(target.detail)").tag(target.id)
                    }
                }
                .disabled(targets.isEmpty)

                Button {
                    Task {
                        await catalog.refresh()
                        onTargetChange()
                    }
                } label: {
                    if catalog.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .help("Обновить список экранов и окон")
                .disabled(catalog.isRefreshing)
            }

            Toggle("Показывать курсор мыши", isOn: $settings.showsCursor)

            if kind == .display {
                Toggle("Не снимать окно самого AutoShoter", isOn: $settings.excludeOwnWindow)
                    .help("Иначе окно программы попадёт в каждый кадр")
            }
        }
        .onAppear { syncKindWithSelection() }
        .onChange(of: kind) { _, newKind in
            selectFirstIfNeeded()
            // Окна открываются и закрываются постоянно — список стоит перечитать.
            if newKind == .window {
                Task { await catalog.refresh() }
            }
        }
        // Список приезжает асинхронно после refresh() — выбор надо переcинхронизировать.
        .onChange(of: catalog.displayTargets) { _, _ in selectFirstIfNeeded() }
        .onChange(of: catalog.windowTargets) { _, _ in selectFirstIfNeeded() }
        .onChange(of: settings.targetID) { _, _ in onTargetChange() }
        .onChange(of: settings.showsCursor) { _, _ in onTargetChange() }
        .onChange(of: settings.excludeOwnWindow) { _, _ in onTargetChange() }
    }

    private func syncKindWithSelection() {
        if settings.targetID.hasPrefix("window:") { kind = .window }
        selectFirstIfNeeded()
    }

    /// Держим выбор валидным: при смене вкладки или пропаже окна подставляем первый доступный источник.
    private func selectFirstIfNeeded() {
        let ids = targets.map(\.id)
        if ids.contains(settings.targetID) { return }
        settings.targetID = ids.first ?? ""
    }
}
