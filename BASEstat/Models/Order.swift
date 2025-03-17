//
//  Order.swift
//  BASEstat
//
//  Created by Marcin Jaroszewicz on 15/03/2025.
//

import Foundation

struct Order: Identifiable, Codable {
    var id: String
    var orderNumber: String
    var date: Date
    var status: String
    var totalAmount: Double
    var currency: String
    var customerName: String
    var customerEmail: String
    var items: [OrderItem]
    
    enum CodingKeys: String, CodingKey {
        case id = "order_id"
        case orderNumber = "order_number"
        case date = "date_add"
        case status = "order_status_id"
        case totalAmount = "price_total"
        case currency
        case customerName = "delivery_fullname"
        case customerEmail = "email"
        case items = "products"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Elastyczne dekodowanie ID - może być string lub liczba
        if let idString = try? container.decode(String.self, forKey: .id) {
            id = idString
        } else if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = String(idInt)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "ID musi być stringiem lub liczbą")
        }
        
        // Elastyczne dekodowanie numeru zamówienia
        if let orderNumberString = try? container.decode(String.self, forKey: .orderNumber), !orderNumberString.isEmpty {
            orderNumber = orderNumberString
        } else if let orderNumberInt = try? container.decode(Int.self, forKey: .orderNumber) {
            orderNumber = String(orderNumberInt)
        } else {
            // Jeśli brak numeru zamówienia, użyj ID zamówienia jako numeru
            orderNumber = "BL-\(id)"
        }
        
        // Elastyczne dekodowanie statusu
        if let statusString = try? container.decode(String.self, forKey: .status) {
            status = statusString
        } else if let statusInt = try? container.decode(Int.self, forKey: .status) {
            status = String(statusInt)
        } else {
            status = "0" // Domyślny status
        }
        
        // Elastyczne dekodowanie kwoty
        if let amountDouble = try? container.decode(Double.self, forKey: .totalAmount) {
            totalAmount = amountDouble
        } else if let amountString = try? container.decode(String.self, forKey: .totalAmount),
                  let amount = Double(amountString) {
            totalAmount = amount
        } else if let amountInt = try? container.decode(Int.self, forKey: .totalAmount) {
            totalAmount = Double(amountInt)
        } else {
            // Jeśli brak kwoty całkowitej, oblicz ją na podstawie produktów
            totalAmount = 0.0
        }
        
        // Dekodowanie waluty
        currency = (try? container.decode(String.self, forKey: .currency)) ?? "PLN"
        
        // Dekodowanie danych klienta
        customerName = (try? container.decode(String.self, forKey: .customerName)) ?? "Brak danych"
        customerEmail = (try? container.decode(String.self, forKey: .customerEmail)) ?? "Brak danych"
        
        // Obsługa daty - API Baselinker zwraca timestamp jako string lub liczbę
        if let dateString = try? container.decode(String.self, forKey: .date),
           let dateTimestamp = Double(dateString) {
            date = Date(timeIntervalSince1970: dateTimestamp)
        } else if let dateTimestamp = try? container.decode(Double.self, forKey: .date) {
            date = Date(timeIntervalSince1970: dateTimestamp)
        } else if let dateTimestamp = try? container.decode(Int.self, forKey: .date) {
            date = Date(timeIntervalSince1970: TimeInterval(dateTimestamp))
        } else {
            date = Date()
        }
        
        // Dekodowanie produktów
        if let productsArray = try? container.decode([OrderItem].self, forKey: .items) {
            items = productsArray
            
            // Jeśli totalAmount jest 0, oblicz na podstawie produktów
            if totalAmount == 0 {
                totalAmount = items.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
            }
        } else {
            items = []
        }
    }
}

struct OrderItem: Identifiable, Codable {
    var id: String
    var name: String
    var sku: String
    var quantity: Int
    var price: Double
    var imageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "product_id"
        case name = "name"
        case sku = "sku"
        case quantity = "quantity"
        case price = "price_brutto"
        case imageUrl = "image_url"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Elastyczne dekodowanie ID
        if let idString = try? container.decode(String.self, forKey: .id) {
            id = idString
        } else if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = String(idInt)
        } else {
            id = UUID().uuidString // Generujemy ID jeśli brak
        }
        
        // Dekodowanie nazwy i SKU
        name = (try? container.decode(String.self, forKey: .name)) ?? "Brak nazwy"
        sku = (try? container.decode(String.self, forKey: .sku)) ?? ""
        
        // Elastyczne dekodowanie ilości
        if let quantityInt = try? container.decode(Int.self, forKey: .quantity) {
            quantity = quantityInt
        } else if let quantityString = try? container.decode(String.self, forKey: .quantity),
                  let qty = Int(quantityString) {
            quantity = qty
        } else {
            quantity = 1
        }
        
        // Elastyczne dekodowanie ceny
        if let priceDouble = try? container.decode(Double.self, forKey: .price) {
            price = priceDouble
        } else if let priceString = try? container.decode(String.self, forKey: .price),
                  let prc = Double(priceString) {
            price = prc
        } else if let priceInt = try? container.decode(Int.self, forKey: .price) {
            price = Double(priceInt)
        } else {
            price = 0.0
        }
        
        // Dekodowanie URL obrazka
        imageUrl = try? container.decode(String.self, forKey: .imageUrl)
    }
    
    // Inicjalizator dla tworzenia OrderItem z parametrów
    init(id: String, name: String, sku: String, quantity: Int, price: Double, imageUrl: String?) {
        self.id = id
        self.name = name
        self.sku = sku
        self.quantity = quantity
        self.price = price
        self.imageUrl = imageUrl
    }
}

