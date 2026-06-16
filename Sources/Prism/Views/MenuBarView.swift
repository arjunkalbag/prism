import SwiftUI
import PrismCore

/// The menu-bar item's label — shows the live Camelot code once locked.
struct MenuBarLabel: View {
    @ObservedObject var model: AppModel
    var body: some View {
        if let c = model.camelot {
            Text(c.code)
        } else {
            Image(systemName: "waveform")
        }
    }
}

/// The menu-bar popover: status, overlay controls, mode, settings, quit.
struct MenuBarView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Circle().fill(Theme.accent(model.accentHue)).frame(width: 8, height: 8)
                Text("Prism").font(.prismBody(13)).foregroundStyle(Theme.muted)
                Spacer()
                Text(statusText).font(.prismBody(10)).foregroundStyle(.secondary)
            }

            if let key = model.displayKey {
                HStack {
                    Text(key.displayName).font(.prismBody(13))
                    Spacer()
                    Text(model.camelot?.code ?? "")
                        .font(.prismBody(15))
                        .foregroundStyle(Theme.accent(model.accentHue))
                }
            }

            Divider()

            Button(model.visible ? "Hide overlay" : "Show overlay") { model.toggleVisible() }

            Picker("Mode", selection: $model.mode) {
                ForEach(AppMode.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Toggle("Float on top", isOn: $model.floatOnTop)
            Toggle("Click-through (⌃⌥T)", isOn: $model.clickThrough)

            VStack(alignment: .leading, spacing: 2) {
                Text("Opacity").font(.system(size: 11)).foregroundStyle(.secondary)
                Slider(value: $model.opacity, in: 0.4...1.0)
            }

            Picker("Detection", selection: $model.profile) {
                ForEach(KeyProfile.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }

            Toggle("AI suggestions", isOn: $model.aiEnabled).disabled(!model.aiConfigured)
            if !model.aiConfigured {
                Text("Set ANTHROPIC_API_KEY to enable AI")
                    .font(.prismBody(10.5)).foregroundStyle(.tertiary)
            }

            if model.status == .needsPermission {
                Button("Grant Screen Recording…") { model.openScreenRecordingSettings() }
            }

            Divider()

            HStack {
                Text("⌃⌥K show/hide").instrument(10, weight: .regular).foregroundStyle(.tertiary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    private var statusText: String {
        switch model.status {
        case .idle: return "starting"
        case .needsPermission: return "no permission"
        case .listening: return "listening"
        case .locked: return "locked"
        }
    }
}
