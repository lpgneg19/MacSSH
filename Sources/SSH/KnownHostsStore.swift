import Foundation
import libssh2

enum HostKeyCheckResult {
    case match
    case notFound(Data, Int32)
    case mismatch(Data, Int32)
}

struct KnownHostsStore {
    private static func knownHostKeyMask(for hostKeyType: Int32) -> Int32 {
        switch hostKeyType {
        case Int32(LIBSSH2_HOSTKEY_TYPE_RSA):
            return Int32(LIBSSH2_KNOWNHOST_KEY_SSHRSA)
        case Int32(LIBSSH2_HOSTKEY_TYPE_DSS):
            return Int32(LIBSSH2_KNOWNHOST_KEY_SSHDSS)
        case Int32(LIBSSH2_HOSTKEY_TYPE_ECDSA_256):
            return Int32(LIBSSH2_KNOWNHOST_KEY_ECDSA_256)
        case Int32(LIBSSH2_HOSTKEY_TYPE_ECDSA_384):
            return Int32(LIBSSH2_KNOWNHOST_KEY_ECDSA_384)
        case Int32(LIBSSH2_HOSTKEY_TYPE_ECDSA_521):
            return Int32(LIBSSH2_KNOWNHOST_KEY_ECDSA_521)
        case Int32(LIBSSH2_HOSTKEY_TYPE_ED25519):
            return Int32(LIBSSH2_KNOWNHOST_KEY_ED25519)
        default:
            return Int32(LIBSSH2_KNOWNHOST_KEY_UNKNOWN)
        }
    }

    static func defaultPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".ssh/known_hosts").path
    }

    static func check(session: OpaquePointer, host: String, port: Int) throws -> HostKeyCheckResult {
        guard let knownHosts = libssh2_knownhost_init(session) else {
            throw SSHError.knownHostsInitFailed
        }
        defer { libssh2_knownhost_free(knownHosts) }

        let path = defaultPath()
        _ = libssh2_knownhost_readfile(knownHosts, path, LIBSSH2_KNOWNHOST_FILE_OPENSSH)

        var hostKeyLen: Int = 0
        var hostKeyType: Int32 = 0
        guard let hostKeyPtr = libssh2_session_hostkey(session, &hostKeyLen, &hostKeyType),
              hostKeyLen > 0
        else {
            throw SSHError.hostKeyUnavailable
        }
        let keyData = Data(bytes: hostKeyPtr, count: hostKeyLen)
        let keyMask = knownHostKeyMask(for: hostKeyType)
        let typeMask = Int32(LIBSSH2_KNOWNHOST_TYPE_PLAIN | LIBSSH2_KNOWNHOST_KEYENC_RAW) | keyMask

        var knownHost: UnsafeMutablePointer<libssh2_knownhost>?
        let check = libssh2_knownhost_checkp(
            knownHosts,
            host,
            Int32(port),
            hostKeyPtr,
            hostKeyLen,
            typeMask,
            &knownHost
        )

        switch check {
        case LIBSSH2_KNOWNHOST_CHECK_MATCH:
            return .match
        case LIBSSH2_KNOWNHOST_CHECK_NOTFOUND:
            return .notFound(keyData, hostKeyType)
        case LIBSSH2_KNOWNHOST_CHECK_MISMATCH:
            return .mismatch(keyData, hostKeyType)
        default:
            throw SSHError.knownHostsCheckFailed(check)
        }
    }

    static func addOrReplace(session: OpaquePointer, host: String, port: Int, keyData: Data, keyType: Int32, replace: Bool) throws {
        guard let knownHosts = libssh2_knownhost_init(session) else {
            throw SSHError.knownHostsInitFailed
        }
        defer { libssh2_knownhost_free(knownHosts) }

        let path = defaultPath()
        _ = libssh2_knownhost_readfile(knownHosts, path, LIBSSH2_KNOWNHOST_FILE_OPENSSH)

        if replace {
            keyData.withUnsafeBytes { buffer in
                guard let base = buffer.bindMemory(to: Int8.self).baseAddress else { return }
                var knownHost: UnsafeMutablePointer<libssh2_knownhost>?
                let keyMask = knownHostKeyMask(for: keyType)
                let typeMask = Int32(LIBSSH2_KNOWNHOST_TYPE_PLAIN | LIBSSH2_KNOWNHOST_KEYENC_RAW) | keyMask
                _ = libssh2_knownhost_checkp(
                    knownHosts,
                    host,
                    Int32(port),
                    base,
                    buffer.count,
                    typeMask,
                    &knownHost
                )
                if let knownHost {
                    libssh2_knownhost_del(knownHosts, knownHost)
                }
            }
        }

        let addResult = keyData.withUnsafeBytes { buffer -> Int32 in
            guard let base = buffer.bindMemory(to: Int8.self).baseAddress else { return -1 }
            let keyMask = knownHostKeyMask(for: keyType)
            let typeMask = Int32(LIBSSH2_KNOWNHOST_TYPE_PLAIN | LIBSSH2_KNOWNHOST_KEYENC_RAW) | keyMask
            return libssh2_knownhost_addc(
                knownHosts,
                host,
                nil,
                base,
                buffer.count,
                nil,
                0,
                typeMask,
                nil
            )
        }
        guard addResult == 0 else {
            throw SSHError.knownHostsWriteFailed(addResult)
        }
        _ = libssh2_knownhost_writefile(knownHosts, path, LIBSSH2_KNOWNHOST_FILE_OPENSSH)
    }
}
