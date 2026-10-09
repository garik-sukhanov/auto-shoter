import SwiftUI

struct LogSection: View {
    @ObservedObject var session: SessionController

    var body: some View {
        Section("Журнал") {
            if session.log.isEmpty {
                Text("Пока пусто. Нажмите «Начать съёмку».")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(session.log) { entry in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(entry.date, format: .dateTime.hour().minute().second())
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                Text(entry.text)
                                    .font(.caption)
                                    .foregroundStyle(entry.isError ? .orange : .primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 120)
            }
        }
    }
}
