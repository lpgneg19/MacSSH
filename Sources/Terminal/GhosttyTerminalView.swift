import SwiftUI

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
                // Use `expect` to automate password entry
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
            // Local Shell fall-back
            // Let Ghostty naturally default to the user's interactive login shell
            // But we MUST pass the environment, otherwise the local shell boots with 0 env vars and crashes instantly!
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
        GhosttySurfaceView(config: configuration)
    }

    func updateNSView(_ nsView: GhosttySurfaceView, context: Context) {
        // Handle dynamic settings updates if needed
    }
}
