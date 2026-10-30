import AppKit
import SwiftUI

/// Настройки вида панели. Хранятся в UserDefaults и читаются через `@AppStorage`,
/// поэтому панель меняется сразу, пока двигаешь ползунки в настройках.
enum AppearanceKeys {
    static let style = "appearance.style"
    static let color = "appearance.color"
    static let opacity = "appearance.opacity"
    static let theme = "appearance.theme"
    static let width = "appearance.width"
    static let textSize = "appearance.textSize"
    static let accent = "appearance.accent"
    static let showTimer = "appearance.showTimer"
    static let showStep = "appearance.showStep"
    static let showAddStep = "appearance.showAddStep"

    static let all = [style, color, opacity, theme, width, textSize, accent, showTimer, showStep, showAddStep]
}

enum PanelStyle: String, CaseIterable, Identifiable {
    case glass, clearGlass, tintedGlass, solid

    var id: Self { self }

    var title: String {
        switch self {
        case .glass: "Стекло"
        case .clearGlass: "Прозрачное стекло"
        case .tintedGlass: "Цветное стекло"
        case .solid: "Цветной фон"
        }
    }

    var usesColor: Bool { self == .tintedGlass || self == .solid }
}

enum PanelTheme: String, CaseIterable, Identifiable {
    case auto, light, dark

    var id: Self { self }

    var title: String {
        switch self {
        case .auto: "Автоматически"
        case .light: "Светлая"
        case .dark: "Тёмная"
        }
    }
}

enum PanelTextSize: String, CaseIterable, Identifiable {
    case small, regular, large

    var id: Self { self }

    var title: String {
        switch self {
        case .small: "Мелкий"
        case .regular: "Обычный"
        case .large: "Крупный"
        }
    }

    var scale: CGFloat {
        switch self {
        case .small: 0.9
        case .regular: 1
        case .large: 1.2
        }
    }
}

enum PanelDefaults {
    static let width: Double = 340
    static let widthRange: ClosedRange<Double> = 280...460
    static let color = "#5B8DEF"
    static let opacity: Double = 0.85
}

/// Фон карточки по выбранному стилю. В «Автоматической» теме текст светлеет на тёмном цвете.
struct PanelBackground: ViewModifier {
    @AppStorage(AppearanceKeys.style) private var style = PanelStyle.glass
    @AppStorage(AppearanceKeys.color) private var colorHex = PanelDefaults.color
    @AppStorage(AppearanceKeys.opacity) private var opacity = PanelDefaults.opacity
    @AppStorage(AppearanceKeys.theme) private var theme = PanelTheme.auto
    @AppStorage(AppearanceKeys.accent) private var accentHex = ""
    @Environment(\.colorScheme) private var systemScheme

    private let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    func body(content: Content) -> some View {
        let color = Color(hex: colorHex) ?? .blue
        let styled = background(content, color: color)
            .environment(\.colorScheme, scheme(over: color))
        if let accent = Color(hex: accentHex) {
            styled.tint(accent)
        } else {
            styled
        }
    }

    @ViewBuilder
    private func background(_ content: Content, color: Color) -> some View {
        switch style {
        case .glass:
            content.clipShape(shape).glassEffect(.regular, in: shape)
        case .clearGlass:
            content.clipShape(shape).glassEffect(.clear, in: shape)
        case .tintedGlass:
            // Цвет отдельным слоем поверх стекла: оттенок самого стекла macOS гасит
            // в неактивном окне, и цвет был виден только при наведении.
            content
                .background(color.opacity(opacity * 0.6), in: shape)
                .clipShape(shape)
                .glassEffect(.regular, in: shape)
        case .solid:
            content.clipShape(shape).background(color.opacity(opacity), in: shape)
        }
    }

    private func scheme(over color: Color) -> ColorScheme {
        switch theme {
        case .light: return .light
        case .dark: return .dark
        case .auto:
            guard style.usesColor, opacity > 0.35 else { return systemScheme }
            return color.luminance < 0.5 ? .dark : .light
        }
    }
}

extension View {
    func panelBackground() -> some View {
        modifier(PanelBackground())
    }
}

extension Color {
    /// `#RRGGBB`; пустая строка или мусор — `nil`.
    init?(hex: String) {
        let digits = hex.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hex: String {
        let color = NSColor(self).usingColorSpace(.sRGB) ?? .gray
        return String(
            format: "#%02X%02X%02X",
            Int((color.redComponent * 255).rounded()),
            Int((color.greenComponent * 255).rounded()),
            Int((color.blueComponent * 255).rounded())
        )
    }

    /// Относительная яркость 0…1.
    var luminance: Double {
        let color = NSColor(self).usingColorSpace(.sRGB) ?? .gray
        return 0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent
    }
}
