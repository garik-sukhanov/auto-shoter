import Foundation

/// Раскладка файлов: база → дата → сессия → снимок.
enum StorageLayout {
    static let rootFolderName = "AutoShoter"

    static func dateFolderName(_ date: Date) -> String {
        format(date, "yyyy-MM-dd")
    }

    static func sessionFolderName(_ date: Date, name: String) -> String {
        let stamp = format(date, "HH-mm-ss")
        let clean = sanitize(name)
        return clean.isEmpty ? "Сессия \(stamp)" : "\(stamp) \(clean)"
    }

    static func sessionDirectory(
        base: URL,
        useRootFolder: Bool,
        groupByDate: Bool,
        useSessionFolder: Bool,
        sessionName: String,
        start: Date
    ) -> URL {
        var url = base
        if useRootFolder { url.appendPathComponent(rootFolderName) }
        if groupByDate { url.appendPathComponent(dateFolderName(start)) }
        if useSessionFolder { url.appendPathComponent(sessionFolderName(start, name: sessionName)) }
        return url
    }

    static func fileName(index: Int, date: Date, prefix: String, ext: String) -> String {
        let clean = sanitize(prefix)
        let head = clean.isEmpty ? "shot" : clean
        return String(format: "%@_%04d_%@.%@", head, index, format(date, "HH-mm-ss"), ext)
    }

    /// Человекочитаемый пример пути — показывается в интерфейсе до запуска.
    static func previewPath(
        base: URL,
        useRootFolder: Bool,
        groupByDate: Bool,
        useSessionFolder: Bool,
        sessionName: String,
        prefix: String,
        ext: String,
        at date: Date = Date()
    ) -> String {
        let dir = sessionDirectory(
            base: base,
            useRootFolder: useRootFolder,
            groupByDate: groupByDate,
            useSessionFolder: useSessionFolder,
            sessionName: sessionName,
            start: date
        )
        let file = fileName(index: 1, date: date, prefix: prefix, ext: ext)
        return dir.appendingPathComponent(file).path
    }

    private static func format(_ date: Date, _ template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = template
        return formatter.string(from: date)
    }

    /// Убираем то, что ломает имена файлов, но кириллицу оставляем.
    private static func sanitize(_ raw: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return raw
            .components(separatedBy: forbidden)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
