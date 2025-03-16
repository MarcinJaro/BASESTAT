//
//  NotificationService.swift
//  BASEstat
//
//  Created by Marcin Jaroszewicz on 15/03/2025.
//

import Foundation
import UserNotifications
import Combine

class NotificationService: ObservableObject {
    @Published var notifications: [Notification] = []
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
        self.notifications = Notification.sample()
        updateUnreadCount()
    }
    
    private func saveNotifications() {
        // W rzeczywistej aplikacji, zapisz powiadomienia w UserDefaults lub innym źródle
        updateUnreadCount()
    }
    
    private func updateUnreadCount() {
        self.unreadCount = notifications.filter { !$0.isRead }.count
    }
    
    func addNotification(_ notification: Notification) {
        DispatchQueue.main.async {
            self.notifications.insert(notification, at: 0)
            self.saveNotifications()
            
            // Wyślij powiadomienie systemowe
            self.sendSystemNotification(notification)
        }
    }
    
    func markAsRead(_ notification: Notification) {
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
    
    func removeNotification(_ notification: Notification) {
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
    
    private func sendSystemNotification(_ notification: Notification) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message
        content.sound = UNNotificationSound.default
        
        // Dodaj identyfikator zamówienia jako dane użytkownika, jeśli istnieje
        if let orderId = notification.relatedOrderId {
            content.userInfo = ["orderId": orderId]
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
            }
        }
    }
    
    // MARK: - Monitoring
    
    func startMonitoringForNewOrders(baselinkerService: BaselinkerService) {
        // W rzeczywistej aplikacji, ustaw timer do okresowego sprawdzania nowych zamówień
        // Na potrzeby przykładu, symulujemy otrzymanie nowego zamówienia po 5 sekundach
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            let newNotification = Notification(
                title: "Nowe zamówienie",
                message: "Otrzymano nowe zamówienie #54321",
                date: Date(),
                type: .newOrder,
                relatedOrderId: "54321"
            )
            self.addNotification(newNotification)
        }
    }
} 