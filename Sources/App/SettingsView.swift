import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    
    private enum Tab: String, CaseIterable, Identifiable {
        case general, appearance, terminal, sftp, about
        var id: String { rawValue }
        
        var label: String {
            switch self {
            case .general: return String(localized: "General")
            case .appearance: return String(localized: "Appearance")
            case .terminal: return String(localized: "Terminal")
            case .sftp: return String(localized: "SFTP")
            case .about: return String(localized: "About")
            }
        }
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .appearance: return "paintpalette"
            case .terminal: return "terminal"
            case .sftp: return "folder.badge.plus"
            case .about: return "info.circle"
            }
        }
    }
    
    @SceneStorage("settingsSelectedTab") private var selectedTab: Tab = .appearance

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem {
                    Label(Tab.general.label, systemImage: Tab.general.icon)
                }
                .tag(Tab.general)
            
            appearanceTab
                .tabItem {
                    Label(Tab.appearance.label, systemImage: Tab.appearance.icon)
                }
                .tag(Tab.appearance)
            
            terminalTab
                .tabItem {
                    Label(Tab.terminal.label, systemImage: Tab.terminal.icon)
                }
                .tag(Tab.terminal)
            
            sftpTab
                .tabItem {
                    Label(Tab.sftp.label, systemImage: Tab.sftp.icon)
                }
                .tag(Tab.sftp)
            
            aboutTab
                .tabItem {
                    Label(Tab.about.label, systemImage: Tab.about.icon)
                }
                .tag(Tab.about)
        }
        .frame(width: 500, height: 400)
    }
    
    private var generalTab: some View {
        Form {
            Section {
                Text(String(localized: "Application behavior and general preferences."))
                    .foregroundStyle(.secondary)
            } header: {
                Text(String(localized: "App Behavior"))
            }
            
            Section {
                // Placeholder for future general settings
                Toggle(String(localized: "Confirm before disconnecting"), isOn: .constant(true))
                Toggle(String(localized: "Automatically reconnect on failure"), isOn: .constant(false))
            }
        }
        .formStyle(.grouped)
    }
    
    private var terminalTab: some View {
        Form {
            Section {
                Picker(String(localized: "Theme"), selection: $settings.theme) {
                    ForEach(AppSettings.TerminalTheme.allCases) { theme in
                        Text(theme.rawValue.capitalized).tag(theme)
                    }
                }
            } header: {
                Text(String(localized: "Engine"))
            }

            Section {
                Picker(String(localized: "Font Family"), selection: $settings.fontName) {
                    ForEach(settings.availableFonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }
                
                HStack {
                    Text(String(localized: "Font Size"))
                    Slider(value: $settings.fontSize, in: 9...24, step: 1)
                    Text("\(Int(settings.fontSize))")
                        .monospacedDigit()
                        .frame(width: 30)
                }
            } header: {
                Text(String(localized: "Typography"))
            }
        }
        .formStyle(.grouped)
    }

    private var appearanceTab: some View {
        Form {
            Section {
                Toggle(String(localized: "Enable Vibrancy (Glass Effect)"), isOn: $settings.vibrancyEnabled)
                Toggle(String(localized: "Show Subtle Grid"), isOn: $settings.showGrid)
                Toggle(String(localized: "Enable Terminal Text Glow"), isOn: $settings.terminalGlow)
            } header: {
                Text(String(localized: "Premium Effects"))
            } footer: {
                Text(String(localized: "Enable these effects for a more modern, state-of-the-art macOS experience."))
            }

            Section {
                Picker(String(localized: "Default Renderer"), selection: $settings.renderer) {
                    ForEach(AppSettings.RendererMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
            } header: {
                Text(String(localized: "Rendering"))
            }
        }
        .formStyle(.grouped)
    }
    
    private var sftpTab: some View {
        Form {
            Section {
                Text(String(localized: "Configure SFTP file transfer preferences."))
                    .foregroundStyle(.secondary)
            } header: {
                Text(String(localized: "Transfers"))
            }
            
            Section {
                Toggle(String(localized: "Show hidden files"), isOn: .constant(false))
                Toggle(String(localized: "Overwrite existing files"), isOn: .constant(true))
            }
        }
        .formStyle(.grouped)
    }
    
    private var aboutTab: some View {
        VStack(spacing: 20) {
            Image(systemName: "desktopcomputer")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .foregroundStyle(Color.accentColor)
            
            VStack(spacing: 4) {
                Text("MacSSH")
                    .font(.title).bold()
                Text("Version 0.1.0 (1)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text(String(localized: "A modern SSH client for macOS."))
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Divider()
                .padding(.horizontal, 40)
            
            Text("© 2026 Steve")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
