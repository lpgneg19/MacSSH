import Foundation
import Observation

@MainActor
@Observable
final class TerminalSessionViewModel {
    enum Status: Equatable {
        case idle
        case connecting
        case connected
        case failed(String)
    }

    struct HostKeyPrompt: Identifiable {
        let id = UUID()
        let host: String
        let status: HostKeyStatus
    }

    let connection: SSHConnection
    private let session: SSHSession
    let sftpService: SFTPService
    let sftpViewModel: SFTPViewModel

    var status: Status = .idle
    var password: String = ""
    var rememberPassword: Bool = false
    var usePublicKey: Bool = false
    var keyPath: String = ""
    var keyPassphrase: String = ""
    var hostKeyPrompt: HostKeyPrompt?
    var lastErrorMessage: String = ""
    
    // Rows/Cols are now managed by the Metal view, but we keep them for logic/API if needed
    var cols: UInt16 = 80
    var rows: UInt16 = 24

    init(connection: SSHConnection) {
        self.connection = connection
        self.session = SSHSession()
        self.sftpService = SFTPService(session: self.session)
        self.sftpViewModel = SFTPViewModel(service: self.sftpService)

        let account = connection.keychainAccount
        if let stored = KeychainStore.loadPassword(account: account) {
            self.password = stored
            self.rememberPassword = true
        }

        self.usePublicKey = connection.usePublicKey
        if connection.usePublicKey {
            if let customKey = connection.keyPath, !customKey.isEmpty {
                self.keyPath = customKey
            } else if let defaultKey = connection.defaultKeyPath {
                self.keyPath = defaultKey
            }
        }
    }

    deinit {
        let activeSession = self.session
        Task.detached {
            await activeSession.disconnect()
        }
    }

    func connect() {
        guard status != .connected else { return }
        status = .connecting

        let auth = makeAuth()

        Task {
            do {
                _ = try await session.connect(connection: connection, auth: auth)
                status = .connected
                handlePasswordPersistence(auth)
                sftpViewModel.refresh()
            } catch let error as SSHError {
                switch error {
                case .hostKeyNotTrusted(let status):
                    hostKeyPrompt = HostKeyPrompt(host: connection.host, status: status)
                    self.status = .idle
                default:
                    self.status = .failed(error.localizedDescription)
                }
            } catch {
                status = .failed(error.localizedDescription)
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func trustHostKeyAndConnect() {
        guard status != .connected else { return }
        status = .connecting
        let auth = makeAuth()
        Task {
            do {
                _ = try await session.acceptHostKeyAndConnect(auth: auth)
                hostKeyPrompt = nil
                status = .connected
                handlePasswordPersistence(auth)
            } catch {
                status = .failed(error.localizedDescription)
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func disconnect() {
        Task {
            await session.disconnect()
            status = .idle
        }
    }

    private func makeAuth() -> SSHAuth {
        if usePublicKey, !keyPath.isEmpty {
            let passphrase = keyPassphrase.isEmpty ? nil : keyPassphrase
            return .publicKey(path: keyPath, passphrase: passphrase)
        }
        return .password(password, remember: rememberPassword)
    }

    private func handlePasswordPersistence(_ auth: SSHAuth) {
        if case .password(let pwd, let remember) = auth {
            let account = connection.keychainAccount
            if remember {
                KeychainStore.savePassword(pwd, account: account)
            } else {
                KeychainStore.deletePassword(account: account)
            }
        }
    }
}
