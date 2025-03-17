//
//  DailySummary.swift
//  BASEstat
//
//  Created by Marcin Jaroszewicz on 17/03/2025.
//

import Foundation

// Importujemy modele z innych plików
import SwiftUI

struct DailySummary {
    var orderCount: Int
    var totalValue: Double
    var newOrdersCount: Int
    var topProducts: [(name: String, quantity: Int, id: String, imageUrl: String?)]
    
    init(orders: [Order], products: [InventoryProduct]) {
        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .hour, value: -24, to: now)!
        
        // Filtrujemy zamówienia z ostatnich 24 godzin
        let todayOrders = orders.filter { order in
            return order.date >= yesterday && order.date <= now
        }
        
        // Liczba zamówień z ostatnich 24 godzin
        self.orderCount = todayOrders.count
        
        // Całkowita wartość zamówień z ostatnich 24 godzin
        self.totalValue = todayOrders.reduce(0) { $0 + $1.totalAmount }
        
        // Liczba nowych zamówień z ostatnich 24 godzin
        self.newOrdersCount = todayOrders.filter { $0.status == OrderStatus.new.rawValue }.count
        
        // Najlepiej sprzedające się produkty z ostatnich 24 godzin
        var productQuantities: [String: (quantity: Int, id: String, sku: String, imageUrl: String?)] = [:]
        
        for order in todayOrders {
            for item in order.items {
                let productId = item.id
                let productName = item.name
                let productSku = item.sku
                let imageUrl = item.imageUrl
                
                if let existingProduct = productQuantities[productName] {
                    // Aktualizujemy ilość dla istniejącego produktu
                    let updatedImageUrl = imageUrl?.hasPrefix("http") == true ? imageUrl : existingProduct.imageUrl
                    productQuantities[productName] = (quantity: existingProduct.quantity + item.quantity, id: existingProduct.id, sku: existingProduct.sku, imageUrl: updatedImageUrl)
                } else {
                    // Dodajemy nowy produkt
                    productQuantities[productName] = (quantity: item.quantity, id: productId, sku: productSku, imageUrl: imageUrl)
                }
            }
        }
        
        // Próbujemy znaleźć odpowiadające produkty w magazynie, aby użyć ich obrazków
        for (productName, productData) in productQuantities {
            // Szukamy produktu w magazynie po SKU
            if let inventoryProduct = products.first(where: { $0.sku == productData.sku && $0.sku.isEmpty == false }) {
                // Jeśli znaleziono produkt w magazynie i ma URL obrazka, używamy go
                if let inventoryImageUrl = inventoryProduct.imageUrl, !inventoryImageUrl.isEmpty {
                    productQuantities[productName] = (quantity: productData.quantity, id: productData.id, sku: productData.sku, imageUrl: inventoryImageUrl)
                }
            }
            // Jeśli nie znaleziono po SKU, próbujemy po ID
            else if let inventoryProduct = products.first(where: { $0.id == productData.id }) {
                // Jeśli znaleziono produkt w magazynie i ma URL obrazka, używamy go
                if let inventoryImageUrl = inventoryProduct.imageUrl, !inventoryImageUrl.isEmpty {
                    productQuantities[productName] = (quantity: productData.quantity, id: productData.id, sku: productData.sku, imageUrl: inventoryImageUrl)
                }
            }
        }
        
        self.topProducts = productQuantities.sorted { $0.value.quantity > $1.value.quantity }
            .prefix(5)
            .map { (name: $0.key, quantity: $0.value.quantity, id: $0.value.id, imageUrl: $0.value.imageUrl) }
        
        // Jeśli nie ma żadnych zamówień z ostatnich 24 godzin, generujemy dane testowe
        if todayOrders.isEmpty && orders.isEmpty {
            self.orderCount = 15
            self.totalValue = 2345.67
            self.newOrdersCount = 2
            
            // Używamy rzeczywistych adresów URL obrazków z internetu
            self.topProducts = [
                ("Smartfon XYZ", 12, "prod1", "https://cdn.pixabay.com/photo/2016/11/29/12/30/phone-1869510_1280.jpg"),
                ("Słuchawki bezprzewodowe", 8, "prod2", "https://cdn.pixabay.com/photo/2018/09/17/14/27/headphones-3683983_1280.jpg"),
                ("Powerbank 10000mAh", 6, "prod3", "https://cdn.pixabay.com/photo/2014/08/05/10/30/iphone-410324_1280.jpg"),
                ("Etui ochronne", 5, "prod4", "https://cdn.pixabay.com/photo/2015/02/02/15/28/office-620822_1280.jpg"),
                ("Ładowarka USB-C", 4, "prod5", "https://cdn.pixabay.com/photo/2014/04/05/11/38/cable-316288_1280.jpg")
            ]
        }
    }
    
    // Formatowanie wartości pieniężnych
    func formattedRevenue() -> String {
        return String(format: "%.2f zł", totalValue)
    }
    
    func formattedAverageValue() -> String {
        return String(format: "%.2f zł", totalValue / Double(orderCount))
    }
} 