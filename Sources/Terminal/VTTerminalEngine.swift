import Foundation

@MainActor
final class VTTerminalEngine {
    private struct RawHandle: @unchecked Sendable {
        var value: UnsafeMutableRawPointer?
    }

    private var terminal = RawHandle(value: nil)
    private var formatter = RawHandle(value: nil)

    init(cols: UInt16 = 80, rows: UInt16 = 24, scrollback: Int = 10_000) {
        guard let handle = GhosttyVTCreateTerminal(cols, rows, max(0, scrollback)) else {
            return
        }
        terminal.value = handle
        guard let formatterHandle = GhosttyVTCreateFormatter(handle) else {
            return
        }
        formatter.value = formatterHandle
    }

    deinit {
        let f = formatter
        let t = terminal
        DispatchQueue.main.async {
            if let fv = f.value {
                GhosttyVTFreeFormatter(fv)
            }
            if let tv = t.value {
                GhosttyVTFreeTerminal(tv)
            }
        }
    }

    func resize(cols: UInt16, rows: UInt16) {
        guard let terminal = terminal.value else { return }
        GhosttyVTResize(terminal, cols, rows)
    }

    func write(_ data: Data) -> String {
        guard let terminal = terminal.value, let formatter = formatter.value else { return "" }
        data.withUnsafeBytes { buffer in
            guard let base = buffer.bindMemory(to: UInt8.self).baseAddress else { return }
            GhosttyVTWrite(terminal, base, buffer.count)
        }
        return format(formatter)
    }

    func formatCurrent() -> String {
        guard let formatter = formatter.value else { return "" }
        return format(formatter)
    }

    private func format(_ formatter: UnsafeMutableRawPointer) -> String {
        var outLen: Int = 0
        guard let outPtr = GhosttyVTFormatAlloc(formatter, &outLen) else {
            return ""
        }
        defer { free(outPtr) }
        return String(decoding: Data(bytes: outPtr, count: Int(outLen)), as: UTF8.self)
    }
}
