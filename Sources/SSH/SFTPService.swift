import Foundation
import libssh2

actor SFTPService {
    enum SFTPError: LocalizedError {
        case notConnected
        case initFailed
        case openDirFailed
        case readFailed
        case openFileFailed
        case writeFailed
        case localIOFailed

        var errorDescription: String? {
            switch self {
            case .notConnected: return "SFTP not connected"
            case .initFailed: return "SFTP init failed"
            case .openDirFailed: return "SFTP open directory failed"
            case .readFailed: return "SFTP read failed"
            case .openFileFailed: return "SFTP open file failed"
            case .writeFailed: return "SFTP write failed"
            case .localIOFailed: return "Local IO failed"
            }
        }
    }

    private let session: SSHSession

    init(session: SSHSession) {
        self.session = session
    }

    func list(path: String) async throws -> [SFTPItem] {
        return try await session.withRawSession { sessionPtr in
            guard let sftp = libssh2_sftp_init(sessionPtr) else { throw SFTPError.initFailed }
            defer { libssh2_sftp_shutdown(sftp) }

            guard let dir = libssh2_sftp_open_ex(
                sftp,
                path,
                UInt32(path.utf8.count),
                0,
                0,
                Int32(LIBSSH2_SFTP_OPENDIR)
            ) else { throw SFTPError.openDirFailed }
            defer { libssh2_sftp_close_handle(dir) }

            var items: [SFTPItem] = []
            var nameBuffer = [Int8](repeating: 0, count: 1024)
            var longBuffer = [Int8](repeating: 0, count: 2048)
            var attrs = LIBSSH2_SFTP_ATTRIBUTES()

            while true {
                let rc = libssh2_sftp_readdir_ex(dir, &nameBuffer, nameBuffer.count, &longBuffer, longBuffer.count, &attrs)
                if rc > 0 {
                    let name = nameBuffer.withUnsafeBufferPointer { ptr in
                        let length = ptr.prefix(while: { $0 != 0 }).count
                        return String(decoding: UnsafeRawBufferPointer(start: ptr.baseAddress, count: length), as: UTF8.self)
                    }
                    if name == "." || name == ".." { continue }
                    let isDir: Bool
                    let attrPermissions = UInt(LIBSSH2_SFTP_ATTR_PERMISSIONS)
                    let permMask = UInt(LIBSSH2_SFTP_S_IFMT)
                    let permDir = UInt(LIBSSH2_SFTP_S_IFDIR)
                    if (attrs.flags & attrPermissions) != 0 {
                        isDir = (attrs.permissions & permMask) == permDir
                    } else {
                        isDir = false
                    }
                    let attrSize = UInt(LIBSSH2_SFTP_ATTR_SIZE)
                    let size: UInt64? = (attrs.flags & attrSize) != 0 ? attrs.filesize : nil
                    let fullPath = path.hasSuffix("/") ? path + name : path + "/" + name
                    items.append(SFTPItem(name: name, path: fullPath, isDirectory: isDir, size: size))
                    continue
                }
                if rc == 0 { break }
                throw SFTPError.readFailed
            }

            return items.sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory && !rhs.isDirectory
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    func download(remotePath: String, localURL: URL) async throws {
        try await session.withRawSession { sessionPtr in
            guard let sftp = libssh2_sftp_init(sessionPtr) else { throw SFTPError.initFailed }
            defer { libssh2_sftp_shutdown(sftp) }

            guard let handle = libssh2_sftp_open_ex(
                sftp,
                remotePath,
                UInt32(remotePath.utf8.count),
                UInt(LIBSSH2_FXF_READ),
                0,
                Int32(LIBSSH2_SFTP_OPENFILE)
            ) else {
                throw SFTPError.openFileFailed
            }
            defer { libssh2_sftp_close_handle(handle) }

            guard FileManager.default.createFile(atPath: localURL.path, contents: nil) else {
                throw SFTPError.localIOFailed
            }
            guard let fileHandle = try? FileHandle(forWritingTo: localURL) else {
                throw SFTPError.localIOFailed
            }
            defer { try? fileHandle.close() }

            var buffer = [UInt8](repeating: 0, count: 32 * 1024)
            while true {
                let rc = buffer.withUnsafeMutableBytes { rawBuffer in
                    libssh2_sftp_read(handle, rawBuffer.bindMemory(to: Int8.self).baseAddress, rawBuffer.count)
                }
                if rc > 0 {
                    fileHandle.write(Data(buffer[0..<rc]))
                    continue
                }
                if rc == 0 { break }
                throw SFTPError.readFailed
            }
        }
    }

    func upload(localURL: URL, remotePath: String) async throws {
        try await session.withRawSession { sessionPtr in
            guard let sftp = libssh2_sftp_init(sessionPtr) else { throw SFTPError.initFailed }
            defer { libssh2_sftp_shutdown(sftp) }

            let flags = UInt(LIBSSH2_FXF_WRITE | LIBSSH2_FXF_CREAT | LIBSSH2_FXF_TRUNC)
            guard let handle = libssh2_sftp_open_ex(
                sftp,
                remotePath,
                UInt32(remotePath.utf8.count),
                flags,
                0o644,
                Int32(LIBSSH2_SFTP_OPENFILE)
            ) else {
                throw SFTPError.openFileFailed
            }
            defer { libssh2_sftp_close_handle(handle) }

            guard let fileHandle = try? FileHandle(forReadingFrom: localURL) else {
                throw SFTPError.localIOFailed
            }
            defer { try? fileHandle.close() }

            while true {
                let data = fileHandle.readData(ofLength: 32 * 1024)
                if data.isEmpty { break }
                let rc = data.withUnsafeBytes { buffer in
                    libssh2_sftp_write(handle, buffer.bindMemory(to: Int8.self).baseAddress, buffer.count)
                }
                if rc < 0 { throw SFTPError.writeFailed }
            }
        }
    }
}
