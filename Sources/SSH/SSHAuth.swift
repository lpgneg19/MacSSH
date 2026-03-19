import Foundation

enum SSHAuth {
    case password(String, remember: Bool)
    case publicKey(path: String, passphrase: String?)
}
