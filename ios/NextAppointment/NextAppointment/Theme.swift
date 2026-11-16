import SwiftUI
import UIKit

/// Colores y medidas de la app, tomados de `css/styles.css`.
/// Los colores cambian solos entre tema claro y oscuro, siguiendo al sistema.
enum Theme {
    static let background = Color(light: 0xF5F6FA, dark: 0x0F1117)
    static let card = Color(light: 0xFFFFFF, dark: 0x1A1D29)
    static let text = Color(light: 0x1E1E2E, dark: 0xF5F6FA)
    static let muted = Color(light: 0x6B7280, dark: 0x9CA3AF)
    static let border = Color(light: 0xE5E7EB, dark: 0x2A2D3A)
    static let brand = Color(hex: Catalog.defaultColor)

    static let cardRadius: CGFloat = 24
    static let smallRadius: CGFloat = 14

    /// Color de acento de un evento para texto e iconos, ajustado para que se lea
    /// sobre la tarjeta: en tema oscuro aclara los colores muy oscuros (como
    /// `#2d3436`) y en tema claro oscurece los muy claros (como `#fdcb6e`).
    static func accent(_ hex: String) -> Color {
        let base = UIColor(hex: hex) ?? UIColor(hex: Catalog.defaultColor)!
        return Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return base.luminance < 0.25 ? base.mixed(with: .white, amount: 0.55) : base
            }
            return base.luminance > 0.6 ? base.mixed(with: .black, amount: 0.35) : base
        })
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// Color a partir de un texto `#rrggbb`. Si no es válido, el color de marca.
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex) ?? UIColor(rgb: 0x6C5CE7))
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }

    convenience init?(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(rgb: value)
    }

    fileprivate var components: (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    fileprivate var luminance: CGFloat {
        let c = components
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }

    fileprivate func mixed(with other: UIColor, amount: CGFloat) -> UIColor {
        let a = components, b = other.components
        return UIColor(
            red: a.r + (b.r - a.r) * amount,
            green: a.g + (b.g - a.g) * amount,
            blue: a.b + (b.b - a.b) * amount,
            alpha: 1
        )
    }
}

extension View {
    /// Fondo de tarjeta: esquinas redondeadas, borde fino y sombra suave.
    func cardBackground(radius: CGFloat = Theme.cardRadius, border: Color = Theme.border, borderWidth: CGFloat = 1) -> some View {
        modifier(CardBackground(radius: radius, border: border, borderWidth: borderWidth))
    }
}

private struct CardBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let radius: CGFloat
    let border: Color
    let borderWidth: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(Theme.card, in: shape)
            .overlay(shape.strokeBorder(border, lineWidth: borderWidth))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.08), radius: 15, x: 0, y: 10)
    }
}
