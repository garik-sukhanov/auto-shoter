import SwiftUI

struct RunPanel: View {
    @ObservedObject var session: SessionController

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button(action: session.toggle) {
                    Label(
                        session.isRunning ? "Остановить" : "Начать съёмку",
                        systemImage: session.isRunning ? "stop.fill" : "record.circle"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(session.isRunning ? .red : .accentColor)
                .keyboardShortcut(.defaultAction)

                Button(action: session.togglePause) {
                    Label(
                        session.isPaused ? "Продолжить" : "Пауза",
                        systemImage: session.isPaused ? "play.fill" : "pause.fill"
                    )
                    .padding(.vertical, 4)
                }
                .disabled(!session.isRunning)
                .help("Пауза не закрывает сессию: папка и нумерация снимков сохранятся")

                Button {
                    session.revealInFinder()
                } label: {
                    Label("В Finder", systemImage: "folder")
                        .padding(.vertical, 4)
                }
                .disabled(session.sessionDirectory == nil)
            }

            if session.isRunning {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    stats(now: context.date)
                }
            } else {
                stats(now: Date())
            }

            if let entry = session.log.first {
                HStack(spacing: 6) {
                    Image(systemName: entry.isError ? "exclamationmark.triangle.fill" : "checkmark.circle")
                        .foregroundStyle(entry.isError ? .orange : .secondary)
                    Text(entry.text)
                        .font(.caption)
                        .foregroundStyle(entry.isError ? .orange : .secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func stats(now: Date) -> some View {
        HStack(spacing: 0) {
            stat("Снимков", "\(session.shotCount)")
            Divider().frame(height: 26)
            stat("Объём", session.totalBytesText)
            Divider().frame(height: 26)
            stat("Длительность", SessionPlan.durationText(session.elapsed))
            Divider().frame(height: 26)
            stat("Следующий", nextShotText(now: now))
        }
        .frame(maxWidth: .infinity)
    }

    private func nextShotText(now: Date) -> String {
        if session.isPaused { return "пауза" }
        guard let next = session.nextShotDate else { return "—" }
        return "\(max(0, Int(next.timeIntervalSince(now).rounded(.up)))) с"
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