struct OrdersResponse: Codable {
    var status: String
    var orders: [Order]
}

// Inicjalizator dla Order z [String: Any]
extension Order {
    init?(from dict: [String: Any]) {
        // Obsługa ID zamówienia
        if let orderId = dict["order_id"] as? String {
            id = orderId
        } else if let orderIdInt = dict["order_id"] as? Int {
            id = String(orderIdInt)
        } else {
            return nil // Nie można utworzyć zamówienia bez ID
        }
        
        // Obsługa numeru zamówienia
        if let orderNumber = dict["order_number"] as? String, !orderNumber.isEmpty {
            self.orderNumber = orderNumber
        } else if let orderNumberInt = dict["order_number"] as? Int {
            self.orderNumber = String(orderNumberInt)
        } else {
            self.orderNumber = "BL-\(id)"
        }
        
        // Obsługa statusu
        if let status = dict["order_status_id"] as? String {
            self.status = status
        } else if let statusInt = dict["order_status_id"] as? Int {
            self.status = String(statusInt)
        } else {
            self.status = "0"
        }
        
        // Obsługa kwoty
        if let amount = dict["price_total"] as? Double {
            self.totalAmount = amount
        } else if let amountString = dict["price_total"] as? String, let amount = Double(amountString) {
            self.totalAmount = amount
        } else if let amountInt = dict["price_total"] as? Int {
            self.totalAmount = Double(amountInt)
        } else {
            self.totalAmount = 0.0
        }
        
        // Obsługa waluty
        self.currency = dict["currency"] as? String ?? "PLN"
        
        // Obsługa danych klienta
        self.customerName = dict["delivery_fullname"] as? String ?? "Brak danych"
        self.customerEmail = dict["email"] as? String ?? "Brak danych"
        
        // Obsługa daty
        if let dateString = dict["date_add"] as? String, let dateTimestamp = Double(dateString) {
            self.date = Date(timeIntervalSince1970: dateTimestamp)
        } else if let dateTimestamp = dict["date_add"] as? Double {
            self.date = Date(timeIntervalSince1970: dateTimestamp)
        } else if let dateTimestamp = dict["date_add"] as? Int {
            self.date = Date(timeIntervalSince1970: TimeInterval(dateTimestamp))
        } else {
            self.date = Date()
        }
        
        // Obsługa produktów
        if let productsArray = dict["products"] as? [[String: Any]] {
            self.items = productsArray.compactMap { productDict -> OrderItem? in
                var productId: String
                if let idString = productDict["product_id"] as? String {
                    productId = idString
                } else if let idInt = productDict["product_id"] as? Int {
                    productId = String(idInt)
                } else {
                    return nil
                }
                
                let name = productDict["name"] as? String ?? "Brak nazwy"
                let sku = productDict["sku"] as? String ?? ""
                
                let quantity: Int
                if let quantityInt = productDict["quantity"] as? Int {
                    quantity = quantityInt
                } else if let quantityString = productDict["quantity"] as? String, let qty = Int(quantityString) {
                    quantity = qty
                } else {
                    quantity = 1
                }
                
                let price: Double
                if let priceDouble = productDict["price_brutto"] as? Double {
                    price = priceDouble
                } else if let priceString = productDict["price_brutto"] as? String, let prc = Double(priceString) {
                    price = prc
                } else if let priceInt = productDict["price_brutto"] as? Int {
                    price = Double(priceInt)
                } else {
                    price = 0.0
                }
                
                let imageUrl = productDict["image_url"] as? String
                
                return OrderItem(id: productId, name: name, sku: sku, quantity: quantity, price: price, imageUrl: imageUrl)
            }
            
            // Jeśli totalAmount jest 0, oblicz na podstawie produktów
            if self.totalAmount == 0 {
                self.totalAmount = self.items.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
            }
        } else {
            self.items = []
        }
    }
}

enum OrderStatus: String, CaseIterable {
    case new = "1"
    case processing = "2"
    case completed = "3"
    case canceled = "4"
    
    var displayName: String {
        switch self {
        case .new: return "Nowe"
        case .processing: return "W realizacji"
        case .completed: return "Zakończone"
        case .canceled: return "Anulowane"
        }
    }
    
    var color: String {
        switch self {
        case .new: return "blue"
        case .processing: return "orange"
        case .completed: return "green"
        case .canceled: return "red"
        }
    }
} 