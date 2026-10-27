import SwiftUI
import UIKit

/// Grayscale only. Hierarchy comes from elevation (shadow) and weight, never hue.
enum Theme {
    static let canvas = Color(light: 0.95, dark: 0.05)
    static let surface = Color(light: 1.00, dark: 0.11)
    static let ink = Color(light: 0.07, dark: 0.95)
    static let muted = Color(light: 0.45, dark: 0.58)
    static let hairline = Color(light: 0.87, dark: 0.20)

    enum Elevation {
        case flat, raised, floating
    }
}

extension Color {
    init(light: Double, dark: Double) {
        self.init(uiColor: UIColor { traits in
            UIColor(white: traits.userInterfaceStyle == .dark ? dark : light, alpha: 1)
        })
    }
}

extension View {
    func elevation(_ level: Theme.Elevation) -> some View {
        let (radius, y, opacity): (CGFloat, CGFloat, Double) = switch level {
        case .flat: (0, 0, 0)
        case .raised: (8, 2, 0.08)
        case .floating: (24, 10, 0.18)
        }
        return shadow(color: .black.opacity(opacity), radius: radius, y: y)
    }
}
