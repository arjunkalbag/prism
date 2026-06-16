import SwiftUI
import PrismCore

/// Producer mode — scale, diatonic chords, progressions, relative/parallel
/// keys, and an optional AI "creative directions" layer.
struct ProducerModeView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        if let dia = model.diatonic, let key = model.displayKey {
            VStack(alignment: .leading, spacing: 12) {
                Text("In the key of \(key.displayName)")
                    .instrument(10)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.faint)

                // Scale
                HStack(spacing: 8) {
                    Text("Scale").font(.prismBody(12)).foregroundStyle(Theme.muted)
                    Text(dia.scale.map(\.symbol).joined(separator: "  "))
                        .instrument(12.5)
                        .foregroundStyle(Theme.ink)
                }

                // Diatonic chords
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(dia.chords) { chordChip($0) }
                }

                if !dia.secondaryChords.isEmpty {
                    HStack(alignment: .center, spacing: 7) {
                        Text("Harmonic").font(.prismBody(11)).foregroundStyle(Theme.faint)
                        ForEach(dia.secondaryChords) { chordChip($0, dim: true) }
                    }
                }

                // Progressions
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(dia.progressions) { prog in
                        HStack(spacing: 8) {
                            Text(prog.label)
                                .font(.prismBody(12))
                                .foregroundStyle(Theme.muted)
                            Spacer(minLength: 6)
                            Text(prog.chords.map(\.symbol).joined(separator: " – "))
                                .instrument(11, weight: .regular)
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }

                // Relative / parallel
                HStack(spacing: 12) {
                    relPill("Relative", dia.relativeKey)
                    relPill("Parallel", dia.parallelKey)
                }

                aiSection(key)
            }
        } else {
            Text("Listening for a key…")
                .font(.prismBody(13))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func chordChip(_ chord: Chord, dim: Bool = false) -> some View {
        VStack(spacing: 1) {
            Text(chord.roman)
                .instrument(9, weight: .bold)
                .foregroundStyle(Theme.accent(model.accentHue))
            Text(chord.symbol)
                .font(.prismBody(15))
                .foregroundStyle(Theme.ink)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 11)
        .background(Color.white.opacity(dim ? 0.04 : 0.06),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Theme.edge, lineWidth: 1))
    }

    private func relPill(_ label: String, _ key: MusicalKey) -> some View {
        HStack(spacing: 7) {
            Text(label).font(.prismBody(11)).foregroundStyle(Theme.faint)
            Text(key.shortName).font(.prismBody(13)).foregroundStyle(Theme.ink)
            Text(Camelot.code(for: key).code)
                .instrument(9.5)
                .foregroundStyle(Color(red: 0.04, green: 0.02, blue: 0.07))
                .padding(.vertical, 2).padding(.horizontal, 5)
                .background(Theme.camelotColor(Camelot.code(for: key).number),
                            in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }

    @ViewBuilder
    private func aiSection(_ key: MusicalKey) -> some View {
        if model.aiEnabled {
            Divider().overlay(Theme.edge)
            if model.aiConfigured {
                HStack {
                    Text("Creative directions")
                        .instrument(10).tracking(1.0).textCase(.uppercase)
                        .foregroundStyle(Theme.faint)
                    Spacer()
                    Button {
                        model.requestAISuggestions()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                            Text(model.aiLoading ? "Thinking…" : "Suggest ideas")
                        }
                        .font(.prismBody(12))
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(Theme.accent(model.accentHue).opacity(0.92), in: Capsule())
                        .foregroundStyle(Color(red: 0.04, green: 0.02, blue: 0.07))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.aiLoading)
                }
                if let err = model.aiError {
                    Text(err).font(.prismBody(11.5)).foregroundStyle(.orange)
                }
                ForEach(model.aiSuggestions) { s in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.title).font(.prismBody(13)).foregroundStyle(Theme.ink)
                        Text(s.detail).font(.prismBody(12)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            } else {
                Text("Set ANTHROPIC_API_KEY to enable AI creative directions.")
                    .font(.prismBody(11.5)).foregroundStyle(Theme.faint)
            }
        }
    }
}
