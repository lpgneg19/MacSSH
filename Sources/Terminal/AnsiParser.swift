import SwiftUI

struct AnsiParser {
    struct State {
        var foreground: Color?
        var background: Color?
        var bold: Bool = false
    }

    static func attributedString(from text: String, fontName: String, fontSize: Double, defaultForeground: Color) -> AttributedString {
        var output = AttributedString()
        var state = State(foreground: defaultForeground, background: nil, bold: false)
        var buffer = ""

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            var chunk = AttributedString(buffer)
            var attrs = AttributeContainer()
            let baseFont = Font.custom(fontName, size: fontSize)
            attrs.font = state.bold ? baseFont.weight(.semibold) : baseFont
            attrs.foregroundColor = state.foreground ?? defaultForeground
            if let bg = state.background {
                attrs.backgroundColor = bg
            }
            chunk.mergeAttributes(attrs)
            output.append(chunk)
            buffer.removeAll(keepingCapacity: true)
        }

        var index = text.startIndex
        while index < text.endIndex {
            if text[index] == "\u{1b}" {
                let next = text.index(after: index)
                if next < text.endIndex, text[next] == "[" {
                    flushBuffer()
                    var seqEnd = text.index(after: next)
                    while seqEnd < text.endIndex, text[seqEnd] != "m" {
                        seqEnd = text.index(after: seqEnd)
                    }
                    if seqEnd < text.endIndex, text[seqEnd] == "m" {
                        let codesString = String(text[text.index(after: next)..<seqEnd])
                        let codes = codesString.split(separator: ";").compactMap { Int($0) }
                        apply(codes: codes, to: &state, defaultForeground: defaultForeground)
                        index = text.index(after: seqEnd)
                        continue
                    }
                }
            }

            buffer.append(text[index])
            index = text.index(after: index)
        }
        flushBuffer()
        return output
    }

    private static func apply(codes: [Int], to state: inout State, defaultForeground: Color) {
        if codes.isEmpty {
            reset(&state, defaultForeground: defaultForeground)
            return
        }
        var i = 0
        while i < codes.count {
            let code = codes[i]
            switch code {
            case 0:
                reset(&state, defaultForeground: defaultForeground)
            case 1:
                state.bold = true
            case 22:
                state.bold = false
            case 39:
                state.foreground = defaultForeground
            case 49:
                state.background = nil
            case 30...37:
                state.foreground = paletteColor(index: code - 30, bright: false)
            case 90...97:
                state.foreground = paletteColor(index: code - 90, bright: true)
            case 40...47:
                state.background = paletteColor(index: code - 40, bright: false)
            case 100...107:
                state.background = paletteColor(index: code - 100, bright: true)
            case 38:
                if i + 2 < codes.count, codes[i+1] == 5 {
                    state.foreground = extendedColor(index: codes[i+2])
                    i += 2
                } else if i + 4 < codes.count, codes[i+1] == 2 {
                    state.foreground = Color(red: Double(codes[i+2])/255.0, green: Double(codes[i+3])/255.0, blue: Double(codes[i+4])/255.0)
                    i += 4
                }
            case 48:
                if i + 2 < codes.count, codes[i+1] == 5 {
                    state.background = extendedColor(index: codes[i+2])
                    i += 2
                } else if i + 4 < codes.count, codes[i+1] == 2 {
                    state.background = Color(red: Double(codes[i+2])/255.0, green: Double(codes[i+3])/255.0, blue: Double(codes[i+4])/255.0)
                    i += 4
                }
            default:
                break
            }
            i += 1
        }
    }

    private static func reset(_ state: inout State, defaultForeground: Color) {
        state = State(foreground: defaultForeground, background: nil, bold: false)
    }

    private static func extendedColor(index: Int) -> Color {
        switch index {
        case 0...7:
            return paletteColor(index: index, bright: false)
        case 8...15:
            return paletteColor(index: index - 8, bright: true)
        case 16...231:
            let i = index - 16
            let b = i % 6
            let g = (i / 6) % 6
            let r = i / 36
            let rVal = r > 0 ? 55 + r * 40 : 0
            let gVal = g > 0 ? 55 + g * 40 : 0
            let bVal = b > 0 ? 55 + b * 40 : 0
            return Color(red: Double(rVal)/255.0, green: Double(gVal)/255.0, blue: Double(bVal)/255.0)
        case 232...255:
            let gray = 8 + (index - 232) * 10
            return Color(red: Double(gray)/255.0, green: Double(gray)/255.0, blue: Double(gray)/255.0)
        default:
            return .clear
        }
    }

    private static func paletteColor(index: Int, bright: Bool) -> Color {
        let base: [Color] = [
            Color(red: 0.0, green: 0.0, blue: 0.0),
            Color(red: 0.78, green: 0.15, blue: 0.16),
            Color(red: 0.0, green: 0.62, blue: 0.28),
            Color(red: 0.77, green: 0.60, blue: 0.0),
            Color(red: 0.25, green: 0.32, blue: 0.71),
            Color(red: 0.55, green: 0.18, blue: 0.60),
            Color(red: 0.0, green: 0.55, blue: 0.55),
            Color(red: 0.78, green: 0.78, blue: 0.78)
        ]
        let brightBase: [Color] = [
            Color(red: 0.45, green: 0.45, blue: 0.45),
            Color(red: 1.0, green: 0.33, blue: 0.33),
            Color(red: 0.33, green: 0.86, blue: 0.40),
            Color(red: 1.0, green: 0.85, blue: 0.33),
            Color(red: 0.45, green: 0.55, blue: 1.0),
            Color(red: 0.89, green: 0.45, blue: 1.0),
            Color(red: 0.33, green: 0.88, blue: 0.88),
            Color(red: 1.0, green: 1.0, blue: 1.0)
        ]
        let palette = bright ? brightBase : base
        let clamped = max(0, min(index, palette.count - 1))
        return palette[clamped]
    }
}
