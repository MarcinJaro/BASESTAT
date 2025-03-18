import SwiftUI
import Foundation

extension Color {
    public init?(hex: String) {
        // Obsługa standardowych nazw kolorów
        switch hex.lowercased() {
        case "blue":
            self = .blue
            return
        case "red":
            self = .red
            return
        case "green":
            self = .green
            return
        case "orange":
            self = .orange
            return
        case "yellow":
            self = .yellow
            return
        case "purple":
            self = .purple
            return
        case "gray", "grey":
            self = .gray
            return
        default:
            break
        }
        
        // Obsługa wartości hex
        var hexSanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hexSanitized.hasPrefix("#") {
            hexSanitized = String(hexSanitized.dropFirst())
        }
        
        var int: UInt64 = 0
        if !Scanner(string: hexSanitized).scanHexInt64(&int) {
            // Nie udało się sparsować hex, zwróć nil
            return nil
        }
        
        let a, r, g, b: UInt64
        switch hexSanitized.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 