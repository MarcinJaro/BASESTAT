//
//  NotificationService.swift
//  BASEstat
//
//  Created by Marcin Jaroszewicz on 15/03/2025.
//

import Foundation
import UserNotifications
import Combine
import UIKit

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
        
        // Użyj dźwięku kasy fiskalnej dla wszystkich typów powiadomień
        content.sound = UNNotificationSound(named: UNNotificationSoundName("cash_register.wav"))
        
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
                print("🔔 Status powiadomień alert: \(settings.alertSetting.rawValue)")
                print("🔔 Status powiadomień banner: \(settings.alertSetting.rawValue)")
                print("🔔 Status powiadomień dźwięk: \(settings.soundSetting.rawValue)")
                print("🔔 Status powiadomień badge: \(settings.badgeSetting.rawValue)")
                print("🔔 Status powiadomień na ekranie blokady: \(settings.lockScreenSetting.rawValue)")
                
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
                    
                    // Wysyłamy powiadomienia z różnymi opóźnieniami, aby zwiększyć szansę na wyświetlenie
                    self.sendTestNotificationWithDelay(1, title: "Test #1: Natychmiastowy")
                    
                    // Opóźnij drugie powiadomienie, aby zwiększyć szansę na powodzenie
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.sendTestNotificationWithDelay(0.5, title: "Test #2: Po 3 sekundach")
                    }
                    
                    // Opóźnij trzecie powiadomienie, aby zwiększyć szansę na powodzenie
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                        self.sendTestNotificationWithDelay(0.5, title: "Test #3: Po 6 sekundach")
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
    
    private func sendTestNotificationWithDelay(_ seconds: TimeInterval, title: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            let content = UNMutableNotificationContent()
            content.title = title
            content.subtitle = "⚠️ Test powiadomień BASEstat"
            content.body = "💰 To jest TESTOWE POWIADOMIENIE. \nUważaj! Kasa fiskalna dzwoni! 💰"
            content.sound = UNNotificationSound(named: UNNotificationSoundName("cash_register.wav"))
            content.badge = NSNumber(value: 1)
            
            // Zwiększ priorytet powiadomienia
            content.threadIdentifier = "critical-test"
            content.categoryIdentifier = "CRITICAL_CATEGORY"
            
            // Dodaj losowy identyfikator, aby uniknąć nadpisywania powiadomień
            let uniqueId = UUID().uuidString
            content.userInfo = [
                "testId": uniqueId,
                "priority": "high",
                "critical": true
            ]
            
            // Ustaw trigger z bardzo krótkim opóźnieniem
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(
                identifier: uniqueId,
                content: content,
                trigger: trigger
            )
            
            // Próba zdefiniowania kategorii powiadomień z akcjami
            let viewAction = UNNotificationAction(
                identifier: "VIEW_ACTION",
                title: "Pokaż szczegóły",
                options: .foreground
            )
            
            let dismissAction = UNNotificationAction(
                identifier: "DISMISS_ACTION",
                title: "Zamknij",
                options: .destructive
            )
            
            let category = UNNotificationCategory(
                identifier: "CRITICAL_CATEGORY",
                actions: [viewAction, dismissAction],
                intentIdentifiers: [],
                options: [.customDismissAction]
            )
            
            // Rejestracja kategorii
            UNUserNotificationCenter.current().setNotificationCategories([category])
            
            print("📤 Wysyłanie powiadomienia testowego: \(title)")
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Błąd powiadomienia [\(title)]: \(error.localizedDescription)")
                    
                    // Tylko w przypadku błędu pokazujemy alert w aplikacji
                    DispatchQueue.main.async {
                        self.showInAppAlert(title: "Błąd powiadomienia", message: error.localizedDescription)
                    }
                } else {
                    print("✅ Powiadomienie [\(title)] wysłane pomyślnie")
                    
                    // Sprawdź liczbę oczekujących powiadomień
                    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                        print("📋 Liczba oczekujących powiadomień: \(requests.count)")
                    }
                    
                    // Wymuś zaktualizowanie odznaki aplikacji
                    DispatchQueue.main.async {
                        UIApplication.shared.applicationIconBadgeNumber = 1
                    }
                }
            }
        }
    }
    
    // Wyświetla alert w aplikacji jako alternatywny sposób pokazania informacji
    private func showInAppAlert(title: String, message: String) {
        // Implementacja zależna od struktury aplikacji
        // Na przykład przez NotificationCenter:
        DispatchQueue.main.async {
            let userInfo: [String: Any] = ["title": title, "message": message]
            NotificationCenter.default.post(name: NSNotification.Name("ShowInAppAlert"), object: nil, userInfo: userInfo)
        }
    }
} 