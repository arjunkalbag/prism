import SwiftUI
import PrismCore

/// The glass overlay itself — the whole product in one panel.
struct OverlayView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    /// Offscreen rendering (PrismSnapshot): `ImageRenderer` can't capture the live
    /// `NSVisualEffectView` blur or a `ScrollView`, so in snapshot mode the blur
    /// becomes a clear pane (the caller draws a desktop stand-in behind) and the
    /// mode content drops the scroll wrapper. Layout is otherwise identical.
    static var isSnapshot = false

    private var accent: Color { Theme.accent(model.accentHue) }

    var body: some View {
        ZStack {
            // True frosted glass of whatever's behind the panel.
            if OverlayView.isSnapshot {
                Color.clear
            } else {
                VisualEffectBlur(material: .hudWindow, blending: .behindWindow)
            }

            // Dark veil + a soft glow tinted to the detected key.
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.025, blue: 0.08).opacity(0.55),
                         Color(red: 0.04, green: 0.025, blue: 0.08).opacity(0.30)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [accent.opacity(0.30), .clear],
                center: .init(x: 0.5, y: 0.0), startRadius: 6, endRadius: 320
            )
            .blendMode(.screen)

            content
                .padding(.horizontal, 22)
                .padding(.top, 28)   // clear the window's traffic-light buttons
                .padding(.bottom, 20)
        }
        .ignoresSafeArea()
        .onAppear { if !reduceMotion { pulse = true } }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if model.status == .needsPermission {
                PermissionView()
                Spacer(minLength: 0)
            } else {
                keyBlock
                metersRow
                modeToggle
                if OverlayView.isSnapshot {
                    Group {
                        if model.mode == .dj { DJModeView() } else { ProducerModeView() }
                    }
                    Spacer(minLength: 0)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        Group {
                            if model.mode == .dj { DJModeView() } else { ProducerModeView() }
                        }
                        .transition(.opacity)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Header — status indicator only (no wordmark)
    private var header: some View {
        HStack(alignment: .center, spacing: 7) {
            Spacer()
            Text(statusText)
                .font(.prismBody(11))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(model.status == .locked ? accent : Theme.faint)
            Circle()
                .fill(model.status == .locked ? accent : Theme.faint)
                .frame(width: 9, height: 9)
                .shadow(color: accent, radius: model.status == .locked ? 6 : 0)
                .opacity(pulse && model.status != .locked ? 0.4 : 1.0)
                .animation(reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
        }
    }

    // MARK: Key block
    private var keyBlock: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if let key = model.displayKey {
                VStack(alignment: .leading, spacing: 0) {
                    Text(key.tonicSpelling.symbol)
                        .font(.prismBody(64))
                        .foregroundStyle(.white)
                        .shadow(color: accent.opacity(0.6), radius: 18, y: 4)
                    Text(key.mode.longName)
                        .font(.prismBody(16))
                        .foregroundStyle(Theme.accent(model.accentHue, sat: 0.55, bri: 0.95))
                        .offset(y: -4)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("listening")
                        .font(.prismBody(38))
                        .foregroundStyle(Theme.muted)
                    Text("for a key…").font(.prismBody(14)).foregroundStyle(Theme.faint)
                }
            }
            Spacer()
            if let c = model.camelot {
                Text(c.code)
                    .font(.prismBody(24))
                    .foregroundStyle(Color(red: 0.04, green: 0.02, blue: 0.07))
                    .padding(.vertical, 8).padding(.horizontal, 12)
                    .background(
                        LinearGradient(colors: [Theme.accent(model.accentHue, bri: 1.0),
                                                Theme.accent(model.accentHue, sat: 0.9, bri: 0.7)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                    .shadow(color: accent.opacity(0.5), radius: 14, y: 6)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.displayKey)
    }

    // MARK: Meters
    private var metersRow: some View {
        HStack(spacing: 14) {
            ChromaMeterView(chroma: model.chroma, accentHue: model.accentHue)
                .frame(height: 34)
            HStack(spacing: 4) {
                Text(model.bpm.map { String(Int($0.rounded())) } ?? "—")
                    .font(.prismBody(20))
                    .foregroundStyle(.white)
                Text("BPM").font(.prismBody(11)).foregroundStyle(Theme.muted)
            }
            .fixedSize()
        }
    }

    // MARK: Mode toggle (the orchestrated interaction)
    private var modeToggle: some View {
        HStack(spacing: 6) {
            ForEach(AppMode.allCases, id: \.self) { m in
                let isOn = model.mode == m
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        model.setMode(m)
                    }
                } label: {
                    Text(m.title)
                        .font(.prismBody(15))
                        .foregroundStyle(isOn ? Color(red: 0.04, green: 0.02, blue: 0.07) : Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isOn
                                      ? LinearGradient(colors: [accent, Theme.accent(model.accentHue + 16, sat: 0.92)],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                                      : LinearGradient(colors: [.clear, .clear],
                                                       startPoint: .top, endPoint: .bottom))
                        )
                        .contentShape(Rectangle())   // whole box is the hit target
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var statusText: String {
        switch model.status {
        case .idle: return "starting"
        case .needsPermission: return "permission needed"
        case .listening: return "listening"
        case .locked: return "locked"
        }
    }
}
