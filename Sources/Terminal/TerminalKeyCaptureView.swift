import SwiftUI
import AppKit

struct TerminalKeyCaptureView: NSViewRepresentable {
    let onBytes: (Data) -> Void
    var onFocusChanged: ((Bool) -> Void)? = nil

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onBytes = onBytes
        view.onFocusChanged = onFocusChanged
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onBytes = onBytes
        nsView.onFocusChanged = onFocusChanged
    }

    final class KeyCaptureNSView: NSView {
        var onBytes: ((Data) -> Void)?
        var onFocusChanged: ((Bool) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self)
                self.onFocusChanged?(self.window?.firstResponder === self)
            }
        }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            onFocusChanged?(true)
            super.mouseDown(with: event)
        }

        override func rightMouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            onFocusChanged?(true)
            super.rightMouseDown(with: event)
        }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
        }

        override func becomeFirstResponder() -> Bool {
            let result = super.becomeFirstResponder()
            if result { onFocusChanged?(true) }
            return result
        }

        override func resignFirstResponder() -> Bool {
            let result = super.resignFirstResponder()
            if result { onFocusChanged?(false) }
            return result
        }

        override func keyDown(with event: NSEvent) {
            if let bytes = mapSpecialKey(event: event) {
                onBytes?(bytes)
                return
            }

            if let text = event.characters {
                onBytes?(Data(text.utf8))
            }
        }

        private func mapSpecialKey(event: NSEvent) -> Data? {
            switch event.keyCode {
            case 36: // Return
                return Data([0x0D])
            case 48: // Tab
                return Data([0x09])
            case 51: // Delete (backspace)
                return Data([0x7F])
            case 53: // Escape
                return Data([0x1B])
            case 123: // Left
                return Data("\u{1b}[D".utf8)
            case 124: // Right
                return Data("\u{1b}[C".utf8)
            case 125: // Down
                return Data("\u{1b}[B".utf8)
            case 126: // Up
                return Data("\u{1b}[A".utf8)
            case 115: // Home
                return Data("\u{1b}[H".utf8)
            case 119: // End
                return Data("\u{1b}[F".utf8)
            case 116: // Page Up
                return Data("\u{1b}[5~".utf8)
            case 121: // Page Down
                return Data("\u{1b}[6~".utf8)
            case 117: // Forward Delete
                return Data("\u{1b}[3~".utf8)
            default:
                return nil
            }
        }
    }
}
