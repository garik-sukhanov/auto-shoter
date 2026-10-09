import SwiftUI

struct QualitySection: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var estimator: PreviewEstimator

    private static let scales: [Double] = [100, 75, 50, 25]

    var body: some View {
        Section("Качество и вес") {
            Picker("Формат", selection: $settings.format) {
                ForEach(ImageFormat.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Text(settings.format.hint)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Качество")
                Slider(value: $settings.quality, in: 0.1...1.0, step: 0.05)
                Text("\(Int(settings.quality * 100)) %")
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
            .disabled(!settings.format.supportsQuality)
            .opacity(settings.format.supportsQuality ? 1 : 0.4)

            Picker("Разрешение", selection: $settings.scalePercent) {
                ForEach(Self.scales, id: \.self) { value in
                    Text(value == 100 ? "100 % (как есть)" : "\(Int(value)) %").tag(value)
                }
            }

            estimateCard
        }
        // Формат и качество меняют только кодирование — кадр переиспользуем.
        .onChange(of: settings.format) { _, _ in estimator.request(recapture: false) }
        .onChange(of: settings.quality) { _, _ in estimator.request(recapture: false) }
        // Масштаб влияет на сам захват.
        .onChange(of: settings.scalePercent) { _, _ in estimator.request() }
    }

    private var estimateCard: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 5) {
                row("Один снимок", estimator.sizeText, emphasized: true)
                row("Размер кадра", estimator.dimensionsText)
                row("За час съёмки", estimator.hourlyText(intervalSeconds: settings.intervalSeconds))
                if let planned = SessionPlan.plannedShots(settings: settings), planned > 0 {
                    row("За сессию (\(planned) шт.)", estimator.totalText(shots: planned))
                }

                if let error = estimator.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack {
                Button {
                    estimator.request(debounce: .zero)  // кнопка «обновить» всегда снимает заново
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Сделать пробный кадр заново")

                if estimator.isWorking {
                    ProgressView().controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func row(_ title: String, _ value: String, emphasized: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(emphasized ? .title3.weight(.semibold) : .callout)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
            if let image = estimator.thumbnail {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 104, height: 66)
    }
}
