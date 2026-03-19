import Foundation
import Observation

@MainActor
@Observable
final class SFTPViewModel {
    enum Status: Equatable {
        case idle
        case loading
        case transferring(String)
        case error(String)
    }

    private let service: SFTPService
    var currentPath: String = "."
    var items: [SFTPItem] = []
    var status: Status = .idle

    init(service: SFTPService) {
        self.service = service
    }

    func refresh() {
        status = .loading
        Task {
            do {
                let items = try await service.list(path: currentPath)
                self.items = items
                status = .idle
            } catch {
                status = .error(error.localizedDescription)
            }
        }
    }

    func changeDirectory(_ item: SFTPItem) {
        guard item.isDirectory else { return }
        currentPath = item.path
        refresh()
    }

    func goUp() {
        guard currentPath != "." else { return }
        let url = URL(fileURLWithPath: currentPath)
        let parent = url.deletingLastPathComponent().path
        currentPath = parent.isEmpty ? "/" : parent
        refresh()
    }

    func download(_ item: SFTPItem, to url: URL) {
        status = .transferring(item.name)
        Task {
            do {
                try await service.download(remotePath: item.path, localURL: url)
                status = .idle
            } catch {
                status = .error(error.localizedDescription)
            }
        }
    }

    func download(_ items: [SFTPItem], to directory: URL) {
        status = .loading
        Task {
            do {
                for item in items where !item.isDirectory {
                    status = .transferring(item.name)
                    let target = directory.appendingPathComponent(item.name)
                    try await service.download(remotePath: item.path, localURL: target)
                }
                status = .idle
            } catch {
                status = .error(error.localizedDescription)
            }
        }
    }

    func upload(from url: URL) {
        status = .transferring(url.lastPathComponent)
        let target = currentPath.hasSuffix("/") ? currentPath + url.lastPathComponent : currentPath + "/" + url.lastPathComponent
        Task {
            do {
                try await service.upload(localURL: url, remotePath: target)
                refresh()
            } catch {
                status = .error(error.localizedDescription)
            }
        }
    }

    func upload(from urls: [URL]) {
        status = .loading
        Task {
            do {
                for url in urls {
                    status = .transferring(url.lastPathComponent)
                    let target = currentPath.hasSuffix("/") ? currentPath + url.lastPathComponent : currentPath + "/" + url.lastPathComponent
                    try await service.upload(localURL: url, remotePath: target)
                }
                refresh()
            } catch {
                status = .error(error.localizedDescription)
            }
        }
    }
}
