import SwiftUI
import AppKit

struct TerminalView: View {
    let connection: SSHConnection
    let settings: AppSettings
    @Bindable var appModel: AppModel

    @State private var model: TerminalSessionViewModel
    @State private var showSftp: Bool = true
    @State private var sftpModel: SFTPViewModel
    @State private var showAuthSheet: Bool = false
    @State private var showReconnectError: Bool = false
    @State private var reconnectErrorMessage: String = ""

    init(connection: SSHConnection, settings: AppSettings, appModel: AppModel) {
        self.connection = connection
        self.settings = settings
        self._appModel = Bindable(appModel)
        let sessionModel = TerminalSessionViewModel(connection: connection)
        _model = State(initialValue: sessionModel)
        _sftpModel = State(initialValue: SFTPViewModel(service: sessionModel.sftpService))
    }

    var body: some View {
        terminalPane
        .navigationTitle(connection.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $showSftp) {
                    Label(String(localized: "SFTP"), systemImage: "sidebar.right")
                }
                .toggleStyle(.button)
                .help(String(localized: "Show SFTP Inspector"))
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(connection.name).font(.headline)
                    HStack(spacing: 6) {
                        if model.status == .connecting {
                            ProgressView().controlSize(.mini)
                        } else {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 6, height: 6)
                        }
                        Text("\(connection.username)@\(connection.host) — \(statusString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button(String(localized: "Credentials"), systemImage: "key") {
                    showAuthSheet = true
                }
                .help(String(localized: "Configure Authentication"))

                if model.status == .connected {
                    Button(String(localized: "Disconnect"), systemImage: "network.slash") {
                        model.disconnect()
                    }
                    .help(String(localized: "Terminate Session"))
                } else {
                    Button(String(localized: "Connect"), systemImage: "network") {
                        model.connect()
                    }
                    .disabled(connectDisabled)
                    .help(String(localized: "Establish Connection"))
                }
            }
        }
        .inspector(isPresented: $showSftp) {
            SFTPPanelView(model: sftpModel)
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
        .sheet(isPresented: $showAuthSheet) {
            AuthSheetView(model: model, pickKeyFile: pickKeyFile)
        }
        .onChange(of: appModel.reconnectRequests[connection.id]) { _, newValue in
            guard newValue != nil else { return }
            Task {
                let success = await model.reconnect()
                if !success {
                    reconnectErrorMessage = model.lastErrorMessage
                    showReconnectError = true
                }
            }
        }
    }

    private var connectDisabled: Bool {
        if settings.renderer == .ghosttySurface {
            return true
        }
        if model.status == .connecting || model.status == .connected {
            return true
        }
        if model.usePublicKey {
            return model.keyPath.isEmpty
        }
        return model.password.isEmpty
    }

    private var currentTabID: SessionTab.ID? {
        appModel.openTabs.first { $0.connection.id == connection.id }?.id
    }

    @ViewBuilder
    private var terminalPane: some View {
        Group {
            if settings.renderer == .ghosttySurface {
                GhosttyTerminalView(settings: settings)
            } else {
                VTTerminalView(model: model, settings: settings)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var statusString: String {
        switch model.status {
        case .idle: return String(localized: "Idle")
        case .connecting: return String(localized: "Connecting...")
        case .connected: return String(localized: "Connected")
        case .failed(let msg): return String(localized: "Error: \(msg)")
        }
    }

    private var statusColor: Color {
        switch model.status {
        case .idle: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .failed: return .red
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

    private func pickKeyFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.data]
        panel.title = String(localized: "Select Private Key")
        if panel.runModal() == .OK, let url = panel.url {
            model.keyPath = url.path
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

private struct AuthSheetView: View {
    @Bindable var model: TerminalSessionViewModel
    let pickKeyFile: () -> Void

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Use Public Key"), isOn: $model.usePublicKey)
                    .toggleStyle(.switch)
            } header: {
                Label(String(localized: "Authentication Mode"), systemImage: "shield.lefthalf.filled")
            }

            if model.usePublicKey {
                Section {
                    HStack(spacing: 8) {
                        TextField(String(localized: "Private key path"), text: $model.keyPath)
                        Button(String(localized: "Browse")) {
                            pickKeyFile()
                        }
                    }
                    SecureField(String(localized: "Passphrase (optional)"), text: $model.keyPassphrase)
                } header: {
                    Text(String(localized: "Public Key Details"))
                } footer: {
                    Text(String(localized: "Select your private key file (e.g., id_rsa) for key-based authentication."))
                }
            } else {
                Section {
                    SecureField(String(localized: "Password"), text: $model.password)
                    Toggle(String(localized: "Remember in keychain"), isOn: $model.rememberPassword)
                } header: {
                    Text(String(localized: "Password Authentication"))
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 300)
        .padding(.horizontal, 10)
    }
}
