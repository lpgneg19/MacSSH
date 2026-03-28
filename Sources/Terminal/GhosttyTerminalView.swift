import SwiftUI

// MARK: - Surface View Host (persistent surface reuse)

/// Hosts a pre-existing GhosttySurfaceView without ever creating a new one.
/// Use this when the GhosttySurfaceView is owned by a long-lived model object
/// (SessionTab.cachedSurface, LocalTerminalTab.surfaceView) so that the PTY
/// process survives SwiftUI navigation.
struct SurfaceViewHost: NSViewRepresentable {
    let surface: GhosttySurfaceView

    func makeNSView(context: Context) -> GhosttySurfaceView { surface }
    func updateNSView(_ nsView: GhosttySurfaceView, context: Context) {}
}

// MARK: - GhosttyTerminalView (creates a surface on first use, caches it back)

/// Used by TerminalView (SSH) and LocalTerminalView.
/// Pass a `tab`/`localTab` that stores `cachedSurface`/`surfaceView`.
/// On first make, builds configuration and stores the surface on the caller's model.
struct GhosttyTerminalView: NSViewRepresentable {
    var tab: SessionTab? = nil
    let settings: AppSettings

    var configuration: GhosttySurfaceConfiguration {
        var config = GhosttySurfaceConfiguration()
        config.fontSize = Float(settings.fontSize)

        if let tab = self.tab {
            let connection = tab.connection

            if !connection.usePublicKey,
               let password = KeychainStore.loadPassword(account: connection.keychainAccount),
               !password.isEmpty {
                let uuidStr = connection.id.uuidString
                let scriptPath = NSTemporaryDirectory() + "macssh_\(uuidStr).exp"
                let pwdPath = NSTemporaryDirectory() + "macssh_\(uuidStr).pwd"

                try? password.write(toFile: pwdPath, atomically: true, encoding: .utf8)
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: pwdPath)

                let expectScript = """
                #!/usr/bin/expect -f
                set fp [open "\(pwdPath)" r]
                set pwd [read -nonewline $fp]
                close $fp
                set timeout -1
                spawn /usr/bin/ssh -p \(connection.port) -o StrictHostKeyChecking=no \(connection.username)@\(connection.host)
                expect {
                    "*assword:*" { send "$pwd\\r"; exp_continue }
                    "*yes/no*" { send "yes\\r"; exp_continue }
                    eof { exit }
                }
                interact
                """
                try? expectScript.write(toFile: scriptPath, atomically: true, encoding: .utf8)
                try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptPath)

                config.command = "/usr/bin/expect \(scriptPath)"
            } else {
                var commandParts = ["/usr/bin/ssh"]
                commandParts.append("-p")
                commandParts.append("\(connection.port)")
                commandParts.append("-o")
                commandParts.append("StrictHostKeyChecking=no")

                if connection.usePublicKey {
                    if let keyPath = connection.keyPath, !keyPath.isEmpty {
                        commandParts.append("-i")
                        commandParts.append(keyPath)
                    } else if let defaultKey = connection.defaultKeyPath {
                        commandParts.append("-i")
                        commandParts.append(defaultKey)
                    }
                }

                commandParts.append("\(connection.username)@\(connection.host)")
                config.command = commandParts.joined(separator: " ")
            }
        } else {
            var env = ProcessInfo.processInfo.environment
            if env["TERM"] == nil || env["TERM"] == "dumb" {
                env["TERM"] = "xterm-256color"
            }
            config.environmentVariables = env
        }

        config.workingDirectory = NSHomeDirectory()
        return config
    }

    func makeNSView(context: Context) -> GhosttySurfaceView {
        // If the tab already has a cached surface, return it directly.
        // This is the hot path: SwiftUI called makeNSView again due to
        // re-entry into this view hierarchy, but the PTY is still alive.
        if let cached = tab?.cachedSurface { return cached }
        let surface = GhosttySurfaceView(config: configuration)
        tab?.cachedSurface = surface
        return surface
    }

    func updateNSView(_ nsView: GhosttySurfaceView, context: Context) {}
}
