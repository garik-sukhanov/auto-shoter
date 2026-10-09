import SwiftUI
import AppKit

struct StorageSection: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Section("Куда сохраняем") {
            HStack {
                Text("Папка")
                Spacer()
                Text(settings.baseFolderURL.path)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(settings.baseFolderURL.path)
                Button("Выбрать…", action: chooseFolder)
            }

            Toggle("Своя папка «\(StorageLayout.rootFolderName)» внутри выбранной", isOn: $settings.useRootFolder)
                .help("Выключите, если папки с датами должны ложиться прямо в выбранную папку")

            Toggle("Папка на каждый день (2026-09-21)", isOn: $settings.groupByDate)
            Toggle("Папка на каждую сессию", isOn: $settings.useSessionFolder)

            if settings.useSessionFolder {
                TextField("Имя сессии (необязательно)", text: $settings.sessionName)
                    .textFieldStyle(.roundedBorder)
            }

            TextField("Префикс имени файла", text: $settings.filePrefix)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 3) {
                Text("Первый файл ляжет сюда:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(examplePath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
    }

    private var examplePath: String {
        StorageLayout.previewPath(
            base: settings.baseFolderURL,
            useRootFolder: settings.useRootFolder,
            groupByDate: settings.groupByDate,
            useSessionFolder: settings.useSessionFolder,
            sessionName: settings.sessionName,
            prefix: settings.filePrefix,
            ext: settings.format.fileExtension
        )
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Выбрать"
        panel.message = "Куда складывать снимки"
        panel.directoryURL = settings.baseFolderURL
        if panel.runModal() == .OK, let url = panel.url {
            settings.baseFolderPath = url.path
        }
    }
}
