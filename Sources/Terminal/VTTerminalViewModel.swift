import Foundation
import Observation

@MainActor
@Observable
final class VTTerminalViewModel {
    private let engine: VTTerminalEngine

    var displayText: String = ""

    init(engine: VTTerminalEngine = VTTerminalEngine()) {
        self.engine = engine
        Task {
            seed()
        }
    }

    func writeString(_ text: String) {
        Task {
            let data = Data(text.utf8)
            let formatted = engine.write(data)
            displayText = formatted
        }
    }

    func resize(cols: UInt16, rows: UInt16) {
        Task {
            engine.resize(cols: cols, rows: rows)
            displayText = engine.formatCurrent()
        }
    }

    private func seed() {
        let banner = "MacSSH ready. Connect to a host to start a session.\n"
        let formatted = engine.write(Data(banner.utf8))
        displayText = formatted
    }
}
