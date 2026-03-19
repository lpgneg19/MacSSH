import SwiftUI

struct VTTerminalView: View {
    @Bindable var model: TerminalSessionViewModel
    @Bindable var settings: AppSettings
    @State private var isFocused: Bool = false

    var body: some View {
        ZStack {
            if settings.vibrancyEnabled {
                VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                    .ignoresSafeArea()
            } else {
                settings.backgroundColor
                    .ignoresSafeArea()
            }

            if settings.showGrid {
                TerminalGridView()
                    .opacity(0.05)
            }

            ScrollView {
                let attributed = AnsiParser.attributedString(
                    from: model.displayText,
                    fontName: settings.fontName,
                    fontSize: settings.fontSize,
                    defaultForeground: settings.textColor
                )
                Text(attributed)
                    .textSelection(.enabled)
                    .shadow(color: settings.terminalGlow ? settings.textColor.opacity(0.5) : .clear, radius: settings.terminalGlow ? 3 : 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }

            TerminalKeyCaptureView { data in
                model.sendBytes(data)
            }
            onFocusChanged: { focused in
                isFocused = focused
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .allowsHitTesting(true)
            .background(Color.clear)

            if !isFocused {
                VStack(spacing: 8) {
                    Text("Click here to type")
                        .font(.callout.weight(.semibold))
                    Text("The terminal captures your keyboard input once focused.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

private struct TerminalGridView: View {
    var body: some View {
        GeometryReader { _ in
            Path { path in
                let step: CGFloat = 20
                for x in stride(from: 0, through: 2000, by: step) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: 2000))
                }
                for y in stride(from: 0, through: 2000, by: step) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: 2000, y: y))
                }
            }
            .stroke(Color.primary, lineWidth: 0.5)
        }
    }
}
