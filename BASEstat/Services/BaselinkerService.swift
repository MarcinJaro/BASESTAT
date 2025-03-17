//
//  BaselinkerService.swift
//  BASEstat
//
//  Created by Marcin Jaroszewicz on 15/03/2025.
//

import Foundation
import Combine
import SwiftUI

// Rozszerzenie dla Dictionary, aby konwertować do JSON string
extension Dictionary {
    var jsonString: String {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: self, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }
}

// Model produktu z magazynu
struct InventoryProduct: Identifiable {
    var id: String
    var name: String
    var sku: String
    var ean: String?
    var price: Double
    var quantity: Int
    var imageUrl: String?
    var description: String?
    var category: String?
    var attributes: [String: String]
    var lastUpdateDate: Date?
    var isLowStock: Bool {
        return quantity <= 5 // Definiujemy niski stan magazynowy jako 5 lub mniej sztuk
    }
    
    init(from json: [String: Any]) {
        // Obsługa product_id jako liczby lub stringa
        if let idString = json["id"] as? String {
            self.id = idString
        } else if let idNumber = json["id"] as? Int {
            self.id = String(idNumber)
        } else if let idNumber = json["id"] as? Double {
            self.id = String(Int(idNumber))
        } else {
            self.id = ""
        }
        
        // Pobieranie nazwy z pola text_fields.name
        if let textFields = json["text_fields"] as? [String: Any], let name = textFields["name"] as? String {
            self.name = name
        } else {
            self.name = "Brak nazwy"
        }
        
        // Pobieranie SKU
        self.sku = (json["sku"] as? String) ?? ""
        
        // Pobieranie EAN
        self.ean = json["ean"] as? String
        
        // Parsowanie ceny - sprawdzamy w polu prices
        if let prices = json["prices"] as? [String: Any], let priceValue = prices["4180"] as? Double {
            self.price = priceValue
        } else if let prices = json["prices"] as? [String: Any], let priceValue = prices["4180"] as? String, let priceDouble = Double(priceValue) {
            self.price = priceDouble
        } else {
            self.price = 0.0
        }
        
        // Parsowanie ilości - sprawdzamy w polu stock
        if let stock = json["stock"] as? [String: Any], let quantity = stock["bl_5247"] as? Int {
            self.quantity = quantity
        } else if let stock = json["stock"] as? [String: Any], let quantity = stock["bl_5247"] as? String, let quantityInt = Int(quantity) {
            self.quantity = quantityInt
        } else {
            self.quantity = 0
        }
        
        // Bezpieczne pobieranie URL obrazka z pola images
        if let images = json["images"] as? [String: Any], let firstImage = images["1"] as? String {
            self.imageUrl = firstImage
        } else {
            self.imageUrl = nil
        }
        
        // Pobieranie opisu z pola text_fields.description_extra1
        if let textFields = json["text_fields"] as? [String: Any], let description = textFields["description_extra1"] as? String {
            self.description = description
        } else {
            self.description = nil
        }
        
        // Pobieranie kategorii
        self.category = json["category_id"] as? String
        
        // Parsowanie daty ostatniej aktualizacji
        if let dateUpdated = json["date_updated"] as? Int {
            self.lastUpdateDate = Date(timeIntervalSince1970: TimeInterval(dateUpdated))
        } else if let dateUpdated = json["date_updated"] as? String, let timestamp = Int(dateUpdated) {
            self.lastUpdateDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
        } else {
            self.lastUpdateDate = nil
        }
        
        // Parsowanie atrybutów z pola text_fields.features
        var attrs: [String: String] = [:]
        if let textFields = json["text_fields"] as? [String: Any], let features = textFields["features"] as? [String: Any] {
            for (key, value) in features {
                if let stringValue = value as? String {
                    attrs[key] = stringValue
                } else {
                    // Bezpieczna konwersja dowolnej wartości na String
                    attrs[key] = String(describing: value)
                }
            }
        }
        self.attributes = attrs
    }
}

// Model katalogu (magazynu)
struct Inventory: Identifiable {
    var id: String
    var name: String
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

class BaselinkerService: ObservableObject {
    private let baseURL = "https://api.baselinker.com/connector.php"
    private var apiToken: String = ""
    
    @Published var orders: [Order] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var connectionStatus: ConnectionStatus = .notConnected
    @Published var lastResponseDebug: String? = nil
    @Published var orderStatuses: [OrderStatusInfo] = []
    @Published var loadingOrdersProgress: String = ""
    
    // Nowe zmienne do obsługi produktów
    @Published var inventories: [Inventory] = []
    @Published var inventoryProducts: [InventoryProduct] = []
    @Published var isLoadingProducts: Bool = false
    @Published var selectedInventoryId: String? = nil
    @Published var loadingProgress: Double = 0.0
    @Published var dailySummary: DailySummary?
    
    private var cancellables = Set<AnyCancellable>()
    private var summaryTimer: Timer?
    private var deltaUpdateTimer: Timer?
    
    enum ConnectionStatus: Equatable {
        case notConnected
        case connecting
        case connected
        case failed(String)
        
        var description: String {
            switch self {
            case .notConnected:
                return "Nie połączono"
            case .connecting:
                return "Łączenie..."
            case .connected:
                return "Połączono"
            case .failed(let message):
                return "Błąd: \(message)"
            }
        }
        
        var isConnected: Bool {
            if case .connected = self {
                return true
            }
            return false
        }
        
        static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
            switch (lhs, rhs) {
            case (.notConnected, .notConnected):
                return true
            case (.connecting, .connecting):
                return true
            case (.connected, .connected):
                return true
            case (.failed(let lhsMessage), .failed(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    init(apiToken: String = "") {
        self.apiToken = apiToken
        // Wczytaj token z bezpiecznego miejsca, np. Keychain
        loadApiToken()
    }
    
    private func loadApiToken() {
        // Sprawdź, czy token jest zapisany w UserDefaults
        if let savedToken = UserDefaults.standard.string(forKey: "baselinkerApiToken"), !savedToken.isEmpty {
            self.apiToken = savedToken
            
            // Jeśli token jest już ustawiony, sprawdź połączenie
            testConnection { [weak self] success, message in
                guard let self = self else { return }
                // Aktualizujemy status połączenia na podstawie wyniku
                DispatchQueue.main.async {
                    if success {
                        self.connectionStatus = .connected
                    } else {
                        self.connectionStatus = .failed(message)
                    }
                }
            }
        } else {
            // Brak zapisanego tokenu
            DispatchQueue.main.async {
                self.apiToken = ""
                self.connectionStatus = .notConnected
            }
        }
    }
    
    func saveApiToken(_ token: String) {
        // Zapisz token w UserDefaults
        UserDefaults.standard.set(token, forKey: "baselinkerApiToken")
        self.apiToken = token
        
        // Po zapisaniu tokenu, przetestuj połączenie
        testConnection { [weak self] success, message in
            guard let self = self else { return }
            // Aktualizujemy status połączenia na podstawie wyniku
            DispatchQueue.main.async {
                if success {
                    self.connectionStatus = .connected
                    // Po udanym połączeniu, pobierz zamówienia
                    self.fetchOrders()
                    // Pobierz również listę magazynów
                    self.fetchInventories()
                } else {
                    self.connectionStatus = .failed(message)
                }
            }
        }
    }
    
    // Funkcja pomocnicza do debugowania
    private func logRequest(_ request: URLRequest, _ body: String) {
        print("🌐 API Request: \(request.url?.absoluteString ?? "")")
        print("🔑 Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("📦 Body: \(body)")
    }
    
    private func logResponse(_ data: Data) {
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📥 API Response: \(jsonString)")
            DispatchQueue.main.async {
                self.lastResponseDebug = jsonString
            }
        }
    }
    
    func testConnection() {
        // Ustawiamy status na "łączenie"
        DispatchQueue.main.async {
            self.connectionStatus = .connecting
        }
        
        // Wywołujemy pełną wersję funkcji testConnection z callbackiem
        testConnection { [weak self] success, message in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if success {
                    self.connectionStatus = .connected
                    // Po udanym połączeniu, pobierz zamówienia
                    self.fetchOrders()
                    // Pobierz również listę magazynów
                    self.fetchInventories()
                    // Pobierz listę statusów zamówień
                    self.fetchOrderStatusList()
                } else {
                    self.connectionStatus = .failed(message)
                }
            }
        }
    }
    
    func testConnection(completion: @escaping (Bool, String) -> Void) {
        let parameters: [String: Any] = [
            "method": "getOrders",
            "parameters": [
                "order_id": "",
                "date_confirmed_from": 0, 
                "date_from": 0,
                "status_id": "0",
                "filter_email": "",
                "include_custom_extrafields": "false",
                "include_product_images": "true" // Próbujemy wymusić zwracanie obrazków
            ]
        ]
        
        sendRequest(parameters: parameters) { [weak self] success, responseData in
            guard let self = self else { return }
            
            if success, let responseData = responseData {
                do {
                    if let jsonObject = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] {
                        if let status = jsonObject["status"] as? String, status == "SUCCESS" {
                            // Sprawdzamy, czy mamy zamówienia do debugowania
                            if let orders = jsonObject["orders"] as? [[String: Any]], let firstOrder = orders.first {
                                print("✅ Połączenie z API Baselinker działa poprawnie!")
                                print("Liczba zamówień: \(orders.count)")
                                
                                // Wywołujemy naszą funkcję debugowania
                                self.debugFirstOrder(firstOrder)
                                
                                completion(true, "Połączono z API. Znaleziono \(orders.count) zamówień.")
                            } else {
                                print("✅ Połączenie z API Baselinker działa, ale nie znaleziono żadnych zamówień.")
                                completion(true, "Połączono z API. Nie znaleziono zamówień.")
                            }
                        } else {
                            let errorMessage = (jsonObject["error_message"] as? String) ?? "Nieznany błąd"
                            print("❌ Błąd API: \(errorMessage)")
                            completion(false, "Błąd API: \(errorMessage)")
                        }
                    } else {
                        print("❌ Niepoprawna odpowiedź API")
                        completion(false, "Niepoprawna odpowiedź API")
                    }
                } catch {
                    print("❌ Błąd podczas przetwarzania odpowiedzi: \(error.localizedDescription)")
                    completion(false, "Błąd podczas przetwarzania odpowiedzi: \(error.localizedDescription)")
                }
            } else {
                print("❌ Błąd połączenia z API")
                completion(false, "Błąd połączenia z API")
            }
        }
    }
    
    func fetchOrders(dateFrom: Date? = nil, dateTo: Date? = nil, statusId: String? = nil) {
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
            self.loadingOrdersProgress = "Pobieranie zamówień..."
            
            // Nie resetujemy listy zamówień, aby nie znikały podczas odświeżania
            // Zamówienia zostaną zaktualizowane po otrzymaniu odpowiedzi
        }
        
        // Pobieramy pierwszą partię zamówień
        fetchOrdersBatch(dateFrom: dateFrom, dateTo: dateTo, statusId: statusId, lastConfirmedDate: nil)
    }
    
