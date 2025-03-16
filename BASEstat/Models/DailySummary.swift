import Foundation

// Importujemy modele z innych plików
import SwiftUI

struct DailySummary {
    var date: Date
    var ordersCount: Int
    var totalRevenue: Double
    var averageOrderValue: Double
    var newProductsCount: Int
    var lowStockProductsCount: Int
    
    init(date: Date = Date(), orders: [Order], products: [InventoryProduct]) {
        self.date = date
        
        // Filtrujemy zamówienia z dzisiejszego dnia
        let calendar = Calendar.current
        let todayOrders = orders.filter { calendar.isDateInToday($0.date) }
        
        // Obliczamy statystyki zamówień
        self.ordersCount = todayOrders.count
        self.totalRevenue = todayOrders.reduce(0) { $0 + $1.totalAmount }
        self.averageOrderValue = ordersCount > 0 ? totalRevenue / Double(ordersCount) : 0
        
        // Obliczamy statystyki produktów
        self.newProductsCount = products.filter { 
            if let updateDate = $0.lastUpdateDate {
                return calendar.isDateInToday(updateDate)
            }
            return false
        }.count
        
        self.lowStockProductsCount = products.filter { $0.isLowStock }.count
    }
    
    // Formatowanie wartości pieniężnych
    func formattedRevenue() -> String {
        return String(format: "%.2f zł", totalRevenue)
    }
    
    func formattedAverageValue() -> String {
        return String(format: "%.2f zł", averageOrderValue)
    }
} 