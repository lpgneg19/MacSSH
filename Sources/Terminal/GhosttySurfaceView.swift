import AppKit
import Foundation
import GhosttyKit

@MainActor
final class GhosttySurfaceView: NSView {
    private let runtime: GhosttyRuntime
    private struct SurfaceHandle: @unchecked Sendable {
        var value: ghostty_surface_t?
    }
    private var surface = SurfaceHandle(value: nil)
    private var surfaceConfig = GhosttySurfaceConfiguration()

    init(runtime: GhosttyRuntime = .shared, config: GhosttySurfaceConfiguration = GhosttySurfaceConfiguration()) {
        self.runtime = runtime
        self.surfaceConfig = config
        super.init(frame: .zero)
        wantsLayer = true
        setupSurfaceIfPossible()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    deinit {
        guard let surface = surface.value else { return }
        DispatchQueue.main.async {
            ghostty_surface_free(surface)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result, let surface = surface.value { ghostty_surface_set_focus(surface, true) }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result, let surface = surface.value { ghostty_surface_set_focus(surface, false) }
        return result
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateContentScale()
        // Re-evaluate size after the window has assigned us a proper frame
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateSurfaceSize()
            self.window?.makeFirstResponder(self)
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateSurfaceSize()
    }

    override func layout() {
        super.layout()
        updateSurfaceSize()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateContentScale()
    }

    override func keyDown(with event: NSEvent) {
        guard let surface = surface.value else { return }
        var keyEvent = event.ghosttyKeyEvent(GHOSTTY_ACTION_PRESS)
        if let text = event.ghosttyCharacters {
            text.withCString { cString in
                keyEvent.text = cString
                ghostty_surface_key(surface, keyEvent)
            }
        } else {
            ghostty_surface_key(surface, keyEvent)
        }
    }

    override func keyUp(with event: NSEvent) {
        guard let surface = surface.value else { return }
        let keyEvent = event.ghosttyKeyEvent(GHOSTTY_ACTION_RELEASE)
        ghostty_surface_key(surface, keyEvent)
    }

    override func flagsChanged(with event: NSEvent) {
        guard let surface = surface.value else { return }
        let keyEvent = event.ghosttyKeyEvent(GHOSTTY_ACTION_PRESS)
        ghostty_surface_key(surface, keyEvent)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.rightMouseDown(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        guard let surface = surface.value else { return }
        let deltaY = event.scrollingDeltaY
        guard abs(deltaY) > 0.1 else { return }

        // macOS up-arrow = 0x7E, down-arrow = 0x7D.
        // scrollingDeltaY > 0  → user dragged finger up → content scrolls up → we need "up-arrow" to walk
        // through scrollback (older lines).
        let arrowKeyCode: UInt32 = deltaY > 0 ? 0x7E : 0x7D
        let rows = max(1, Int(abs(deltaY) / 3.0))

        for _ in 0..<rows {
            var pressEvent = ghostty_input_key_s()
            pressEvent.action = GHOSTTY_ACTION_PRESS
            pressEvent.keycode = arrowKeyCode
            pressEvent.mods = ghostty_input_mods_e(GHOSTTY_MODS_NONE.rawValue)
            pressEvent.consumed_mods = ghostty_input_mods_e(GHOSTTY_MODS_NONE.rawValue)
            pressEvent.composing = false
            pressEvent.text = nil
            pressEvent.unshifted_codepoint = 0
            ghostty_surface_key(surface, pressEvent)

            var releaseEvent = pressEvent
            releaseEvent.action = GHOSTTY_ACTION_RELEASE
            ghostty_surface_key(surface, releaseEvent)
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    private func setupSurfaceIfPossible() {
        guard let app = runtime.app else { return }
        var config = ghostty_surface_config_new()

        config.userdata = Unmanaged.passUnretained(self).toOpaque()
        config.platform_tag = GHOSTTY_PLATFORM_MACOS
        config.platform = ghostty_platform_u(macos: ghostty_platform_macos_s(
            nsview: Unmanaged.passUnretained(self).toOpaque()
        ))
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        config.scale_factor = Double(scale)
        config.font_size = max(10.0, surfaceConfig.fontSize)
        config.wait_after_command = surfaceConfig.waitAfterCommand
        config.context = surfaceConfig.context

        let workingDirectory = surfaceConfig.workingDirectory
        let command = surfaceConfig.command
        let initialInput = surfaceConfig.initialInput

        var envVars = surfaceConfig.environmentVariables.map { key, value in
            ghostty_env_var_s(key: strdup(key), value: strdup(value))
        }

        let createSurface: () -> Void = {
            envVars.withUnsafeMutableBufferPointer { buffer in
                config.env_vars = buffer.baseAddress
                config.env_var_count = buffer.count
                self.surface.value = ghostty_surface_new(app, &config)
            }
        }

        if let workingDirectory, let command, let initialInput {
            workingDirectory.withCString { wd in
                config.working_directory = wd
                command.withCString { cmd in
                    config.command = cmd
                    initialInput.withCString { input in
                        config.initial_input = input
                        createSurface()
                    }
                }
            }
        } else if let workingDirectory, let command {
            workingDirectory.withCString { wd in
                config.working_directory = wd
                command.withCString { cmd in
                    config.command = cmd
                    createSurface()
                }
            }
        } else if let workingDirectory, let initialInput {
            workingDirectory.withCString { wd in
                config.working_directory = wd
                initialInput.withCString { input in
                    config.initial_input = input
                    createSurface()
                }
            }
        } else if let command, let initialInput {
            command.withCString { cmd in
                config.command = cmd
                initialInput.withCString { input in
                    config.initial_input = input
                    createSurface()
                }
            }
        } else if let workingDirectory {
            workingDirectory.withCString { wd in
                config.working_directory = wd
                createSurface()
            }
        } else if let command {
            command.withCString { cmd in
                config.command = cmd
                createSurface()
            }
        } else if let initialInput {
            initialInput.withCString { input in
                config.initial_input = input
                createSurface()
            }
        } else {
            createSurface()
        }

        for env in envVars {
            if let key = env.key { free(UnsafeMutableRawPointer(mutating: key)) }
            if let value = env.value { free(UnsafeMutableRawPointer(mutating: value)) }
        }
    }

    private func updateContentScale() {
        guard let surface = surface.value else { return }
        let backingFrame = convertToBacking(bounds)
        guard bounds.width > 0, bounds.height > 0 else { return }
        let xScale = backingFrame.width / bounds.width
        let yScale = backingFrame.height / bounds.height
        ghostty_surface_set_content_scale(surface, xScale, yScale)
    }

    private func updateSurfaceSize() {
        guard let surface = surface.value else { return }
        let size = convertToBacking(bounds.size)
        guard size.width > 0, size.height > 0 else { return }
        ghostty_surface_set_size(surface, UInt32(size.width), UInt32(size.height))
    }
}

struct GhosttySurfaceConfiguration {
    var fontSize: Float = 0
    var workingDirectory: String?
    var command: String?
    var environmentVariables: [String: String] = [:]
    var initialInput: String?
    var waitAfterCommand: Bool = false
    var context: ghostty_surface_context_e = GHOSTTY_SURFACE_CONTEXT_WINDOW
}
