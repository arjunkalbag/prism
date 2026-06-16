import SwiftUI

/// Shown inside the overlay when Screen Recording permission is missing —
/// the macOS path to system-audio capture.
struct PermissionView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: "waveform.slash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.accent(model.accentHue))
                Text("Screen Recording needed")
                    .font(.prismBody(18))
                    .foregroundStyle(Theme.ink)
            }

            Text("Prism listens to system audio through ScreenCaptureKit, which macOS gates behind Screen Recording permission. Grant it, then hit retry.")
                .font(.prismBody(13))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                step(1, "Open System Settings → Privacy & Security → Screen Recording")
                step(2, "Enable Prism, then return here")
            }
            .padding(.vertical, 2)

            HStack(spacing: 10) {
                Button {
                    model.openScreenRecordingSettings()
                } label: {
                    Text("Open System Settings")
                        .font(.prismBody(13))
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(
                            LinearGradient(colors: [Theme.accent(model.accentHue),
                                                    Theme.accent(model.accentHue + 30, sat: 0.9, bri: 0.95)],
                                           startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                        )
                        .foregroundStyle(Color(red: 0.04, green: 0.02, blue: 0.07))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await model.retryCapture() }
                } label: {
                    Text("Retry")
                        .font(.prismBody(13))
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Theme.edge, lineWidth: 1))
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("\(n)")
                .instrument(11)
                .foregroundStyle(Color(red: 0.04, green: 0.02, blue: 0.07))
                .frame(width: 18, height: 18)
                .background(Theme.accent(model.accentHue), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(text)
                .font(.prismBody(12.5))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
