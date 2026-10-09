import Foundation
import SwiftUI

/// Все пользовательские настройки. Каждое свойство само пишется в UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let d = UserDefaults.standard

    // MARK: - Что снимаем

    /// "display:<id>" или "window:<windowID>|<bundleID>|<title>"
    @Published var targetID: String { didSet { d.set(targetID, forKey: K.targetID) } }
    @Published var showsCursor: Bool { didSet { d.set(showsCursor, forKey: K.showsCursor) } }
    @Published var excludeOwnWindow: Bool { didSet { d.set(excludeOwnWindow, forKey: K.excludeOwnWindow) } }

    // MARK: - Как часто

    @Published var intervalSeconds: Double { didSet { d.set(intervalSeconds, forKey: K.intervalSeconds) } }
    @Published var stopMode: StopMode { didSet { d.set(stopMode.rawValue, forKey: K.stopMode) } }
    @Published var maxShots: Int { didSet { d.set(maxShots, forKey: K.maxShots) } }
    @Published var stopAfterMinutes: Double { didSet { d.set(stopAfterMinutes, forKey: K.stopAfterMinutes) } }
    /// Минуты от полуночи: 15:00 — это 900.
    @Published var stopAtMinuteOfDay: Int { didSet { d.set(stopAtMinuteOfDay, forKey: K.stopAtMinuteOfDay) } }

    // MARK: - Куда сохраняем

    @Published var baseFolderPath: String { didSet { d.set(baseFolderPath, forKey: K.baseFolderPath) } }
    /// Своя папка AutoShoter внутри выбранной — чтобы не засорять её папками с датами.
    @Published var useRootFolder: Bool { didSet { d.set(useRootFolder, forKey: K.useRootFolder) } }
    @Published var groupByDate: Bool { didSet { d.set(groupByDate, forKey: K.groupByDate) } }
    @Published var useSessionFolder: Bool { didSet { d.set(useSessionFolder, forKey: K.useSessionFolder) } }
    @Published var sessionName: String { didSet { d.set(sessionName, forKey: K.sessionName) } }
    @Published var filePrefix: String { didSet { d.set(filePrefix, forKey: K.filePrefix) } }

    // MARK: - Качество

    @Published var format: ImageFormat { didSet { d.set(format.rawValue, forKey: K.format) } }
    /// 0.1 … 1.0
    @Published var quality: Double { didSet { d.set(quality, forKey: K.quality) } }
    /// 25 … 100 процентов от исходного разрешения
    @Published var scalePercent: Double { didSet { d.set(scalePercent, forKey: K.scalePercent) } }

    var baseFolderURL: URL {
        URL(fileURLWithPath: (baseFolderPath as NSString).expandingTildeInPath)
    }

    private init() {
        // Папку AutoShoter добавляет useRootFolder, поэтому база — просто «Изображения».
        let defaultFolder = FileManager.default
            .urls(for: .picturesDirectory, in: .userDomainMask).first?.path
            ?? NSHomeDirectory() + "/Pictures"

        targetID = d.string(forKey: K.targetID) ?? ""
        showsCursor = d.object(forKey: K.showsCursor) as? Bool ?? true
        excludeOwnWindow = d.object(forKey: K.excludeOwnWindow) as? Bool ?? true

        intervalSeconds = d.object(forKey: K.intervalSeconds) as? Double ?? 60
        stopMode = StopMode(rawValue: d.string(forKey: K.stopMode) ?? "") ?? .never
        // 0 мог остаться от прежней схемы, где это значило «без лимита» — теперь за лимит
        // отвечает stopMode, и ноль здесь сделал бы режим «после N снимков» бесконечным.
        let storedShots = d.object(forKey: K.maxShots) as? Int ?? 100
        maxShots = storedShots > 0 ? storedShots : 100
        stopAfterMinutes = d.object(forKey: K.stopAfterMinutes) as? Double ?? 60
        stopAtMinuteOfDay = d.object(forKey: K.stopAtMinuteOfDay) as? Int ?? 18 * 60

        baseFolderPath = d.string(forKey: K.baseFolderPath) ?? defaultFolder
        useRootFolder = d.object(forKey: K.useRootFolder) as? Bool ?? true
        groupByDate = d.object(forKey: K.groupByDate) as? Bool ?? true
        useSessionFolder = d.object(forKey: K.useSessionFolder) as? Bool ?? true
        sessionName = d.string(forKey: K.sessionName) ?? ""
        filePrefix = d.string(forKey: K.filePrefix) ?? "shot"

        format = ImageFormat(rawValue: d.string(forKey: K.format) ?? "") ?? .jpeg
        quality = d.object(forKey: K.quality) as? Double ?? 0.8
        scalePercent = d.object(forKey: K.scalePercent) as? Double ?? 100
    }

    private enum K {
        static let targetID = "targetID"
        static let showsCursor = "showsCursor"
        static let excludeOwnWindow = "excludeOwnWindow"
        static let intervalSeconds = "intervalSeconds"
        static let stopMode = "stopMode"
        static let maxShots = "maxShots"
        static let stopAfterMinutes = "stopAfterMinutes"
        static let stopAtMinuteOfDay = "stopAtMinuteOfDay"
        static let baseFolderPath = "baseFolderPath"
        static let useRootFolder = "useRootFolder"
        static let groupByDate = "groupByDate"
        static let useSessionFolder = "useSessionFolder"
        static let sessionName = "sessionName"
        static let filePrefix = "filePrefix"
        static let format = "format"
        static let quality = "quality"
        static let scalePercent = "scalePercent"
    }
}
