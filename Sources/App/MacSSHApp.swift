import SwiftUI

@main
struct MacSSHApp: App {
    @State private var model = AppModel()
    @State private var settings = AppSettings()

    init() {
        // Ensure Ghostty is initialized on the main thread immediately
        _ = GhosttyRuntime.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model, settings: settings)
        }
        .commands {
            CommandMenu(String(localized: "Session")) {
                Button(String(localized: "Reconnect")) {
                    if let connectionID = model.selectedTab?.connection.id {
                        model.requestReconnect(connectionID: connectionID)
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(model.selectedTab == nil)

                Button(String(localized: "Close Tab")) {
                    if let tabID = model.selectedTabID {
                        model.closeTab(tabID)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(model.selectedTabID == nil)
            }
            
            CommandMenu(String(localized: "Tab")) {
                Button(String(localized: "Next Tab")) {
                    model.nextTab()
                }
                .keyboardShortcut("]", modifiers: .command)
                
                Button(String(localized: "Previous Tab")) {
                    model.previousTab()
                }
                .keyboardShortcut("[", modifiers: .command)
                
                Divider()
                
                ForEach(0..<min(model.openTabs.count, 9), id: \.self) { index in
                    Button(model.openTabs[index].connection.name) {
                        model.selectTab(at: index)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
        }

        Settings {
            SettingsView(settings: settings)
        }
    }
}
