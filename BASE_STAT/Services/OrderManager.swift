import Foundation
import Combine

class OrderManager: ObservableObject {
    private let baseURL = "https://api.baselinker.com/connector.php"
    private var apiToken: String = "" // Token do ustawienia w ustawieniach
    
    @Published var orders: [Order] = []
    @Published var statistics: OrderStatistics?
    @Published var isLoading = false
    @Published var error: Error?
    
    func fetchOrders() {
        isLoading = true
        
        let parameters: [String: Any] = [
            "method": "getOrders",
            "parameters": [
                "date_from": Date().addingTimeInterval(-30*24*60*60), // ostatnie 30 dni
                "date_to": Date(),
                "status_id": 0
            ]
        ]
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiToken, forHTTPHeaderField: "X-BLToken")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            self.error = error
            self.isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error
                    return
                }
                
                guard let data = data else {
                    self?.error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Brak danych"])
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(OrdersResponse.self, from: data)
                    self?.orders = response.orders
                    self?.calculateStatistics()
                } catch {
                    self?.error = error
                }
            }
        }.resume()
    }
    
    private func calculateStatistics() {
        let totalSales = orders.reduce(0.0) { $0 + $1.totalAmount }
        let orderCount = orders.count
        let averageOrderValue = orderCount > 0 ? totalSales / Double(orderCount) : 0
        
        statistics = OrderStatistics(
            totalSales: totalSales,
            orderCount: orderCount,
            averageOrderValue: averageOrderValue
        )
    }
    
    func setApiToken(_ token: String) {
        apiToken = token
        UserDefaults.standard.set(token, forKey: "baselinkerApiToken")
    }
} 