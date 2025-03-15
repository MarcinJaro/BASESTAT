import Foundation

struct Order: Identifiable, Codable {
    let id: Int
    let orderNumber: String
    let date: Date
    let status: String
    let totalAmount: Double
    let currency: String
    let customerName: String
    
    enum CodingKeys: String, CodingKey {
        case id = "order_id"
        case orderNumber = "order_number"
        case date = "date_add"
        case status = "order_status_id"
        case totalAmount = "price"
        case currency
        case customerName = "delivery_fullname"
    }
}

struct OrdersResponse: Codable {
    let status: String
    let orders: [Order]
} 