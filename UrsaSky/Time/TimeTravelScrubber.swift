import SwiftUI

struct TimeTravelScrubber: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(formatted)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(app.theme.primaryText)
                Spacer()
                Picker("Unit", selection: Binding(
                    get: { app.clock.scrubberUnit },
                    set: { app.clock.scrubberUnit = $0 }
                )) {
                    Text("Hours").tag(0)
                    Text("Days").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 160)
                Button("Now") { app.clock.resetToNow() }
                    .font(.caption)
            }
            Slider(
                value: Binding(
                    get: { app.clock.offset },
                    set: { app.clock.offset = $0; app.clock.isLive = $0 == 0 }
                ),
                in: range,
                step: step
            )
            .tint(app.theme.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var range: ClosedRange<Double> {
        app.clock.scrubberUnit == 0 ? -12 * 3600 ... 12 * 3600 : -7 * 86400 ... 7 * 86400
    }

    private var step: Double {
        app.clock.scrubberUnit == 0 ? 60 : 600
    }

    private var formatted: String {
        let f = DateFormatter()
        f.timeZone = app.clock.timeZone
        f.dateFormat = "EEE MMM d HH:mm"
        return f.string(from: app.clock.now())
    }
}
