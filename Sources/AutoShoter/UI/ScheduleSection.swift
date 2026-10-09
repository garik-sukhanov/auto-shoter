import SwiftUI

struct ScheduleSection: View {
    @ObservedObject var settings: AppSettings
    var onIntervalChange: () -> Void

    private enum Unit: String, CaseIterable, Identifiable {
        case seconds, minutes
        var id: String { rawValue }
        var title: String { self == .seconds ? "сек" : "мин" }
        var factor: Double { self == .seconds ? 1 : 60 }
    }

    private static let presets: [(String, Double)] = [
        ("10 сек", 10), ("30 сек", 30), ("1 мин", 60), ("5 мин", 300), ("15 мин", 900)
    ]

    @State private var unit: Unit = .minutes
    @State private var amount: Double = 1

    var body: some View {
        Section("Как часто") {
            HStack(spacing: 8) {
                Text("Каждые")
                TextField("", value: $amount, format: .number.precision(.fractionLength(0...2)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .multilineTextAlignment(.trailing)
                Picker("", selection: $unit) {
                    ForEach(Unit.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(width: 80)
                Spacer()
                Text(humanInterval)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            HStack(spacing: 6) {
                ForEach(Self.presets, id: \.0) { title, seconds in
                    Button(title) { apply(seconds: seconds) }
                        .buttonStyle(.bordered)
                        .tint(abs(settings.intervalSeconds - seconds) < 0.01 ? .accentColor : nil)
                }
                Spacer()
            }
        }

        Section("Когда остановиться") {
            Picker("Остановиться", selection: $settings.stopMode) {
                ForEach(StopMode.allCases) { Text($0.title).tag($0) }
            }

            switch settings.stopMode {
            case .never:
                EmptyView()

            case .shots:
                HStack {
                    Text("Количество")
                    Spacer()
                    TextField("", value: $settings.maxShots, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text(SessionPlan.shotsWord(settings.maxShots))
                }

            case .duration:
                HStack {
                    Text("Длительность")
                    Spacer()
                    TextField("", value: $settings.stopAfterMinutes, format: .number.precision(.fractionLength(0...1)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text(SessionPlan.minutesWord(settings.stopAfterMinutes))
                }

            case .clock:
                DatePicker("Остановиться в", selection: clockBinding, displayedComponents: .hourAndMinute)
            }

            if let hint = planHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { loadFromSettings() }
        .onChange(of: amount) { _, _ in pushToSettings() }
        .onChange(of: unit) { _, _ in pushToSettings() }
    }

    // MARK: - Подсказки

    private var humanInterval: String {
        let seconds = settings.intervalSeconds
        if seconds < 60 { return "\(Int(seconds)) с между снимками" }
        return "≈ \(Int((3600 / seconds).rounded())) снимк. в час"
    }

    private var planHint: String? {
        guard let planned = SessionPlan.plannedShots(settings: settings) else { return nil }
        switch settings.stopMode {
        case .never:
            return nil
        case .shots, .duration:
            return "Получится примерно \(SessionPlan.shotsText(planned))."
        case .clock:
            let target = SessionPlan.nextOccurrence(minuteOfDay: settings.stopAtMinuteOfDay)
            let today = Calendar.current.isDateInToday(target)
            let time = SessionPlan.clockText(minuteOfDay: settings.stopAtMinuteOfDay)
            return "Остановится \(today ? "сегодня" : "завтра") в \(time) — примерно \(SessionPlan.shotsText(planned))."
        }
    }

    private var clockBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.startOfDay(for: Date())
                    .addingTimeInterval(TimeInterval(settings.stopAtMinuteOfDay * 60))
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                settings.stopAtMinuteOfDay = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    // MARK: - Интервал

    private func loadFromSettings() {
        let seconds = settings.intervalSeconds
        if seconds >= 60, seconds.truncatingRemainder(dividingBy: 60) == 0 {
            unit = .minutes
            amount = seconds / 60
        } else {
            unit = .seconds
            amount = seconds
        }
    }

    private func apply(seconds: Double) {
        settings.intervalSeconds = seconds
        loadFromSettings()
        onIntervalChange()
    }

    private func pushToSettings() {
        let seconds = max(1, amount * unit.factor)
        if abs(seconds - settings.intervalSeconds) > 0.001 {
            settings.intervalSeconds = seconds
            onIntervalChange()
        }
    }
}
