import Foundation
import Observation

@Observable
final class SessionTab: Identifiable {
    let id: UUID
    let connection: SSHConnection
    var terminalModel: TerminalSessionViewModel?

    init(connection: SSHConnection) {
        self.id = UUID()
        self.connection = connection
    }
}
