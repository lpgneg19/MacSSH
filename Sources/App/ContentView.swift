import SwiftUI
import AppKit

struct ContentView: View {
    @Bindable var model: AppModel
    @Bindable var settings: AppSettings
    @State private var editorConnection: SSHConnection?
    @State private var pendingImportURL: URL?
    @State private var importMode: ImportMode = .merge
    @State private var showImportDialog: Bool = false
    @State private var showingDeleteAlert: Bool = false

    var body: some View {
        Group {
            if settings.renderer == .ghosttySurface {
                LocalTerminalView(settings: settings)
            } else {
                splitView
            }
        }
        .confirmationDialog(
            String(localized: "Import Connections"),
            isPresented: $showImportDialog,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Merge (Recommended)")) {
                importMode = .merge
                confirmImport()
            }
            Button(String(localized: "Replace All"), role: .destructive) {
                importMode = .replace
                confirmImport()
            }
            Button(String(localized: "Cancel"), role: .cancel) {
                pendingImportURL = nil
            }
        } message: {
            Text("Choose how to import connections. 'Merge' will add new connections from the file, while 'Replace All' will remove all existing data first.", comment: "Import mode selection message")
        }
        .confirmationDialog(
            String(localized: "Delete Connection"),
            isPresented: $showingDeleteAlert,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                model.removeSelectedConnection()
            }
            Button(String(localized: "Cancel"), role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete the selected connection?", comment: "Delete connection confirmation message")
        }
        .onChange(of: model.selection) { _, newValue in
            guard let id = newValue,
                  let connection = model.connections.first(where: { $0.id == id })
            else { return }
            model.openConnection(connection)
        }
    }

    private func exportConnections() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "connections.json"
        panel.title = String(localized: "Export Connections")
        if panel.runModal() == .OK, let url = panel.url {
            model.exportConnections(to: url)
        }
    }

    @ViewBuilder
    private var splitView: some View {
        NavigationSplitView {
            List(selection: $model.selection) {
                Section(String(localized: "Recent Connections")) {
                    ForEach(model.filteredConnections) { connection in
                        ConnectionRow(connection: connection, isSelected: model.selection == connection.id) {
                            model.openConnection(connection)
                        }
                        .tag(connection.id)
                        .contextMenu {
                            Button {
                                model.openConnection(connection)
                            } label: {
                                Label(String(localized: "Open in Tab"), systemImage: "terminal")
                            }
                            
                            Divider()
                            
                            Button {
                                editorConnection = connection
                            } label: {
                                Label(String(localized: "Edit"), systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                model.selection = connection.id
                                showingDeleteAlert = true
                            } label: {
                                Label(String(localized: "Delete"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .searchable(text: $model.searchText, placement: .sidebar, prompt: Text(String(localized: "Search connections")))
            .navigationTitle("MacSSH")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    ControlGroup {
                        Button {
                            editorConnection = SSHConnection(name: "", host: "", port: 22, username: "")
                        } label: {
                            Label(String(localized: "Add Connection"), systemImage: "plus")
                        }
                        .keyboardShortcut("n", modifiers: .command)
                        .help(String(localized: "Create a new SSH connection profile"))
                        
                        Button {
                            if let selected = model.selectedConnection {
                                editorConnection = selected
                            }
                        } label: {
                            Label(String(localized: "Edit"), systemImage: "pencil")
                        }
                        .disabled(model.selection == nil)
                        
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label(String(localized: "Delete"), systemImage: "trash")
                        }
                        .disabled(model.selection == nil)
                    }
                }
                
                ToolbarItemGroup(placement: .secondaryAction) {
                    Menu {
                        Button {
                            exportConnections()
                        } label: {
                            Label(String(localized: "Export Connections..."), systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            importConnections()
                        } label: {
                            Label(String(localized: "Import Connections..."), systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Label(String(localized: "Manage"), systemImage: "ellipsis.circle")
                    }
                }
            }
        } detail: {
            if model.openTabs.isEmpty {
                EmptyStateView()
            } else {
                TabView(selection: $model.selectedTabID) {
                    ForEach(model.openTabs) { tab in
                        TerminalView(connection: tab.connection, settings: settings, appModel: model)
                            .tag(tab.id as SessionTab.ID?)
                            .tabItem {
                                Label(tab.connection.name, systemImage: "terminal")
                            }
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.selectedTabID)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(item: $editorConnection) { connection in
            ConnectionEditorView(connection: connection) { updated in
                model.upsertConnection(updated)
                model.openConnection(updated)
            }
        }
    }

    private func importConnections() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = String(localized: "Import Connections")
        if panel.runModal() == .OK, let url = panel.url {
            pendingImportURL = url
            showImportDialog = true
        }
    }

    private func confirmImport() {
        guard let url = pendingImportURL else { return }
        model.importConnections(from: url, mode: importMode)
        pendingImportURL = nil
    }
}

private struct EmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label {
                Text("Start a New Connection", comment: "Empty state title")
                    .font(.title2)
            } icon: {
                Image(systemName: "terminal.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
                    .font(.system(size: 48))
            }
        } description: {
            Text("Select a server from the sidebar to begin your session, or add a new one to get started.", comment: "Empty state description")
                .font(.body)
                .foregroundStyle(.secondary)
        } actions: {
            Text("Shortcut: ⌘N New Connection", comment: "Empty state shortcut hint")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct ConnectionRow: View {
    let connection: SSHConnection
    let isSelected: Bool
    @State private var isHovered = false
    var onConnect: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.blue.opacity(0.1))
                
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.blue.gradient))
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(connection.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Text("\(connection.username)@\(connection.host)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
            }
            
            Spacer()
            
            if isHovered && !isSelected {
                Button {
                    onConnect?()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color.blue.gradient)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}

enum ImportMode {
    case merge
    case replace
}
