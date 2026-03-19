import AppKit
import Foundation
import GhosttyKit

@MainActor
final class GhosttyRuntime {
    static let shared = GhosttyRuntime()

    private(set) var app: ghostty_app_t?
    private(set) var config: ghostty_config_t?

    private init() {
        _ = ghostty_init(0, nil)

        let cfg = ghostty_config_new()
        if let cfg {
            ghostty_config_load_default_files(cfg)
            ghostty_config_finalize(cfg)
        }
        self.config = cfg

        var runtimeCfg = ghostty_runtime_config_s(
            userdata: Unmanaged.passUnretained(self).toOpaque(),
            supports_selection_clipboard: true,
            wakeup_cb: { userdata in
                guard let userdata else { return }
                DispatchQueue.main.async {
                    let runtime = Unmanaged<GhosttyRuntime>.fromOpaque(userdata).takeUnretainedValue()
                    runtime.appTick()
                }
            },
            action_cb: { _, _, _ in
                false
            },
            read_clipboard_cb: { _, _, _ in
                false
            },
            confirm_read_clipboard_cb: { _, _, _, _ in },
            write_clipboard_cb: { _, _, _, _, _ in },
            close_surface_cb: { _, _ in }
        )

        if let cfg {
            self.app = ghostty_app_new(&runtimeCfg, cfg)
        }
    }

    private func appTick() {
        guard let app else { return }
        ghostty_app_tick(app)
    }
}
