//
//  Order.swift
//  BASEstat
//
//  Created by Marcin Jaroszewicz on 15/03/2025.
//

import Foundation

struct Order: Identifiable, Codable, Hashable {
    var id: String
    var orderNumber: String
    var date: Date
    var dateConfirmed: Date
    var status: String
    var statusName: String?
    var statusColor: String?
    var totalAmount: Double
    var currency: String
    var customerName: String
    var customerEmail: String
    var items: [OrderItem]
    
    enum CodingKeys: String, CodingKey {
        case id = "order_id"
        case orderNumber = "order_number"
        case date = "date_add"
        case dateConfirmed = "date_confirmed"
        case status = "order_status_id"
        case totalAmount = "price_total"
        case currency
        case customerName = "delivery_fullname"
        case customerEmail = "delivery_email"
        case items = "products"
    }
    
    // Implementacja Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Order, rhs: Order) -> Bool {
        return lhs.id == rhs.id
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
        
        // Obsługa daty potwierdzenia - API Baselinker zwraca timestamp jako string lub liczbę
        if let dateString = try? container.decode(String.self, forKey: .dateConfirmed),
           let dateTimestamp = Double(dateString) {
            dateConfirmed = Date(timeIntervalSince1970: dateTimestamp)
        } else if let dateTimestamp = try? container.decode(Double.self, forKey: .dateConfirmed) {
            dateConfirmed = Date(timeIntervalSince1970: dateTimestamp)
        } else if let dateTimestamp = try? container.decode(Int.self, forKey: .dateConfirmed) {
            dateConfirmed = Date(timeIntervalSince1970: TimeInterval(dateTimestamp))
        } else {
            // Jeśli brak daty potwierdzenia, używamy daty dodania
            dateConfirmed = date
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

struct OrderItem: Identifiable, Codable, Hashable {
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
    
    // Implementacja Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(sku)
    }
    
    static func == (lhs: OrderItem, rhs: OrderItem) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name && lhs.sku == rhs.sku
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
}

struct OrdersResponse: Codable {
    var status: String
    var orders: [Order]
}

// Podstawowe predefiniowane statusy
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

// Nowy model do przechowywania informacji o statusach zamówień z API
struct OrderStatusInfo: Identifiable, Codable {
    var id: String
    var name: String
    var nameForCustomer: String
    var color: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameForCustomer = "name_for_customer"
        case color
    }
}

// Nowy model do przechowywania własnych statusów użytkownika
struct CustomOrderStatus: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var color: String
    
    static func == (lhs: CustomOrderStatus, rhs: CustomOrderStatus) -> Bool {
        return lhs.id == rhs.id
    }
}

// Kolekcja własnych statusów użytkownika
struct CustomOrderStatuses: Codable {
    var statuses: [CustomOrderStatus]
    
    // Pobiera status o podanym ID lub nil, jeśli nie znaleziono
    func getStatus(id: String) -> CustomOrderStatus? {
        return statuses.first { $0.id == id }
    }
    
    // Dodaje nowy status lub aktualizuje istniejący
    mutating func addOrUpdateStatus(id: String, name: String, color: String) {
        if let index = statuses.firstIndex(where: { $0.id == id }) {
            statuses[index].name = name
            statuses[index].color = color
        } else {
            let newStatus = CustomOrderStatus(id: id, name: name, color: color)
            statuses.append(newStatus)
        }
    }
    
    // Usuwa status o podanym ID
    mutating func removeStatus(id: String) {
        statuses.removeAll { $0.id == id }
    }
    
    static var empty: CustomOrderStatuses {
        return CustomOrderStatuses(statuses: [])
    }
}

// Nowa struktura do przechowywania mapowań statusów
struct StatusMapping: Codable, Equatable {
    var baselinkerStatusId: String
    var appStatusId: String
    
    static func == (lhs: StatusMapping, rhs: StatusMapping) -> Bool {
        return lhs.baselinkerStatusId == rhs.baselinkerStatusId && lhs.appStatusId == rhs.appStatusId
    }
}

// Kolekcja mapowań statusów dla użytkownika
struct StatusMappings: Codable {
    var mappings: [StatusMapping]
    
    func getAppStatusId(for baselinkerStatusId: String) -> String? {
        return mappings.first(where: { $0.baselinkerStatusId == baselinkerStatusId })?.appStatusId
    }
    
    mutating func setMapping(baselinkerStatusId: String, appStatusId: String) {
        // Usuń istniejące mapowanie jeśli istnieje
        mappings.removeAll(where: { $0.baselinkerStatusId == baselinkerStatusId })
        // Dodaj nowe
        mappings.append(StatusMapping(baselinkerStatusId: baselinkerStatusId, appStatusId: appStatusId))
    }
    
    static var empty: StatusMappings {
        return StatusMappings(mappings: [])
    }
} 