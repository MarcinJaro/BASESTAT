import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AppTheme {
    // Główne kolory aplikacji
    struct Colors {
        // Kolory podstawowe
        static let primary = Color(hex: "4A80F0") // Niebieski
        static let secondary = Color(hex: "F45E6D") // Różowy
        static let accent = Color(hex: "32D4A4") // Miętowy
        
        // Kolory gradientów
        static let gradientStart = Color(hex: "4A80F0") // Niebieski
        static let gradientEnd = Color(hex: "32D4A4") // Miętowy
        
        // Kolory tła
        #if canImport(UIKit)
        static let background = Color(UIColor.systemBackground)
        #else
        static let background = Color.white
        #endif
        
        // Kolory tekstu
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textLight = Color.white
        
        // Kolory statusów
        static let success = Color(hex: "32D4A4") // Miętowy
        static let warning = Color(hex: "FFCF5C") // Żółty
        static let error = Color(hex: "F45E6D") // Różowy
        
        // Kolory wykresów
        static let chart1 = Color(hex: "4A80F0") // Niebieski
        static let chart2 = Color(hex: "F45E6D") // Różowy
        static let chart3 = Color(hex: "32D4A4") // Miętowy
        static let chart4 = Color(hex: "FFCF5C") // Żółty
        
        // Kolory kart
        static let cardBackground = Color.white
        static let cardShadow = Color.black.opacity(0.05)
    }
    
    // Wymiary i rozmiary
    struct Dimensions {
        // Padding
        static let paddingSmall: CGFloat = 8
        static let paddingMedium: CGFloat = 16
        static let paddingLarge: CGFloat = 24
        
        // Corner radius
        static let cornerRadiusSmall: CGFloat = 8
        static let cornerRadiusMedium: CGFloat = 12
        static let cornerRadiusLarge: CGFloat = 16
        
        // Icon sizes
        static let iconSmall: CGFloat = 16
        static let iconMedium: CGFloat = 24
        static let iconLarge: CGFloat = 32
        
        // Button heights
        static let buttonSmall: CGFloat = 32
        static let buttonMedium: CGFloat = 44
        static let buttonLarge: CGFloat = 56
        
        // Card padding
        static let cardPadding: CGFloat = 16
        
        // Corner radius
        static let cornerRadius: CGFloat = 16
    }
    
    // Style tekstu
    struct TextStyles {
        // Heading styles
        static let h1 = Font.system(size: 28, weight: .bold)
        static let h2 = Font.system(size: 24, weight: .bold)
        static let h3 = Font.system(size: 20, weight: .semibold)
        static let h4 = Font.system(size: 18, weight: .semibold)
        
        // Body styles
        static let bodyLarge = Font.system(size: 16)
        static let bodyMedium = Font.system(size: 14)
        static let bodySmall = Font.system(size: 12)
        
        // Button styles
        static let buttonLarge = Font.system(size: 16, weight: .semibold)
        static let buttonMedium = Font.system(size: 14, weight: .semibold)
        static let buttonSmall = Font.system(size: 12, weight: .semibold)
        
        // Special styles
        static let subtitle = Font.system(size: 16, weight: .semibold)
        static let caption = Font.system(size: 12, weight: .medium)
    }
    
    // Cienie
    struct Shadows {
        static let small = Shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        static let medium = Shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        static let large = Shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
    }
    
    // Animacje
    struct Animations {
        static let defaultAnimation = Animation.easeInOut(duration: 0.3)
        static let quickAnimation = Animation.easeInOut(duration: 0.15)
        static let slowAnimation = Animation.easeInOut(duration: 0.5)
    }
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
} 