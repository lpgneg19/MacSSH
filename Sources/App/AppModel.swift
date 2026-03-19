import Foundation
import Observation

@Observable
final class AppModel {
    var connections: [SSHConnection]
    var selection: SSHConnection.ID?
    var searchText: String = ""

    var openTabs: [SessionTab] = []
    var selectedTabID: SessionTab.ID?
    var reconnectRequests: [SSHConnection.ID: UUID] = [:]

    var filteredConnections: [SSHConnection] {
        if searchText.isEmpty {
            return connections
        }
        return connections.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.host.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }

    private enum TabKeys {
        static let openTabConnections = "openTabConnections"
        static let selectedTabConnection = "selectedTabConnection"
    }

    init() {
        let stored = ConnectionsStore.load()
        if stored.isEmpty {
            let seed = SSHConnection(name: "Example", host: "example.com", port: 22, username: "root")
            connections = [seed]
            selection = seed.id
        } else {
            connections = stored
            selection = stored.first?.id
        }

        restoreTabs()
    }

    var selectedConnection: SSHConnection? {
        guard let selection else { return nil }
        return connections.first { $0.id == selection }
    }

    var selectedTab: SessionTab? {
        guard let selectedTabID else { return openTabs.first }
        return openTabs.first { $0.id == selectedTabID }
    }

    func upsertConnection(_ connection: SSHConnection) {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
        } else {
            connections.append(connection)
        }
        selection = connection.id
        persist()
    }

    func removeSelectedConnection() {
        guard let selection else { return }
        connections.removeAll { $0.id == selection }
        openTabs.removeAll { $0.connection.id == selection }
        self.selection = connections.first?.id
        if !openTabs.contains(where: { $0.id == selectedTabID }) {
            selectedTabID = openTabs.first?.id
        }
        persist()
    }

    func openConnection(_ connection: SSHConnection) {
        if let existing = openTabs.first(where: { $0.connection.id == connection.id }) {
            selectedTabID = existing.id
            persistTabs()
            return
        }
        let tab = SessionTab(connection: connection)
        openTabs.append(tab)
        selectedTabID = tab.id
        persistTabs()
    }

    func closeTab(_ tabID: SessionTab.ID) {
        openTabs.removeAll { $0.id == tabID }
        if selectedTabID == tabID {
            selectedTabID = openTabs.last?.id
        }
        persistTabs()
    }

    func moveTab(from source: IndexSet, to destination: Int) {
        openTabs.move(fromOffsets: source, toOffset: destination)
        persistTabs()
    }

    func requestReconnect(connectionID: SSHConnection.ID) {
        reconnectRequests[connectionID] = UUID()
    }

    func nextTab() {
        guard !openTabs.isEmpty else { return }
        guard let currentID = selectedTabID,
              let index = openTabs.firstIndex(where: { $0.id == currentID }) else {
            selectedTabID = openTabs.first?.id
            return
        }
        let nextIndex = (index + 1) % openTabs.count
        selectedTabID = openTabs[nextIndex].id
    }

    func previousTab() {
        guard !openTabs.isEmpty else { return }
        guard let currentID = selectedTabID,
              let index = openTabs.firstIndex(where: { $0.id == currentID }) else {
            selectedTabID = openTabs.last?.id
            return
        }
        let nextIndex = (index - 1 + openTabs.count) % openTabs.count
        selectedTabID = openTabs[nextIndex].id
    }

    func selectTab(at index: Int) {
        guard index >= 0 && index < openTabs.count else { return }
        selectedTabID = openTabs[index].id
    }

    func exportConnections(to url: URL) {
        ConnectionsStore.export(connections, to: url)
    }

    func importConnections(from url: URL, mode: ImportMode) {
        guard let imported = ConnectionsStore.import(from: url) else { return }
        switch mode {
        case .merge:
            let merged = mergeConnections(existing: connections, incoming: imported)
            connections = merged
        case .replace:
            connections = imported
        }
        selection = connections.first?.id
        persist()
    }

    private func mergeConnections(existing: [SSHConnection], incoming: [SSHConnection]) -> [SSHConnection] {
        var result = existing
        for item in incoming {
            if result.contains(where: { $0.host == item.host && $0.port == item.port && $0.username == item.username }) {
                continue
            }
            result.append(item)
        }
        return result
    }

    private func persist() {
        ConnectionsStore.save(connections)
        persistTabs()
    }

    private func persistTabs() {
        let defaults = UserDefaults.standard
        let connectionIDs = openTabs.map { $0.connection.id.uuidString }
        defaults.set(connectionIDs, forKey: TabKeys.openTabConnections)
        if let selected = selectedTab?.connection.id {
            defaults.set(selected.uuidString, forKey: TabKeys.selectedTabConnection)
        } else {
            defaults.removeObject(forKey: TabKeys.selectedTabConnection)
        }
    }

    private func restoreTabs() {
        let defaults = UserDefaults.standard
        let ids = defaults.stringArray(forKey: TabKeys.openTabConnections) ?? []
        let connectionsByID = Dictionary(uniqueKeysWithValues: connections.map { ($0.id.uuidString, $0) })
        let tabs = ids.compactMap { connectionsByID[$0] }.map { SessionTab(connection: $0) }
        openTabs = tabs

        if let selectedID = defaults.string(forKey: TabKeys.selectedTabConnection),
           let selectedConnection = connectionsByID[selectedID],
           let tab = openTabs.first(where: { $0.connection.id == selectedConnection.id }) {
            selectedTabID = tab.id
        } else {
            selectedTabID = openTabs.first?.id
        }
    }
}