    private func fetchOrdersBatch(dateFrom: Date? = nil, dateTo: Date? = nil, statusId: String? = nil, lastConfirmedDate: Date? = nil, isDeltaUpdate: Bool = false) {
        // Tworzymy zagnieżdżony słownik parametrów
        var orderParameters: [String: Any] = [
            "get_unconfirmed_orders": false // Pobieramy tylko potwierdzone zamówienia
        ]
        
        // Dodajemy opcjonalne parametry, jeśli zostały podane
        if let lastConfirmedDate = lastConfirmedDate {
            // Używamy lastConfirmedDate + 1 sekunda jako date_confirmed_from, aby uniknąć duplikatów
            let nextSecond = lastConfirmedDate.addingTimeInterval(1)
            orderParameters["date_confirmed_from"] = Int(nextSecond.timeIntervalSince1970)
            if isDeltaUpdate {
                print("🔄 Delta update: Pobieranie zamówień od daty: \(nextSecond)")
            } else {
                print("🔄 Pobieranie zamówień od daty: \(nextSecond)")
            }
        } else if let dateFrom = dateFrom {
            // Jeśli nie mamy lastConfirmedDate, ale mamy dateFrom, używamy dateFrom
            orderParameters["date_confirmed_from"] = Int(dateFrom.timeIntervalSince1970)
        }
        
        if let dateTo = dateTo {
            orderParameters["date_confirmed_to"] = Int(dateTo.timeIntervalSince1970)
        }
        
        if let statusId = statusId {
            orderParameters["status_id"] = statusId
        }
        
        // Dodajemy parametr, aby upewnić się, że API zwraca obrazki produktów
        orderParameters["include_product_images"] = true
        
        // Logowanie parametrów żądania
        print("📤 Parametry żądania getOrders: \(orderParameters)")
        
        // Konwertujemy parametry do formatu JSON
        guard let parametersData = try? JSONSerialization.data(withJSONObject: orderParameters),
              let parametersString = String(data: parametersData, encoding: .utf8) else {
            DispatchQueue.main.async {
                self.error = "Błąd serializacji parametrów"
                self.isLoading = false
            }
            return
        }
        
        guard let url = URL(string: baseURL) else {
            DispatchQueue.main.async {
                self.error = "Nieprawidłowy URL"
                self.isLoading = false
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue(apiToken, forHTTPHeaderField: "X-BLToken")
        
        // Przygotowujemy dane w formacie application/x-www-form-urlencoded
        let requestBody = "method=getOrders&parameters=\(parametersString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = requestBody.data(using: .utf8)
        
        // Logujemy żądanie do debugowania
        logRequest(request, requestBody)
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .tryMap { [weak self] data -> [Order] in
                guard let self = self else { throw NSError(domain: "Brak referencji do self", code: -1) }
                
                // Logujemy odpowiedź do debugowania
                self.logResponse(data)
                
                guard let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    print("❌ Nieprawidłowa odpowiedź JSON")
                    throw NSError(domain: "Nieprawidłowa odpowiedź JSON", code: -1)
                }
                
                guard let status = jsonObject["status"] as? String, status == "SUCCESS" else {
                    let errorMessage = (jsonObject["error_message"] as? String) ?? "Nieznany błąd"
                    print("❌ Błąd API: \(errorMessage)")
                    throw NSError(domain: errorMessage, code: -1)
                }
                
                guard let ordersData = jsonObject["orders"] as? [[String: Any]] else {
                    print("❌ Brak danych o zamówieniach")
                    throw NSError(domain: "Brak danych o zamówieniach", code: -1)
                }
                
                print("✅ Pobrano \(ordersData.count) zamówień z API")
                
                let ordersJsonData = try JSONSerialization.data(withJSONObject: ordersData, options: [])
                
                do {
                    // Tworzymy dekoder z niestandardową strategią dekodowania dat
                    let decoder = JSONDecoder()
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let dateString = try container.decode(String.self)
                        
                        // Próbujemy najpierw z formatem yyyy-MM-dd HH:mm:ss
                        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        if let date = dateFormatter.date(from: dateString) {
                            return date
                        }
                        
                        // Jeśli nie zadziała, próbujemy z formatem timestamp
                        if let timestamp = Double(dateString) {
                            return Date(timeIntervalSince1970: timestamp)
                        }
                        
                        // Jeśli nic nie zadziała, zwracamy aktualną datę
                        print("⚠️ Nie udało się zdekodować daty: \(dateString)")
                        return Date()
                    }
                    
                    var newOrders = try decoder.decode([Order].self, from: ordersJsonData)
                    
                    // Uzupełniamy informacje o statusie dla każdego zamówienia
                    for i in 0..<newOrders.count {
                        if let statusInfo = self.getOrderStatusInfo(for: newOrders[i].status) {
                            newOrders[i].statusName = statusInfo.name
                            newOrders[i].statusColor = statusInfo.color
                        }
                    }
                    
                    print("✅ Pomyślnie zdekodowano \(newOrders.count) zamówień")
                    return newOrders
                } catch {
                    print("❌ Błąd dekodowania zamówień: \(error.localizedDescription)")
                    throw error
                }
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.isLoading = false
                    self?.error = "Błąd pobierania danych: \(error.localizedDescription)"
                    self?.connectionStatus = .failed(error.localizedDescription)
                }
            }, receiveValue: { [weak self] orders in
                guard let self = self else { return }
                
                // Aktualizujemy listę zamówień (jesteśmy już na głównym wątku dzięki receive(on: DispatchQueue.main))
                if lastConfirmedDate == nil {
                    // Jeśli to pierwsza partia, zastępujemy istniejącą listę
                    self.orders = orders
                } else {
                    // Jeśli to kolejna partia, dodajemy do istniejącej listy, ale usuwamy duplikaty
                    // Tworzymy zbiór istniejących ID zamówień
                    let existingIds = Set(self.orders.map { $0.id })
                    
                    // Filtrujemy nowe zamówienia, aby dodać tylko te, których jeszcze nie mamy
                    let newOrders = orders.filter { !existingIds.contains($0.id) }
                    
                    // Dodajemy tylko unikalne zamówienia
                    self.orders.append(contentsOf: newOrders)
                    
                    print("Odfiltrowano \(orders.count - newOrders.count) duplikatów zamówień")
                }
                
                // Sortujemy zamówienia od najnowszych do najstarszych
                self.orders.sort { $0.date > $1.date }
                
                print("Pobrano łącznie \(self.orders.count) unikalnych zamówień")
                
                // Sprawdzamy, czy są jeszcze zamówienia do pobrania
                if orders.count == 100 {  // Jeśli pobraliśmy pełną stronę (100 zamówień), to prawdopodobnie są jeszcze zamówienia do pobrania
                    if isDeltaUpdate {
                        print("🔄 Delta update: Pobrano pełną stronę zamówień (\(orders.count)). Pobieranie kolejnej partii...")
                    } else {
                        print("Pobrano pełną stronę zamówień (\(orders.count)). Pobieranie kolejnej partii...")
                    }
                    
                    // Znajdujemy najnowszą datę potwierdzenia zamówienia w bieżącej partii
                    if let lastOrder = orders.max(by: { $0.dateConfirmed < $1.dateConfirmed }) {
                        // Aktualizujemy informację o postępie
                        if isDeltaUpdate {
                            self.loadingOrdersProgress = "Pobrano \(self.orders.count) zamówień. Pobieranie nowych..."
                        } else {
                            self.loadingOrdersProgress = "Pobrano \(self.orders.count) zamówień. Pobieranie kolejnej partii..."
                        }
                        
                        // Dodajemy opóźnienie przed pobraniem kolejnej partii, aby uniknąć przekroczenia limitu API (100 zapytań/min)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            // Pobieramy kolejną partię zamówień, używając daty potwierdzenia ostatniego zamówienia
                            self.fetchOrdersBatch(dateFrom: dateFrom, dateTo: dateTo, statusId: statusId, lastConfirmedDate: lastOrder.dateConfirmed, isDeltaUpdate: isDeltaUpdate)
                        }
                    } else {
                        // Nie udało się znaleźć daty potwierdzenia - kończymy pobieranie
                        self.connectionStatus = .connected
                        self.error = nil
                        self.isLoading = false
                        if isDeltaUpdate {
                            self.loadingOrdersProgress = "Pobrano nowe zamówienia: \(self.orders.count)"
                            print("🔄 Delta update: Zakończono pobieranie nowych zamówień. Łącznie: \(self.orders.count)")
                        } else {
                            self.loadingOrdersProgress = "Pobrano wszystkie zamówienia: \(self.orders.count)"
                            print("Zakończono pobieranie wszystkich zamówień. Łącznie: \(self.orders.count)")
                        }
                        
                        // Po zakończeniu aktualizacji, odświeżamy widok podsumowania dziennego
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.objectWillChange.send()
                            print("🔄 Odświeżono widok podsumowania dziennego po pobraniu zamówień")
                        }
                    }
                } else {
                    // Wszystkie zamówienia zostały pobrane
                    self.connectionStatus = .connected
                    self.error = nil
                    self.isLoading = false
                    if isDeltaUpdate {
                        if orders.isEmpty {
                            self.loadingOrdersProgress = "Brak nowych zamówień"
                            print("🔄 Delta update: Brak nowych zamówień")
                        } else {
                            self.loadingOrdersProgress = "Pobrano \(orders.count) nowych zamówień"
                            print("🔄 Delta update: Pobrano \(orders.count) nowych zamówień. Łącznie: \(self.orders.count)")
                        }
                    } else {
                        self.loadingOrdersProgress = "Pobrano wszystkie zamówienia: \(self.orders.count)"
                        print("Zakończono pobieranie wszystkich zamówień. Łącznie: \(self.orders.count)")
                    }
                    
                    // Po zakończeniu aktualizacji, odświeżamy widok podsumowania dziennego
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.objectWillChange.send()
                        print("🔄 Odświeżono widok podsumowania dziennego po pobraniu zamówień")
                    }
                }
            })
            .store(in: &cancellables)
    }
    
    // Pomocnicza funkcja do znajdowania informacji o statusie
    private func getOrderStatusInfo(for statusId: String) -> OrderStatusInfo? {
        return orderStatuses.first { $0.id == statusId }
    }
    
    // Funkcja pomocnicza do wysyłania żądań API
    private func sendRequest(parameters: [String: Any], completion: @escaping (Bool, Data?) -> Void) {
        guard !apiToken.isEmpty else {
            print("❌ Brak tokenu API")
            completion(false, nil)
            return
        }
        
        // Pobieramy metodę i parametry z przekazanego słownika
        let method = parameters["method"] as? String ?? ""
        let requestParameters = parameters["parameters"] as? [String: Any] ?? [:]
        
        // Konwertujemy tylko parametry żądania do formatu JSON
        guard let parametersData = try? JSONSerialization.data(withJSONObject: requestParameters),
              let parametersJSONString = String(data: parametersData, encoding: .utf8) else {
            print("❌ Błąd serializacji parametrów")
            completion(false, nil)
            return
        }
        
        guard let url = URL(string: baseURL) else {
            print("❌ Nieprawidłowy URL")
            completion(false, nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue(apiToken, forHTTPHeaderField: "X-BLToken")
        
        // Przygotowujemy dane w formacie application/x-www-form-urlencoded
        let requestBody = "method=\(method)&parameters=\(parametersJSONString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = requestBody.data(using: .utf8)
        
        // Logujemy żądanie do debugowania
        logRequest(request, requestBody)
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Błąd sieciowy: \(error.localizedDescription)")
                completion(false, nil)
                return
            }
            
            guard let data = data else {
                print("❌ Brak danych w odpowiedzi")
                completion(false, nil)
                return
            }
            
            // Logujemy odpowiedź do debugowania
            self.logResponse(data)
            
            // Zwracamy sukces i dane
            completion(true, data)
        }
        
        task.resume()
    }
    
    // Funkcja pomocnicza do debugowania pierwszego zamówienia
    private func debugFirstOrder(_ order: [String: Any]) {
        print("🔍 DEBUGOWANIE PIERWSZEGO ZAMÓWIENIA:")
        print("ID: \(order["order_id"] ?? "brak")")
        print("Numer zamówienia: \(order["order_number"] ?? "brak")")
        print("Kwota całkowita: \(order["price_total"] ?? "brak")")
        print("Waluta: \(order["currency"] ?? "brak")")
        print("Status: \(order["order_status_id"] ?? "brak")")
        print("Data dodania: \(order["date_add"] ?? "brak")")
        
        if let products = order["products"] as? [[String: Any]] {
            print("Liczba produktów: \(products.count)")
            
            if let firstProduct = products.first {
                print("Pierwszy produkt:")
                print("  Nazwa: \(firstProduct["name"] ?? "brak")")
                print("  Cena: \(firstProduct["price_brutto"] ?? "brak")")
                print("  Ilość: \(firstProduct["quantity"] ?? "brak")")
                
                // Wypisywanie wszystkich kluczy produktu dla lepszego debugowania
                print("  📋 Dostępne klucze produktu: \(firstProduct.keys.joined(separator: ", "))")
                
                // Sprawdzamy standardowe pole image_url
                if let imageUrl = firstProduct["image_url"] as? String {
                    print("  🖼️ Pole image_url: \(imageUrl)")
                    if !imageUrl.isEmpty {
                        print("  ✅ API zwraca niepusty URL obrazka w polu image_url")
                    } else {
                        print("  ⚠️ API zwraca pusty URL obrazka w polu image_url")
                    }
                } else {
                    print("  ❌ Pole image_url nie istnieje w danych produktu")
                }
                
                // Sprawdzamy inne możliwe pola z URL obrazków
                for key in ["image", "images", "img", "imgurl", "img_url", "product_image", "thumbnail"] {
                    if let value = firstProduct[key] {
                        print("  🔍 Znaleziono alternatywne pole '\(key)': \(value)")
                    }
                }
                
                // Wyświetlamy wszystkie pola zawierające w nazwie "image" lub "img"
                for (key, value) in firstProduct {
                    if key.lowercased().contains("image") || key.lowercased().contains("img") {
                        print("  🔎 Pole z obrazkiem '\(key)': \(value)")
                    }
                }
                
                // Dodatkowe informacje o produkcie
                print("\n  📝 SZCZEGÓŁY PRODUKTU:")
                print("  ID: \(firstProduct["product_id"] ?? "brak")")
                print("  SKU: \(firstProduct["sku"] ?? "brak")")
                print("  EAN: \(firstProduct["ean"] ?? "brak")")
                print("  Cena netto: \(firstProduct["price_netto"] ?? "brak")")
                
                // Wyświetlamy wszystkie pola produktu dla pełnej analizy
                print("\n  🔍 WSZYSTKIE POLA PRODUKTU:")
                for (key, value) in firstProduct {
                    print("  \(key): \(value)")
                }
            } else {
                print("Brak produktów w zamówieniu")
            }
        } else {
            print("Brak produktów lub nieprawidłowy format")
        }
        
        // Wyświetlamy informacje o metodzie getInventories
        print("\n🔍 INFORMACJA O METODZIE getInventories:")
        print("Aby pobrać obrazki produktów, należy użyć metody getInventoryProductsData.")
        print("Proces wymaga następujących kroków:")
        print("1. Pobrać listę katalogów metodą getInventories")
        print("2. Pobrać listę produktów metodą getInventoryProductsList")
        print("3. Pobrać szczegółowe dane produktów metodą getInventoryProductsData")
        print("Obrazki są dostępne w polu 'images' jako obiekt z kluczami od 1 do 16.")
        
        print("🔍 KONIEC DEBUGOWANIA")
    }
    
    func getOrderStatistics() -> [String: Double] {
        var statistics: [String: Double] = [:]
        
        // Wartość wszystkich zamówień
        statistics["totalValue"] = orders.reduce(0) { $0 + $1.totalAmount }
        
        // Liczba zamówień w każdym statusie
        for status in OrderStatus.allCases {
            let count = orders.filter { $0.status == status.rawValue }.count
            statistics["status_\(status.rawValue)"] = Double(count)
        }
        
        // Średnia wartość zamówienia
        if !orders.isEmpty {
            statistics["averageOrderValue"] = statistics["totalValue"]! / Double(orders.count)
        } else {
            statistics["averageOrderValue"] = 0
        }
        
        return statistics
    }
    
    func getTopSellingProducts(limit: Int = 5) -> [(name: String, quantity: Int, id: String, imageUrl: String?)] {
        var productQuantities: [String: (quantity: Int, id: String, sku: String, imageUrl: String?)] = [:]
        
        // Zliczanie ilości sprzedanych produktów
        for order in orders {
            for item in order.items {
                let productId = item.id
                let productName = item.name
                let productSku = item.sku
                let imageUrl = item.imageUrl
                
                if let existingProduct = productQuantities[productName] {
                    // Aktualizujemy ilość dla istniejącego produktu
                    // Preferujemy rzeczywisty URL obrazka, jeśli jest dostępny
                    let updatedImageUrl = imageUrl?.hasPrefix("http") == true ? imageUrl : existingProduct.imageUrl
                    productQuantities[productName] = (quantity: existingProduct.quantity + item.quantity, id: existingProduct.id, sku: existingProduct.sku, imageUrl: updatedImageUrl)
                } else {
                    // Dodajemy nowy produkt
                    productQuantities[productName] = (quantity: item.quantity, id: productId, sku: productSku, imageUrl: imageUrl)
                }
            }
        }
        
        print("🔍 Znaleziono \(productQuantities.count) produktów w zamówieniach")
        print("📊 Liczba produktów w magazynie: \(inventoryProducts.count)")
        
        // Próbujemy znaleźć odpowiadające produkty w magazynie, aby użyć ich obrazków
        for (productName, productData) in productQuantities {
            print("🔎 Szukam produktu '\(productName)' w magazynie (SKU: \(productData.sku), ID: \(productData.id))")
            
            // Szukamy produktu w magazynie po SKU
            if let inventoryProduct = inventoryProducts.first(where: { $0.sku == productData.sku && $0.sku.isEmpty == false }) {
                // Jeśli znaleziono produkt w magazynie i ma URL obrazka, używamy go
                if let inventoryImageUrl = inventoryProduct.imageUrl, !inventoryImageUrl.isEmpty {
                    print("✅ Znaleziono produkt w magazynie po SKU. URL obrazka: \(inventoryImageUrl)")
                    productQuantities[productName] = (quantity: productData.quantity, id: productData.id, sku: productData.sku, imageUrl: inventoryImageUrl)
                } else {
                    print("⚠️ Znaleziono produkt w magazynie po SKU, ale brak URL obrazka")
                }
            }
            // Jeśli nie znaleziono po SKU, próbujemy po ID
            else if let inventoryProduct = inventoryProducts.first(where: { $0.id == productData.id }) {
                // Jeśli znaleziono produkt w magazynie i ma URL obrazka, używamy go
                if let inventoryImageUrl = inventoryProduct.imageUrl, !inventoryImageUrl.isEmpty {
                    print("✅ Znaleziono produkt w magazynie po ID. URL obrazka: \(inventoryImageUrl)")
                    productQuantities[productName] = (quantity: productData.quantity, id: productData.id, sku: productData.sku, imageUrl: inventoryImageUrl)
                } else {
                    print("⚠️ Znaleziono produkt w magazynie po ID, ale brak URL obrazka")
                }
            } else {
                print("❌ Nie znaleziono produktu w magazynie")
            }
        }
        
        // Sortowanie i ograniczenie do limitu
        let result = productQuantities.sorted { $0.value.quantity > $1.value.quantity }
            .prefix(limit)
            .map { (name: $0.key, quantity: $0.value.quantity, id: $0.value.id, imageUrl: $0.value.imageUrl) }
        
        // Wyświetlamy informacje o wynikowych produktach
        print("📋 Najlepiej sprzedające się produkty:")
        for (index, product) in result.enumerated() {
            print("\(index + 1). \(product.name) (\(product.quantity) szt.) - URL obrazka: \(product.imageUrl ?? "brak")")
        }
        
        return result
    }
    
    func getSalesDataForLastWeek() -> [(day: String, value: Double, date: Date)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Tworzymy daty dla ostatnich 7 dni
        var days: [(date: Date, day: String, value: Double)] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let formatter = DateFormatter()
                formatter.dateFormat = "EE" // Skrócona nazwa dnia tygodnia
                formatter.locale = Locale(identifier: "pl_PL") // Ustawiamy polską lokalizację
                let dayName = formatter.string(from: date)
                days.append((date: date, day: dayName, value: 0.0))
            }
        }
        
        // Grupujemy zamówienia według dnia
        for order in orders {
            let orderDate = calendar.startOfDay(for: order.date)
            for i in 0..<days.count {
                if calendar.isDate(orderDate, inSameDayAs: days[i].date) {
                    days[i].value += order.totalAmount
                    break
                }
            }
        }
        
        // Odwracamy, aby najstarszy dzień był pierwszy
        let result = days.reversed().map { (day: $0.day, value: $0.value, date: $0.date) }
        
        // Wyświetlamy informacje o danych sprzedaży
        print("📊 Dane sprzedaży z ostatnich 7 dni:")
        for (index, day) in result.enumerated() {
            print("\(index + 1). \(day.day): \(day.value) zł")
        }
        
        return result
    }
    
    // Funkcja zwracająca podsumowanie aktualnego dnia
    func getTodaySummary() -> (orderCount: Int, totalValue: Double, newOrdersCount: Int, topProducts: [(name: String, quantity: Int, id: String, imageUrl: String?)]) {
        let calendar = Calendar.current
        let now = Date()
        // Zamiast ostatnich 24h, bierzemy początek bieżącego dnia
        let startOfToday = calendar.startOfDay(for: now)
        
        // Filtrujemy zamówienia tylko z bieżącego dnia
        let todayOrders = orders.filter { order in
            return order.date >= startOfToday && order.date <= now
        }
        
        // Jeśli nie ma żadnych zamówień z bieżącego dnia, zwracamy zerowe wartości
        if todayOrders.isEmpty {
            print("📊 Brak zamówień z bieżącego dnia - zwracam zerowe wartości")
            return (orderCount: 0, totalValue: 0.0, newOrdersCount: 0, topProducts: [])
        }
        
        print("📊 Znaleziono \(todayOrders.count) zamówień z bieżącego dnia")
        
        // Liczba zamówień z bieżącego dnia
        let orderCount = todayOrders.count
        
        // Całkowita wartość zamówień z bieżącego dnia
        let totalValue = todayOrders.reduce(0) { $0 + $1.totalAmount }
        
        // Liczba nowych zamówień z bieżącego dnia
        let newOrdersCount = todayOrders.filter { $0.status == OrderStatus.new.rawValue }.count
        
        // Najlepiej sprzedające się produkty z bieżącego dnia
        var productQuantities: [String: (quantity: Int, id: String, sku: String, imageUrl: String?)] = [:]
        
        for order in todayOrders {
            for item in order.items {
                let productId = item.id
                let productName = item.name
                let productSku = item.sku
                let imageUrl = item.imageUrl
                
                if let existingProduct = productQuantities[productName] {
                    // Aktualizujemy ilość dla istniejącego produktu
                    // Preferujemy rzeczywisty URL obrazka, jeśli jest dostępny
                    let updatedImageUrl = imageUrl?.hasPrefix("http") == true ? imageUrl : existingProduct.imageUrl
                    productQuantities[productName] = (quantity: existingProduct.quantity + item.quantity, id: existingProduct.id, sku: existingProduct.sku, imageUrl: updatedImageUrl)
                } else {
                    // Dodajemy nowy produkt
                    productQuantities[productName] = (quantity: item.quantity, id: productId, sku: productSku, imageUrl: imageUrl)
                }
            }
        }
        
        print("🔍 Znaleziono \(productQuantities.count) produktów w zamówieniach z bieżącego dnia")
        print("📊 Liczba produktów w magazynie: \(inventoryProducts.count)")
        
        // Próbujemy znaleźć odpowiadające produkty w magazynie, aby użyć ich obrazków
        for (productName, productData) in productQuantities {
            print("🔎 Szukam produktu '\(productName)' w magazynie (SKU: \(productData.sku), ID: \(productData.id))")
            
            // Szukamy produktu w magazynie po SKU
            if let inventoryProduct = inventoryProducts.first(where: { $0.sku == productData.sku && $0.sku.isEmpty == false }) {
                // Jeśli znaleziono produkt w magazynie i ma URL obrazka, używamy go
                if let inventoryImageUrl = inventoryProduct.imageUrl, !inventoryImageUrl.isEmpty {
                    print("✅ Znaleziono produkt w magazynie po SKU. URL obrazka: \(inventoryImageUrl)")
                    productQuantities[productName] = (quantity: productData.quantity, id: productData.id, sku: productData.sku, imageUrl: inventoryImageUrl)
                } else {
                    print("⚠️ Znaleziono produkt w magazynie po SKU, ale brak URL obrazka")
                }
            }
            // Jeśli nie znaleziono po SKU, próbujemy po ID
            else if let inventoryProduct = inventoryProducts.first(where: { $0.id == productData.id }) {
                // Jeśli znaleziono produkt w magazynie i ma URL obrazka, używamy go
                if let inventoryImageUrl = inventoryProduct.imageUrl, !inventoryImageUrl.isEmpty {
                    print("✅ Znaleziono produkt w magazynie po ID. URL obrazka: \(inventoryImageUrl)")
                    productQuantities[productName] = (quantity: productData.quantity, id: productData.id, sku: productData.sku, imageUrl: inventoryImageUrl)
                } else {
                    print("⚠️ Znaleziono produkt w magazynie po ID, ale brak URL obrazka")
                }
            } else {
                print("❌ Nie znaleziono produktu w magazynie")
            }
        }
        
        let topProducts = productQuantities.sorted { $0.value.quantity > $1.value.quantity }
            .prefix(5)
            .map { (name: $0.key, quantity: $0.value.quantity, id: $0.value.id, imageUrl: $0.value.imageUrl) }
        
        // Wyświetlamy informacje o wynikowych produktach
        print("📋 Najlepiej sprzedające się produkty z bieżącego dnia:")
        for (index, product) in topProducts.enumerated() {
            print("\(index + 1). \(product.name) (\(product.quantity) szt.) - URL obrazka: \(product.imageUrl ?? "brak")")
        }
        
        return (orderCount: orderCount, totalValue: totalValue, newOrdersCount: newOrdersCount, topProducts: topProducts)
    }
    
    // MARK: - Metody do obsługi produktów z magazynu
    
    // Pobieranie listy katalogów (magazynów)
    func fetchInventories() {
        guard connectionStatus.isConnected else {
            print("❌ Brak połączenia z API")
            return
        }
        
        DispatchQueue.main.async {
            self.isLoadingProducts = true
        }
        
        let parameters: [String: Any] = [
            "method": "getInventories",
            "parameters": [:]
        ]
        
        sendRequest(parameters: parameters) { [weak self] success, responseData in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoadingProducts = false
                
                if success, let responseData = responseData {
                    do {
                        // Logowanie pełnej odpowiedzi API dla debugowania
                        if let jsonString = String(data: responseData, encoding: .utf8) {
                            print("📥 Pełna odpowiedź API getInventories: \(jsonString)")
                        }
                        
                        if let json = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
                           let status = json["status"] as? String, status == "SUCCESS" {
                            
                            if let inventoriesArray = json["inventories"] as? [[String: Any]] {
                                var newInventories: [Inventory] = []
                                
                                for inventory in inventoriesArray {
                                    // Obsługa inventory_id jako liczby lub stringa
                                    let inventoryId: String
                                    if let idString = inventory["inventory_id"] as? String {
                                        inventoryId = idString
                                    } else if let idNumber = inventory["inventory_id"] as? Int {
                                        inventoryId = String(idNumber)
                                    } else if let idNumber = inventory["inventory_id"] as? Double {
                                        inventoryId = String(Int(idNumber))
                                    } else {
                                        continue // Pomijamy ten element, jeśli nie ma poprawnego ID
                                    }
                                    
                                    if let name = inventory["name"] as? String {
                                        newInventories.append(Inventory(id: inventoryId, name: name))
                                    }
                                }
                                
                                self.inventories = newInventories
                                print("✅ Pobrano \(newInventories.count) katalogów")
                                
                                // Wypisujemy wszystkie katalogi dla debugowania
                                for inventory in newInventories {
                                    print("📋 Katalog: ID=\(inventory.id), Nazwa=\(inventory.name)")
                                }
                                
                                // Jeśli mamy katalogi, wybieramy pierwszy i pobieramy jego produkty
                                if let firstInventory = newInventories.first {
                                    self.selectedInventoryId = firstInventory.id
                                    print("🔍 Wybrany katalog do pobrania produktów: ID=\(firstInventory.id), Nazwa=\(firstInventory.name)")
                                    self.fetchInventoryProducts(inventoryId: firstInventory.id)
                                }
                            } else {
                                print("❌ Brak katalogów w odpowiedzi")
                                self.error = "Brak katalogów w odpowiedzi"
                            }
                        } else {
                            self.isLoadingProducts = false
                            let errorMessage = (try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any])?["error_message"] as? String ?? "Nieznany błąd"
                            print("❌ Błąd API: \(errorMessage)")
                            self.error = "Błąd API: \(errorMessage)"
                        }
                    } catch {
                        print("❌ Błąd podczas przetwarzania odpowiedzi: \(error.localizedDescription)")
                        self.error = "Błąd podczas przetwarzania odpowiedzi: \(error.localizedDescription)"
                    }
                } else {
                    print("❌ Błąd połączenia z API")
                    self.error = "Błąd połączenia z API"
                }
            }
        }
    }
    
    // Pobieranie listy produktów z katalogu
    func fetchInventoryProducts(inventoryId: String, page: Int = 1, allProductIds: [String] = []) {
        guard connectionStatus.isConnected else {
            print("❌ Brak połączenia z API")
            return
        }
        
        DispatchQueue.main.async {
            self.isLoadingProducts = true
            self.selectedInventoryId = inventoryId
        }
        
        print("🔍 Rozpoczynam pobieranie produktów z katalogu ID=\(inventoryId), strona=\(page)")
        
        // Konwertujemy inventoryId na liczbę, ponieważ API oczekuje wartości liczbowej
        let inventoryIdValue: Any
        if let inventoryIdInt = Int(inventoryId) {
            inventoryIdValue = inventoryIdInt
        } else {
            inventoryIdValue = inventoryId
        }
        
        // Tworzymy parametry żądania
        // Ustawiamy limit na 1000 produktów na stronę (maksymalna wartość dozwolona przez API)
        let requestParameters: [String: Any] = [
            "inventory_id": inventoryIdValue,
            "page": page,
            "filter_limit": 1000  // Maksymalna dozwolona wartość dla API
        ]
        
        let parameters: [String: Any] = [
            "method": "getInventoryProductsList",
            "parameters": requestParameters
        ]
        
        // Logowanie parametrów żądania
        if let parametersData = try? JSONSerialization.data(withJSONObject: parameters),
           let parametersString = String(data: parametersData, encoding: .utf8) {
            print("📤 Parametry żądania getInventoryProductsList (strona \(page)): \(parametersString)")
        }
        
        sendRequest(parameters: parameters) { [weak self] success, responseData in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if success, let responseData = responseData {
                    do {
                        // Logowanie pełnej odpowiedzi API dla debugowania
                        if let jsonString = String(data: responseData, encoding: .utf8) {
                            print("📥 Pełna odpowiedź API getInventoryProductsList (strona \(page)): \(jsonString)")
                        }
                        
                        if let json = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
                           let status = json["status"] as? String, status == "SUCCESS" {
                            
                            if let productsDict = json["products"] as? [String: [String: Any]] {
                                // Pobieramy ID produktów z bieżącej strony
                                var currentPageProductIds: [String] = []
                                
                                print("✅ Znaleziono \(productsDict.count) produktów w katalogu na stronie \(page)")
                                
                                for (productId, _) in productsDict {
                                    currentPageProductIds.append(productId)
                                }
                                
                                // Łączymy ID produktów z poprzednich stron z ID z bieżącej strony
                                let updatedProductIds = allProductIds + currentPageProductIds
                                print("📊 Łącznie znaleziono \(updatedProductIds.count) produktów na wszystkich stronach")
                                
                                // Sprawdzamy, czy mamy więcej stron do pobrania
                                if !currentPageProductIds.isEmpty {
                                    // Jeśli liczba produktów na stronie wynosi 1000, to prawdopodobnie są kolejne strony
                                    if productsDict.count >= 1000 {
                                        print("🔄 Pobieranie kolejnej strony produktów (\(page + 1))...")
                                        // Dodajemy małe opóźnienie, aby uniknąć przekroczenia limitów API
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                            // Rekurencyjnie pobieramy kolejną stronę
                                            self.fetchInventoryProducts(inventoryId: inventoryId, page: page + 1, allProductIds: updatedProductIds)
                                        }
                                    } else {
                                        // To była ostatnia strona, pobieramy szczegółowe dane wszystkich produktów
                                        print("🔍 Pobieranie szczegółowych danych dla \(updatedProductIds.count) produktów z \(page) stron")
                                        if !updatedProductIds.isEmpty {
                                            self.fetchInventoryProductsDetails(inventoryId: inventoryId, productIds: updatedProductIds)
                                        } else {
                                            self.isLoadingProducts = false
                                            self.inventoryProducts = []
                                            print("✅ Brak produktów w katalogu")
                                        }
                                    }
                                } else {
                                    // Brak produktów na bieżącej stronie, ale mamy produkty z poprzednich stron
                                    if !updatedProductIds.isEmpty {
                                        print("🔍 Pobieranie szczegółowych danych dla \(updatedProductIds.count) produktów z \(page - 1) stron")
                                        self.fetchInventoryProductsDetails(inventoryId: inventoryId, productIds: updatedProductIds)
                                    } else {
                                        self.isLoadingProducts = false
                                        self.inventoryProducts = []
                                        print("✅ Brak produktów w katalogu")
                                    }
                                }
                            } else {
                                // Brak produktów na bieżącej stronie, ale mamy produkty z poprzednich stron
                                if !allProductIds.isEmpty {
                                    print("🔍 Pobieranie szczegółowych danych dla \(allProductIds.count) produktów z \(page - 1) stron")
                                    self.fetchInventoryProductsDetails(inventoryId: inventoryId, productIds: allProductIds)
                                } else {
                                    self.isLoadingProducts = false
                                    print("❌ Brak produktów w odpowiedzi lub nieprawidłowy format odpowiedzi")
                                    self.error = "Brak produktów w odpowiedzi"
                                }
                            }
                        } else {
                            // Obsługa błędu API, ale tylko jeśli nie mamy produktów z poprzednich stron
                            if allProductIds.isEmpty {
                                self.isLoadingProducts = false
                                let errorMessage = (try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any])?["error_message"] as? String ?? "Nieznany błąd"
                                print("❌ Błąd API: \(errorMessage)")
                                self.error = "Błąd API: \(errorMessage)"
                            } else {
                                // Mamy produkty z poprzednich stron, więc pobieramy ich szczegółowe dane
                                print("🔍 Pobieranie szczegółowych danych dla \(allProductIds.count) produktów z \(page - 1) stron")
                                self.fetchInventoryProductsDetails(inventoryId: inventoryId, productIds: allProductIds)
                            }
                        }
                    } catch {
                        // Obsługa błędu parsowania, ale tylko jeśli nie mamy produktów z poprzednich stron
                        if allProductIds.isEmpty {
                            self.isLoadingProducts = false
                            print("❌ Błąd podczas przetwarzania odpowiedzi: \(error.localizedDescription)")
                            self.error = "Błąd podczas przetwarzania odpowiedzi: \(error.localizedDescription)"
                        } else {
                            // Mamy produkty z poprzednich stron, więc pobieramy ich szczegółowe dane
                            print("🔍 Pobieranie szczegółowych danych dla \(allProductIds.count) produktów z \(page - 1) stron")
                            self.fetchInventoryProductsDetails(inventoryId: inventoryId, productIds: allProductIds)
                        }
                    }
                } else {
                    // Obsługa błędu połączenia, ale tylko jeśli nie mamy produktów z poprzednich stron
                    if allProductIds.isEmpty {
                        self.isLoadingProducts = false
                        print("❌ Błąd połączenia z API")
                        self.error = "Błąd połączenia z API"
                    } else {
                        // Mamy produkty z poprzednich stron, więc pobieramy ich szczegółowe dane
                        print("🔍 Pobieranie szczegółowych danych dla \(allProductIds.count) produktów z \(page - 1) stron")
                        self.fetchInventoryProductsDetails(inventoryId: inventoryId, productIds: allProductIds)
                    }
                }
            }
        }
    }
    
    // Pobieranie szczegółowych danych produktów, w tym obrazków
    private func fetchInventoryProductsDetails(inventoryId: String, productIds: [String]) {
        print("🔍 Rozpoczynam pobieranie szczegółowych danych produktów z katalogu ID=\(inventoryId)")
        print("📊 Łączna liczba produktów do pobrania: \(productIds.count)")
        
        // Dzielimy produkty na partie po 600 sztuk, aby uniknąć przekroczenia limitów API
        let batchSize = 600 // Zwiększamy rozmiar partii dla znacznego zmniejszenia liczby zapytań
        let batches = stride(from: 0, to: productIds.count, by: batchSize).map {
            Array(productIds[$0..<min($0 + batchSize, productIds.count)])
        }
        
        print("📦 Podzielono produkty na \(batches.count) partii po maksymalnie \(batchSize) produktów")
        
        // Resetujemy listę produktów przed pobraniem nowych
        DispatchQueue.main.async {
            self.inventoryProducts = []
            
            // Pokazujemy informację o postępie
            self.loadingProgress = 0.0
        }
        
        // Pobieramy dane dla każdej partii produktów
        fetchNextBatch(inventoryId: inventoryId, batches: batches, currentBatchIndex: 0, allProducts: [])
    }
    
    // Pomocnicza funkcja do pobierania kolejnych partii produktów
    private func fetchNextBatch(inventoryId: String, batches: [[String]], currentBatchIndex: Int, allProducts: [InventoryProduct]) {
        // Sprawdzamy, czy mamy jeszcze partie do pobrania
        guard currentBatchIndex < batches.count else {
            // Wszystkie partie zostały pobrane, kończymy proces
            DispatchQueue.main.async {
                // Usuwamy duplikaty produktów na podstawie ID
                var uniqueProducts: [InventoryProduct] = []
                var seenIds = Set<String>()
                
                for product in allProducts {
                    if !seenIds.contains(product.id) {
                        uniqueProducts.append(product)
                        seenIds.insert(product.id)
                    } else {
                        print("⚠️ Znaleziono duplikat produktu z ID: \(product.id), nazwa: \(product.name)")
                    }
                }
                
                // Sortujemy produkty alfabetycznie
                let sortedProducts = uniqueProducts.sorted { $0.name < $1.name }
                self.inventoryProducts = sortedProducts
                self.isLoadingProducts = false
                self.loadingProgress = 1.0
                print("✅ Zakończono pobieranie wszystkich partii. Łącznie pobrano \(sortedProducts.count) unikalnych produktów z \(allProducts.count) wszystkich.")
                
                // Wypisujemy pierwsze 10 produktów dla weryfikacji
                print("🔍 Przykładowe produkty:")
                for (index, product) in sortedProducts.prefix(10).enumerated() {
                    print("  \(index + 1). ID: \(product.id), Nazwa: \(product.name), Cena: \(product.price), Ilość: \(product.quantity)")
                }
            }
            return
        }
        
        let currentBatch = batches[currentBatchIndex]
        print("🔄 Pobieranie partii \(currentBatchIndex + 1)/\(batches.count) (\(currentBatch.count) produktów)")
        
        // Aktualizujemy postęp pobierania
        DispatchQueue.main.async {
            self.loadingProgress = Double(currentBatchIndex) / Double(batches.count)
        }
        
        // Konwertujemy inventoryId na liczbę, ponieważ API oczekuje wartości liczbowej
        let inventoryIdValue: Any
        if let inventoryIdInt = Int(inventoryId) {
            inventoryIdValue = inventoryIdInt
        } else {
            inventoryIdValue = inventoryId
        }
        
        // Tworzymy parametry żądania - uwaga: nie zagnieżdżamy ich podwójnie
        let requestParameters: [String: Any] = [
            "inventory_id": inventoryIdValue,
            "products": currentBatch
        ]
        
        let parameters: [String: Any] = [
            "method": "getInventoryProductsData",
            "parameters": requestParameters
        ]
        
        // Logowanie parametrów żądania
        if let parametersData = try? JSONSerialization.data(withJSONObject: parameters),
           let parametersString = String(data: parametersData, encoding: .utf8) {
            print("📤 Parametry żądania getInventoryProductsData (partia \(currentBatchIndex + 1)): \(parametersString)")
        }
        
        // Dodajemy opóźnienie między żądaniami, aby uniknąć przekroczenia limitów API
        // Zwiększamy opóźnienie z 0.3 do 0.7 sekundy, aby lepiej respektować limit 100 zapytań/min
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self = self else { return }
            
            self.sendRequest(parameters: parameters) { [weak self] success, responseData in
                guard let self = self else { return }
                
                if success, let responseData = responseData {
                    do {
                        // Logowanie pełnej odpowiedzi API dla debugowania
                        if let jsonString = String(data: responseData, encoding: .utf8) {
                            print("📥 Pełna odpowiedź API getInventoryProductsData (partia \(currentBatchIndex + 1)): \(jsonString)")
                        }
                        
                        if let json = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
                           let status = json["status"] as? String, status == "SUCCESS" {
                            
                            if let productsDict = json["products"] as? [String: [String: Any]] {
                                var newProducts: [InventoryProduct] = []
                                
                                print("✅ Pobrano szczegółowe dane dla \(productsDict.count) produktów w partii \(currentBatchIndex + 1)")
                                
                                for (productId, productData) in productsDict {
                                    // Tworzymy kopię danych produktu i dodajemy do niej ID z klucza słownika
                                    var productDataWithId = productData
                                    productDataWithId["id"] = productId
                                    
                                    let product = InventoryProduct(from: productDataWithId)
                                    newProducts.append(product)
                                }
                                
                                // Łączymy nowe produkty z już pobranymi
                                let updatedProducts = allProducts + newProducts
                                print("📊 Łącznie pobrano \(updatedProducts.count) produktów z \(currentBatchIndex + 1) partii")
                                
                                // Pobieramy kolejną partię
                                self.fetchNextBatch(inventoryId: inventoryId, batches: batches, currentBatchIndex: currentBatchIndex + 1, allProducts: updatedProducts)
                            } else {
                                print("⚠️ Brak danych produktów w odpowiedzi dla partii \(currentBatchIndex + 1)")
                                // Kontynuujemy z kolejną partią, nawet jeśli bieżąca nie zwróciła danych
                                self.fetchNextBatch(inventoryId: inventoryId, batches: batches, currentBatchIndex: currentBatchIndex + 1, allProducts: allProducts)
                            }
                        } else {
                            let errorMessage = (try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any])?["error_message"] as? String ?? "Nieznany błąd"
                            print("❌ Błąd API dla partii \(currentBatchIndex + 1): \(errorMessage)")
                            // Kontynuujemy z kolejną partią, nawet jeśli bieżąca zakończyła się błędem
                            self.fetchNextBatch(inventoryId: inventoryId, batches: batches, currentBatchIndex: currentBatchIndex + 1, allProducts: allProducts)
                        }
                    } catch {
                        print("❌ Błąd podczas przetwarzania odpowiedzi dla partii \(currentBatchIndex + 1): \(error.localizedDescription)")
                        // Kontynuujemy z kolejną partią, nawet jeśli bieżąca zakończyła się błędem
                        self.fetchNextBatch(inventoryId: inventoryId, batches: batches, currentBatchIndex: currentBatchIndex + 1, allProducts: allProducts)
                    }
                } else {
                    print("❌ Błąd połączenia z API dla partii \(currentBatchIndex + 1)")
                    // Kontynuujemy z kolejną partią, nawet jeśli bieżąca zakończyła się błędem
                    self.fetchNextBatch(inventoryId: inventoryId, batches: batches, currentBatchIndex: currentBatchIndex + 1, allProducts: allProducts)
                }
            }
        }
    }
    
    // Funkcja do obliczania dziennego podsumowania
    func calculateDailySummary() {
        let summary = DailySummary(orders: orders, products: inventoryProducts)
        DispatchQueue.main.async {
            self.dailySummary = summary
        }
    }
    
    // Funkcja do uruchomienia automatycznego odświeżania podsumowania dziennego
    func startDailySummaryAutoRefresh() {
        // Zatrzymaj istniejący timer, jeśli istnieje
        summaryTimer?.invalidate()
        
        // Oblicz podsumowanie od razu
        calculateDailySummary()
        
        // Ustaw timer na odświeżanie co 5 minut (300 sekund) zamiast co 60 sekund
        summaryTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.calculateDailySummary()
        }
    }
    
    // Zatrzymaj automatyczne odświeżanie
    func stopDailySummaryAutoRefresh() {
        summaryTimer?.invalidate()
        summaryTimer = nil
    }
    
    // Funkcja do uruchomienia automatycznego pobierania nowych zamówień (delta update)
    func startDeltaUpdateAutoRefresh() {
        // Zatrzymaj istniejący timer, jeśli istnieje
        deltaUpdateTimer?.invalidate()
        
        // Pobierz nowe zamówienia od razu
        deltaUpdateOrders()
        
        // Pobierz zapisaną częstotliwość synchronizacji lub użyj domyślnej wartości 30 sekund
        let syncInterval = UserDefaults.standard.double(forKey: "syncIntervalInSeconds")
        let interval = syncInterval > 0 ? syncInterval : 30.0
        
        // Ustaw timer na odświeżanie z określoną częstotliwością
        deltaUpdateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.deltaUpdateOrders()
        }
        
        print("🔄 Uruchomiono automatyczne pobieranie nowych zamówień co \(interval) sekund")
    }
    
    // Zatrzymaj automatyczne pobieranie nowych zamówień
    func stopDeltaUpdateAutoRefresh() {
        deltaUpdateTimer?.invalidate()
        deltaUpdateTimer = nil
        print("🛑 Zatrzymano automatyczne pobieranie nowych zamówień")
    }
    
    // Aktualizacja częstotliwości synchronizacji
    func updateSyncInterval(_ intervalInSeconds: Double) {
        // Zatrzymaj istniejący timer
        deltaUpdateTimer?.invalidate()
        
        // Ustaw nowy timer z nową częstotliwością
        deltaUpdateTimer = Timer.scheduledTimer(withTimeInterval: intervalInSeconds, repeats: true) { [weak self] _ in
            self?.deltaUpdateOrders()
        }
        
        // Zapisz ustawienie w UserDefaults
        UserDefaults.standard.set(intervalInSeconds, forKey: "syncIntervalInSeconds")
        
        print("🔄 Zaktualizowano częstotliwość synchronizacji na \(intervalInSeconds) sekund")
    }
    
    // Funkcja do pobierania listy statusów zamówień
    func fetchOrderStatusList() {
        let parameters: [String: Any] = [
            "method": "getOrderStatusList",
            "parameters": [:]
        ]
        
        sendRequest(parameters: parameters) { [weak self] success, responseData in
            guard let self = self else { return }
            
            if success, let responseData = responseData {
                do {
                    if let jsonObject = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
                       let status = jsonObject["status"] as? String, status == "SUCCESS",
                       let statuses = jsonObject["statuses"] as? [[String: Any]] {
                        
                        var orderStatusList: [OrderStatusInfo] = []
                        
                        for statusData in statuses {
                            if let id = statusData["id"] as? Int,
                               let name = statusData["name"] as? String,
                               let nameForCustomer = statusData["name_for_customer"] as? String {
                                let color = statusData["color"] as? String ?? ""
                                let statusInfo = OrderStatusInfo(
                                    id: String(id),
                                    name: name,
                                    nameForCustomer: nameForCustomer,
                                    color: color
                                )
                                orderStatusList.append(statusInfo)
                            }
                        }
                        
                        DispatchQueue.main.async {
                            self.orderStatuses = orderStatusList
                            print("Pobrano \(orderStatusList.count) statusów zamówień")
                            
                            // Aktualizujemy informacje o statusach dla istniejących zamówień
                            self.updateOrderStatusInfo()
                        }
                    } else {
                        print("❌ Błąd podczas pobierania statusów zamówień")
                    }
                } catch {
                    print("❌ Błąd parsowania odpowiedzi: \(error.localizedDescription)")
                }
            } else {
                print("❌ Błąd połączenia z API podczas pobierania statusów zamówień")
            }
        }
    }
    
    // Funkcja do aktualizacji informacji o statusach dla istniejących zamówień
    private func updateOrderStatusInfo() {
        for i in 0..<orders.count {
            if let statusInfo = getOrderStatusInfo(for: orders[i].status) {
                orders[i].statusName = statusInfo.name
                orders[i].statusColor = statusInfo.color
            }
        }
    }
    
    // Funkcja do pobierania tylko nowych zamówień (delta update)
    func deltaUpdateOrders() {
        // Jeśli aktualnie trwa pobieranie, pomijamy
        if isLoading {
            print("🔄 Delta update: Pomijam, trwa już pobieranie zamówień")
            return
        }
        
        // Jeśli nie mamy żadnych zamówień, pobieramy wszystkie
        if orders.isEmpty {
            print("🔄 Delta update: Brak zamówień, pobieram wszystkie")
            fetchOrders()
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
            self.loadingOrdersProgress = "Pobieranie nowych zamówień..."
        }
        
        // Znajdujemy najnowszą datę potwierdzenia wśród istniejących zamówień
        if let latestOrder = orders.max(by: { $0.dateConfirmed < $1.dateConfirmed }) {
            // Pobieramy zamówienia od daty potwierdzenia najnowszego zamówienia + 1 sekunda
            let latestDate = latestOrder.dateConfirmed.addingTimeInterval(1)
            print("🔄 Delta update: Pobieranie zamówień od daty: \(latestDate)")
            
            // Wywołujemy fetchOrdersBatch z datą najnowszego zamówienia jako lastConfirmedDate
            fetchOrdersBatch(lastConfirmedDate: latestDate, isDeltaUpdate: true)
            
            // Sprawdzamy, czy jakieś zamówienia zostały usunięte w Baselinker
            checkForDeletedOrders()
            
            // Po zakończeniu aktualizacji, odświeżamy widok podsumowania dziennego
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.objectWillChange.send()
                print("🔄 Delta update: Odświeżono widok podsumowania dziennego")
            }
        } else {
            // Jeśli nie możemy znaleźć najnowszej daty, pobieramy wszystkie zamówienia
            print("🔄 Delta update: Nie znaleziono daty potwierdzenia, pobieram wszystkie zamówienia")
            fetchOrders()
            
            // Po zakończeniu aktualizacji, odświeżamy widok podsumowania dziennego
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.objectWillChange.send()
                print("🔄 Delta update: Odświeżono widok podsumowania dziennego")
            }
        }
    }
    
    // Funkcja do sprawdzania, czy jakieś zamówienia zostały usunięte w Baselinker
    private func checkForDeletedOrders() {
        // Sortujemy zamówienia od najnowszych do najstarszych
        let sortedOrders = orders.sorted { $0.dateConfirmed > $1.dateConfirmed }
        
        // Bierzemy tylko ostatnie 100 zamówień (lub mniej, jeśli mamy mniej zamówień)
        let recentOrders = Array(sortedOrders.prefix(100))
        let recentOrderIds = recentOrders.map { $0.id }
        
        if recentOrderIds.isEmpty {
            print("🔍 Brak zamówień do sprawdzenia")
            return
        }
        
        print("🔍 Sprawdzanie usuniętych zamówień: sprawdzam \(recentOrderIds.count) najnowszych zamówień")
        
        // Tworzymy parametry żądania - sprawdzamy wszystkie ID jednocześnie
        let requestParameters: [String: Any] = [
            "order_id": recentOrderIds.joined(separator: "|")
        ]
        
        let parameters: [String: Any] = [
            "method": "getOrders",
            "parameters": requestParameters
        ]
        
        sendRequest(parameters: parameters) { [weak self] success, responseData in
            guard let self = self else { return }
            
            if success, let responseData = responseData {
                do {
                    if let jsonObject = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
                       let status = jsonObject["status"] as? String, status == "SUCCESS" {
                        
                        // Pobieramy ID zamówień, które istnieją w Baselinker
                        let existingOrderIds: Set<String>
                        
                        if let ordersData = jsonObject["orders"] as? [[String: Any]] {
                            // Pobieramy ID zamówień, które istnieją w Baselinker
                            existingOrderIds = Set(ordersData.compactMap { orderData -> String? in
                                if let orderId = orderData["order_id"] as? String {
                                    return orderId
                                } else if let orderId = orderData["order_id"] as? Int {
                                    return String(orderId)
                                }
                                return nil
                            })
                            
                            // Znajdujemy ID zamówień, które nie istnieją już w Baselinker
                            let deletedOrderIds = Set(recentOrderIds).subtracting(existingOrderIds)
                            
                            if !deletedOrderIds.isEmpty {
                                print("🗑️ Wykryto \(deletedOrderIds.count) usuniętych zamówień: \(deletedOrderIds.joined(separator: ", "))")
                                
                                // Usuwamy zamówienia z lokalnej listy, ale zachowujemy zamówienia z bieżącego dnia
                                DispatchQueue.main.async {
                                    let calendar = Calendar.current
                                    let startOfToday = calendar.startOfDay(for: Date())
                                    
                                    let initialCount = self.orders.count
                                    self.orders.removeAll { order in
                                        // Usuwamy tylko jeśli ID jest na liście usuniętych I zamówienie nie jest z dzisiejszego dnia
                                        return deletedOrderIds.contains(order.id) && order.date < startOfToday
                                    }
                                    let removedCount = initialCount - self.orders.count
                                    print("✅ Usunięto \(removedCount) zamówień z lokalnej listy (zachowano zamówienia z dzisiejszego dnia)")
                                }
                            } else {
                                print("✅ Wszystkie sprawdzane zamówienia istnieją w Baselinker")
                            }
                        } else {
                            // Brak zamówień w odpowiedzi - wszystkie zostały usunięte
                            print("🗑️ Wszystkie sprawdzane zamówienia zostały usunięte w Baselinker")
                            
                            // Usuwamy wszystkie sprawdzane zamówienia z lokalnej listy, ale zachowujemy zamówienia z bieżącego dnia
                            DispatchQueue.main.async {
                                let calendar = Calendar.current
                                let startOfToday = calendar.startOfDay(for: Date())
                                
                                let initialCount = self.orders.count
                                self.orders.removeAll { order in
                                    // Usuwamy tylko jeśli ID jest na liście sprawdzanych I zamówienie nie jest z dzisiejszego dnia
                                    return recentOrderIds.contains(order.id) && order.date < startOfToday
                                }
                                let removedCount = initialCount - self.orders.count
                                print("✅ Usunięto \(removedCount) zamówień z lokalnej listy (zachowano zamówienia z dzisiejszego dnia)")
                            }
                        }
                    } else {
                        // Próbujemy pobrać komunikat błędu z odpowiedzi
                        let errorMessage: String
                        do {
                            if let errorJson = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
                               let errorMsg = errorJson["error_message"] as? String {
                                errorMessage = errorMsg
                            } else {
                                errorMessage = "Nieznany błąd"
                            }
                        } catch {
                            errorMessage = "Nieznany błąd: \(error.localizedDescription)"
                        }
                        print("❌ Błąd API podczas sprawdzania zamówień: \(errorMessage)")
                    }
                } catch {
                    print("❌ Błąd podczas przetwarzania odpowiedzi: \(error.localizedDescription)")
                }
            } else {
                print("❌ Błąd połączenia z API podczas sprawdzania zamówień")
            }
        }
    }
} 