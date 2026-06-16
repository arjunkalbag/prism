import SwiftUI
import PrismCore

/// DJ mode — the color-coded Camelot wheel plus a ranked "mix next" list.
struct DJModeView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let current = model.camelot ?? Camelot(number: 8, mode: .minor)
        let matches = model.mixSuggestions
        let compatible = Set(matches.map { $0.camelot.code })

        VStack(alignment: .leading, spacing: 12) {
            Text("Harmonic matches — Camelot")
                .instrument(10)
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.faint)

            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    CamelotWheelView(current: current, compatibleCodes: compatible)
                        .frame(width: 146, height: 146)
                    VStack(spacing: 1) {
                        Text(current.code)
                            .font(.prismBody(20))
                            .foregroundStyle(Theme.ink)
                        Text(model.displayKey?.shortName ?? "—")
                            .instrument(10, weight: .regular)
                            .foregroundStyle(Theme.muted)
                    }
                }

                VStack(spacing: 6) {
                    ForEach(matches) { mixRow($0) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func mixRow(_ s: MixSuggestion) -> some View {
        HStack(spacing: 9) {
            Text(s.camelot.code)
                .instrument(11)
                .foregroundStyle(Color(red: 0.04, green: 0.02, blue: 0.07))
                .frame(minWidth: 30)
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(Theme.camelotColor(s.camelot.number),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(s.key.displayName)
                .font(.prismBody(13))
                .foregroundStyle(Color(red: 0.91, green: 0.89, blue: 0.96))
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(s.label)
                .instrument(9, weight: .regular)
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundStyle(Theme.faint)
        }
    }
}
