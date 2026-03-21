import Foundation

struct SSHConnection: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var keyPath: String?
    var usePublicKey: Bool = false

    init(id: UUID = UUID(), name: String, host: String, port: Int, username: String, keyPath: String? = nil, usePublicKey: Bool = false) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.keyPath = keyPath
        self.usePublicKey = usePublicKey
    }

    var displayName: String {
        "\(name) (\(username)@\(host))"
    }

    var keychainAccount: String {
        id.uuidString
    }

    var defaultKeyPath: String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let defaultPath = home.appendingPathComponent(".ssh/id_ed25519").path
        if FileManager.default.fileExists(atPath: defaultPath) {
            return defaultPath
        }
        let rsaPath = home.appendingPathComponent(".ssh/id_rsa").path
        if FileManager.default.fileExists(atPath: rsaPath) {
            return rsaPath
        }
        return nil
    }
}
