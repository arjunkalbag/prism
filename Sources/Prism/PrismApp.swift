import SwiftUI

/// Menu-bar accessory app (LSUIElement). The custom floating overlay panel is
/// created and owned by `AppDelegate`; this scene is just the menu-bar item.
@main
struct PrismApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView().environmentObject(appDelegate.model)
        } label: {
            MenuBarLabel(model: appDelegate.model)
        }
        .menuBarExtraStyle(.window)
    }
}
