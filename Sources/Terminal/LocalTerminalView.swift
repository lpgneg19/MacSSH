import SwiftUI

struct LocalTerminalView: View {
    let settings: AppSettings
    @State private var tabIDs: [UUID] = [UUID()]
    @State private var selectedTabID: UUID?

    init(settings: AppSettings) {
        self.settings = settings
        _selectedTabID = State(initialValue: tabIDs.first)
    }
    
    var body: some View {
        TabView(selection: $selectedTabID) {
            ForEach(tabIDs, id: \.self) { id in
                GhosttyTerminalView(settings: settings)
                    .tag(id as UUID?)
                    .tabItem {
                        Label(String(localized: "Local"), systemImage: "terminal")
                    }
            }
        }
        .ignoresSafeArea()
        .navigationTitle(String(localized: "Local Terminal"))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    let newID = UUID()
                    tabIDs.append(newID)
                    selectedTabID = newID
                } label: {
                    Label(String(localized: "New Tab"), systemImage: "plus")
                }
                .keyboardShortcut("t", modifiers: .command)

                Button {
                    closeSelectedTab()
                } label: {
                    Label(String(localized: "Close Tab"), systemImage: "xmark")
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(tabIDs.count <= 1)

                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Label(String(localized: "Settings"), systemImage: "gearshape")
                }
                .help(String(localized: "Open Application Settings"))
            }
            
            ToolbarItem(placement: .status) {
                Text("Ghostty Engine")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func closeSelectedTab() {
        guard tabIDs.count > 1, let current = selectedTabID else { return }
        if let index = tabIDs.firstIndex(of: current) {
            tabIDs.remove(at: index)
            selectedTabID = tabIDs.last
        }
    }
}
