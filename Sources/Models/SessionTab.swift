import Foundation

struct SessionTab: Identifiable, Hashable {
    let id: UUID
    let connection: SSHConnection

    init(connection: SSHConnection) {
        self.id = UUID()
        self.connection = connection
    }
}
