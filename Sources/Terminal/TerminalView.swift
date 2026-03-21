import SwiftUI
import AppKit

struct TerminalView: View {
    let tab: SessionTab
    let settings: AppSettings
    @Bindable var appModel: AppModel

    @State private var showSftp: Bool = true
    @State private var showReconnectError: Bool = false
    @State private var reconnectErrorMessage: String = ""
    @FocusState private var isTerminalFocused: Bool

    private var model: TerminalSessionViewModel {
        if let existing = tab.terminalModel {
            return existing
        }
        let newModel = TerminalSessionViewModel(connection: tab.connection)
        tab.terminalModel = newModel
        return newModel
    }

    var body: some View {
        @Bindable var model = self.model
        @Bindable var settings = self.settings

        VStack(spacing: 0) {
            GhosttyTerminalView(tab: tab, settings: settings)
                .id("ghostty-\(tab.id)-\(settings.fontSize)-\(appModel.reconnectRequests[tab.connection.id]?.uuidString ?? "")")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(tab.connection.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    appModel.requestReconnect(connectionID: tab.connection.id)
                } label: {
                    Label(String(localized: "Reconnect"), systemImage: "arrow.clockwise")
                }
                .help(String(localized: "Restart Terminal Session"))

                Button {
                    appModel.closeTab(tab.id)
                } label: {
                    Label(String(localized: "Disconnect"), systemImage: "network.slash")
                }
                .help(String(localized: "Close Session Tab"))

                Toggle(isOn: $showSftp) {
                    Label(String(localized: "SFTP"), systemImage: "sidebar.right")
                }
                .toggleStyle(.button)
                .help(String(localized: "Show SFTP Inspector"))
            }
        }
        .inspector(isPresented: $showSftp) {
            SFTPPanelView(model: model.sftpViewModel)
        }
        .task {
            model.connect()
        }
        .inspectorColumnWidth(min: 280, ideal: 340)
        .confirmationDialog(
            hostKeyPromptTitle,
            isPresented: hostKeyPromptBinding,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Trust and Continue")) {
                model.trustHostKeyAndConnect()
            }
            Button(String(localized: "Cancel"), role: .cancel) {
                model.hostKeyPrompt = nil
            }
        } message: {
            Text(hostKeyPromptMessage)
        }
        .alert(String(localized: "Reconnect Failed"), isPresented: $showReconnectError) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(reconnectErrorMessage)
        }
    }

    private var hostKeyPromptTitle: String {
        guard let prompt = model.hostKeyPrompt else { return "" }
        switch prompt.status {
        case .notFound:
            return String(localized: "Unknown Host Key")
        case .mismatch:
            return String(localized: "Host Key Changed")
        }
    }

    private var hostKeyPromptMessage: String {
        guard let prompt = model.hostKeyPrompt else { return "" }
        switch prompt.status {
        case .notFound:
            return String(localized: "The authenticity of \(prompt.host) can't be established. Do you want to trust this host key and continue?")
        case .mismatch:
            return String(localized: "WARNING: The host key for \(prompt.host) has changed. This could indicate a security issue. Only continue if you trust the new key.")
        }
    }

    private var hostKeyPromptBinding: Binding<Bool> {
        Binding(
            get: { model.hostKeyPrompt != nil },
            set: { newValue in
                if !newValue { model.hostKeyPrompt = nil }
            }
        )
    }

}
