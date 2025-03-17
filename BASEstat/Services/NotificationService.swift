//
//  NotificationService.swift
//  BASEstat
//
//  Created by Marcin Jaroszewicz on 15/03/2025.
//

import Foundation
import UserNotifications
import Combine

// Definiujemy alias dla naszego typu Notification, aby uniknąć konfliktu z typem UserNotifications.Notification
typealias AppNotification = BASEstat.Notification

class NotificationService: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Wczytaj zapisane powiadomienia
        loadNotifications()
        
        // Obserwuj zmiany w powiadomieniach
        $notifications
            .map { notifications in
                notifications.filter { !$0.isRead }.count
            }
            .assign(to: \.unreadCount, on: self)
            .store(in: &cancellables)
        
        // Poproś o pozwolenie na powiadomienia
        requestNotificationPermission()
    }
    
    private func loadNotifications() {
        // W rzeczywistej aplikacji, wczytaj powiadomienia z UserDefaults lub innego źródła
        // Na potrzeby przykładu używamy przykładowych danych
        self.notifications = AppNotification.sample()
        updateUnreadCount()
    }
    
    private func saveNotifications() {
        // W rzeczywistej aplikacji, zapisz powiadomienia w UserDefaults lub innym źródle
        updateUnreadCount()
    }
    
    private func updateUnreadCount() {
        self.unreadCount = notifications.filter { !$0.isRead }.count
    }
    
    func addNotification(_ notification: AppNotification) {
        DispatchQueue.main.async {
            self.notifications.insert(notification, at: 0)
            self.saveNotifications()
            
            // Wyślij powiadomienie systemowe
            self.sendSystemNotification(notification)
        }
    }
    
    func markAsRead(_ notification: AppNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
            saveNotifications()
        }
    }
    
    func markAllAsRead() {
        for i in 0..<notifications.count {
            notifications[i].isRead = true
        }
        saveNotifications()
    }
    
    func removeNotification(_ notification: AppNotification) {
        notifications.removeAll { $0.id == notification.id }
        saveNotifications()
    }
    
    func clearAll() {
        notifications.removeAll()
        saveNotifications()
    }
    
    // MARK: - System Notifications
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Pozwolenie na powiadomienia zostało udzielone")
            } else if let error = error {
                print("Błąd podczas prośby o pozwolenie na powiadomienia: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendSystemNotification(_ notification: AppNotification) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message
        
        // Użyj dźwięku kasy fiskalnej dla powiadomień o nowych zamówieniach
        if notification.type == .newOrder {
            // W prawdziwej aplikacji użyj pliku dźwiękowego kasy fiskalnej
            // content.sound = UNNotificationSound(named: UNNotificationSoundName("cash-register.wav"))
            content.sound = UNNotificationSound.default
        } else {
            content.sound = UNNotificationSound.default
        }
        
        // Dodaj identyfikator zamówienia i inne informacje jako dane użytkownika
        var userInfo: [String: Any] = [:]
        if let orderId = notification.relatedOrderId {
            userInfo["orderId"] = orderId
        }
        
        // Dodaj informacje o kwocie zamówienia, liczbie dziennych zamówień i sumie, jeśli istnieją
        if let orderAmount = notification.orderAmount {
            userInfo["orderAmount"] = orderAmount
        }
        if let dailyOrderCount = notification.dailyOrderCount {
            userInfo["dailyOrderCount"] = dailyOrderCount
        }
        if let dailyOrderTotal = notification.dailyOrderTotal {
            userInfo["dailyOrderTotal"] = dailyOrderTotal
        }
        
        // Ustaw dane użytkownika tylko jeśli nie są puste
        if !userInfo.isEmpty {
            content.userInfo = userInfo
        }
        
        // Wyślij powiadomienie natychmiast
        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Błąd podczas wysyłania powiadomienia: \(error.localizedDescription)")
            } else {
                print("Powiadomienie zostało pomyślnie wysłane: \(notification.title)")
            }
        }
    }
    
    // MARK: - Monitoring
    
    func startMonitoringForNewOrders(baselinkerService: BaselinkerService) {
        // W rzeczywistej aplikacji, ustaw timer do okresowego sprawdzania nowych zamówień
        // Na potrzeby przykładu, symulujemy otrzymanie nowego zamówienia po 5 sekundach
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            // Pobierz podsumowanie z dzisiejszego dnia
            let summary = baselinkerService.getTodaySummary()
            let orderAmount = 249.99
            
            // Utwórz komunikat zawierający informacje o zamówieniu i dzienną statystykę
            let message = "Otrzymano nowe zamówienie #54321 - \(String(format: "%.2f", orderAmount)) zł\nDzisiaj: \(summary.orderCount) zamówień, \(String(format: "%.2f", summary.totalValue)) zł"
            
            let newNotification = AppNotification(
                title: "Nowe zamówienie",
                message: message,
                date: Date(),
                type: .newOrder,
                relatedOrderId: "54321",
                orderAmount: orderAmount,
                dailyOrderCount: summary.orderCount,
                dailyOrderTotal: summary.totalValue
            )
            self.addNotification(newNotification)
            
            // Wypisz informacje debugowania
            print("💰 Utworzono powiadomienie o nowym zamówieniu: \(orderAmount) zł")
            print("📊 Statystyki dzienne: \(summary.orderCount) zamówień, \(summary.totalValue) zł")
        }
    }
    
    // MARK: - Testing Notifications
    
    func testNotifications() {
        print("🧪 Testowanie systemu powiadomień...")
        
        // Najpierw sprawdzamy, czy mamy pozwolenie na powiadomienia
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                print("🔔 Status powiadomień: \(settings.authorizationStatus.rawValue)")
                
                if settings.authorizationStatus == .authorized {
                    print("✅ Powiadomienia są autoryzowane")
                    
                    // Tworzymy testowe powiadomienie
                    let testNotification = Notification(
                        title: "Test powiadomienia", 
                        message: "To jest testowe powiadomienie z kwotą 100.00 zł",
                        date: Date(),
                        type: .newOrder,
                        orderAmount: 100.00,
                        dailyOrderCount: 5,
                        dailyOrderTotal: 1500.00
                    )
                    
                    // Dodajemy je do serwisu
                    self.addNotification(testNotification)
                    
                    // Wysyłamy bezpośrednio powiadomienie systemowe
                    let content = UNMutableNotificationContent()
                    content.title = "Testowe powiadomienie"
                    content.body = "To jest bezpośredni test powiadomienia systemowego"
                    content.sound = UNNotificationSound.default
                    
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                    let request = UNNotificationRequest(
                        identifier: UUID().uuidString,
                        content: content,
                        trigger: trigger
                    )
                    
                    UNUserNotificationCenter.current().add(request) { error in
                        if let error = error {
                            print("❌ Błąd bezpośredniego powiadomienia: \(error.localizedDescription)")
                        } else {
                            print("✅ Bezpośrednie powiadomienie wysłane pomyślnie")
                        }
                    }
                    
                } else {
                    print("⚠️ Powiadomienia nie są autoryzowane, próbuję uzyskać pozwolenie...")
                    self.requestNotificationPermission()
                    
                    // Po uzyskaniu pozwolenia próbujemy ponownie
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.testNotifications()
                    }
                }
            }
        }
    }
} 