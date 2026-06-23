import SwiftUI

enum Theme {
    // Paleta: negro profundo + dorado + acentos
    static let bgPrimary = Color(red: 0.05, green: 0.05, blue: 0.08)
    static let bgSecondary = Color(red: 0.10, green: 0.10, blue: 0.14)
    static let bgCard = Color(red: 0.13, green: 0.13, blue: 0.18)

    static let gold = Color(red: 0.83, green: 0.69, blue: 0.22)        // #d4af37
    static let goldLight = Color(red: 0.95, green: 0.82, blue: 0.40)
    static let accent = Color(red: 0.85, green: 0.20, blue: 0.55)       // pink/magenta

    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.7)
    static let textTertiary = Color(white: 0.5)

    static let success = Color(red: 0.20, green: 0.78, blue: 0.40)
    static let warning = Color(red: 1.0, green: 0.65, blue: 0.0)
    static let error = Color(red: 0.95, green: 0.30, blue: 0.30)
    static let info = Color(red: 0.30, green: 0.65, blue: 0.95)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
