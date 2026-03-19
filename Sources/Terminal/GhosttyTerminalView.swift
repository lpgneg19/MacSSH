import SwiftUI

struct GhosttyTerminalView: NSViewRepresentable {
    let settings: AppSettings
    
    var configuration: GhosttySurfaceConfiguration {
        var config = GhosttySurfaceConfiguration()
        config.fontSize = Float(settings.fontSize)
        
        if settings.renderer == .ghosttySurface {
            config.workingDirectory = NSHomeDirectory()
            config.command = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        }
        
        return config
    }

    func makeNSView(context: Context) -> GhosttySurfaceView {
        GhosttySurfaceView(config: configuration)
    }

    func updateNSView(_ nsView: GhosttySurfaceView, context: Context) {
        // Handle dynamic settings updates if needed
    }
}
