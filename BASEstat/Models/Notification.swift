//
//  Notification.swift
//  BASEstat
//
//  Created by Marcin Jaroszewicz on 15/03/2025.
//

import Foundation

struct Notification: Identifiable {
    var id = UUID()
    var title: String
    var message: String
    var date: Date
    var type: NotificationType
    var isRead: Bool = false
    var relatedOrderId: String?
    var orderAmount: Double?
    var dailyOrderCount: Int?
    var dailyOrderTotal: Double?
    
    static func sample() -> [Notification] {
        return [
            Notification(
                title: "Nowe zamówienie",
                message: "Otrzymano nowe zamówienie #12345",
                date: Date(),
                type: .newOrder,
                relatedOrderId: "12345"
            ),
            Notification(
                title: "Zmiana statusu",
                message: "Zamówienie #12346 zmieniło status na 'W realizacji'",
                date: Date().addingTimeInterval(-3600),
                type: .statusChange,
                relatedOrderId: "12346"
            ),
            Notification(
                title: "Niski stan magazynowy",
                message: "Produkt 'Koszulka XL' ma niski stan magazynowy (2 szt.)",
                date: Date().addingTimeInterval(-7200),
                type: .lowStock
            )
        ]
    }
}

enum NotificationType {
    case newOrder
    case statusChange
    case lowStock
    case error
    case info
    
    var icon: String {
        switch self {
        case .newOrder: return "cart.badge.plus"
        case .statusChange: return "arrow.triangle.2.circlepath"
        case .lowStock: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .info: return "info.circle"
        }
    }
    
    var color: String {
        switch self {
        case .newOrder: return "green"
        case .statusChange: return "blue"
        case .lowStock: return "orange"
        case .error: return "red"
        case .info: return "gray"
        }
    }
}

// Funkcja testowa do sprawdzenia, czy tworzenie powiadomień działa poprawnie
extension Notification {
    static func createTestNotification() -> Notification {
        print("🔔 Tworzę testowe powiadomienie")
        return Notification(
            title: "Test powiadomienia", 
            message: "To jest testowe powiadomienie z kwotą 100.00 zł",
            date: Date(),
            type: .newOrder,
            orderAmount: 100.00,
            dailyOrderCount: 5,
            dailyOrderTotal: 1500.00
        )
    }
} 