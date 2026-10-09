import Foundation

/// Чем ограничена сессия.
enum StopMode: String, CaseIterable, Identifiable {
    case never
    case shots
    case duration
    case clock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: return "Не останавливаться"
        case .shots: return "После N снимков"
        case .duration: return "Через время"
        case .clock: return "В заданное время"
        }
    }
}

enum SessionPlan {
    /// Ближайшее HH:MM — сегодня, а если момент уже прошёл, то завтра.
    static func nextOccurrence(minuteOfDay: Int, from now: Date = Date(), calendar: Calendar = .current) -> Date {
        let midnight = calendar.startOfDay(for: now)
        let today = midnight.addingTimeInterval(TimeInterval(minuteOfDay * 60))
        guard today <= now else { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86400)
    }

    /// Сколько снимков даст сессия при текущих настройках. nil — ограничения нет.
    /// Первый кадр снимается сразу, поэтому за время T их получается floor(T / интервал) + 1.
    static func plannedShots(settings: AppSettings, from now: Date = Date()) -> Int? {
        let interval = max(1, settings.intervalSeconds)
        switch settings.stopMode {
        case .never:
            return nil
        case .shots:
            return max(1, settings.maxShots)
        case .duration:
            return Int(max(0, settings.stopAfterMinutes * 60) / interval) + 1
        case .clock:
            let left = nextOccurrence(minuteOfDay: settings.stopAtMinuteOfDay, from: now).timeIntervalSince(now)
            return Int(max(0, left) / interval) + 1
        }
    }

    /// «1 снимок», «3 снимка», «11 снимков» — иначе интерфейс выглядит машинным.
    static func shotsWord(_ count: Int) -> String {
        let last = abs(count) % 10
        let lastTwo = abs(count) % 100
        if last == 1 && lastTwo != 11 { return "снимок" }
        if (2...4).contains(last) && !(12...14).contains(lastTwo) { return "снимка" }
        return "снимков"
    }

    static func shotsText(_ count: Int) -> String {
        "\(count) \(shotsWord(count))"
    }

    /// «1 минута», «2 минуты», «10 минут»; дробные значения всегда «минуты».
    static func minutesWord(_ value: Double) -> String {
        guard value == value.rounded() else { return "минуты" }
        let count = Int(value)
        let last = abs(count) % 10
        let lastTwo = abs(count) % 100
        if last == 1 && lastTwo != 11 { return "минута" }
        if (2...4).contains(last) && !(12...14).contains(lastTwo) { return "минуты" }
        return "минут"
    }

    static func durationText(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    static func clockText(minuteOfDay: Int) -> String {
        String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
    }
}
