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
    private let engine: VTTerminalEngine
    private let session: SSHSession
    let sftpService: SFTPService

    var status: Status = .idle
    var displayText: String = ""
    var password: String = ""
    var rememberPassword: Bool = false
    var usePublicKey: Bool = false
    var keyPath: String = ""
    var keyPassphrase: String = ""
    var hostKeyPrompt: HostKeyPrompt?
    var lastErrorMessage: String = ""

    init(connection: SSHConnection) {
        self.connection = connection
        self.engine = VTTerminalEngine()
        self.session = SSHSession()
        self.sftpService = SFTPService(session: self.session)

        let account = connection.keychainAccount
        if let stored = KeychainStore.loadPassword(account: account) {
            self.password = stored
            self.rememberPassword = true
        }

        if let defaultKey = connection.defaultKeyPath {
            self.keyPath = defaultKey
        }

        Task {
            seed()
        }
    }

    func connect() {
        guard status != .connected else { return }
        status = .connecting

        let auth = makeAuth()

        Task {
            do {
                let stream = try await session.connect(connection: connection, auth: auth)
                status = .connected
                handlePasswordPersistence(auth)
                await readLoop(stream)
            } catch let error as SSHError {
                switch error {
                case .hostKeyNotTrusted(let status):
                    hostKeyPrompt = HostKeyPrompt(host: connection.host, status: status)
                    self.status = .idle
                default:
                    self.status = .failed(error.localizedDescription)
                    let errorLabel = String(localized: "[error]")
                    append(text: "\n\(errorLabel) \(error.localizedDescription)\n")
                }
            } catch {
                status = .failed(error.localizedDescription)
                lastErrorMessage = error.localizedDescription
                let errorLabel = String(localized: "[error]")
                append(text: "\n\(errorLabel) \(error.localizedDescription)\n")
            }
        }
    }

    func trustHostKeyAndConnect() {
        guard status != .connected else { return }
        status = .connecting
        let auth = makeAuth()
        Task {
            do {
                let stream = try await session.acceptHostKeyAndConnect(auth: auth)
                hostKeyPrompt = nil
                status = .connected
                handlePasswordPersistence(auth)
                await readLoop(stream)
            } catch {
                status = .failed(error.localizedDescription)
                lastErrorMessage = error.localizedDescription
                let errorLabel = String(localized: "[error]")
                append(text: "\n\(errorLabel) \(error.localizedDescription)\n")
            }
        }
    }

    func disconnect() {
        Task {
            status = .idle
            append(text: "\n" + String(localized: "[disconnected]") + "\n")
        }
    }

    func reconnect() async -> Bool {
        await session.disconnect()
        status = .connecting
        let auth = makeAuth()
        do {
            let stream = try await session.connect(connection: connection, auth: auth)
            status = .connected
            handlePasswordPersistence(auth)
            Task { await readLoop(stream) }
            return true
        } catch {
            status = .failed(error.localizedDescription)
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    func sendBytes(_ data: Data) {
        Task {
            do {
                try await session.send(data)
            } catch {
                let errorLabel = String(localized: "[send error]")
                append(text: "\n\(errorLabel) \(error.localizedDescription)\n")
            }
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

    private func readLoop(_ stream: AsyncStream<Data>) async {
        for await data in stream {
            let formatted = engine.write(data)
            displayText = formatted
        }
        status = .idle
    }

    private func append(text: String) {
        let formatted = engine.write(Data(text.utf8))
        displayText = formatted
    }

    private func seed() {
        let banner = String(localized: "MacSSH ready. Connect to start a session.\n")
        let formatted = engine.write(Data(banner.utf8))
        displayText = formatted
    }
}
