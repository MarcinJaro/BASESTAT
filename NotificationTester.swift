import Foundation
import UserNotifications

// Prosty skrypt do testowania powiadomień
class NotificationTester {
    static func testNotifications() {
        print("🧪 Testowanie systemu powiadomień...")
        
        // Najpierw prośba o pozwolenie na powiadomienia
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Pozwolenie na powiadomienia zostało udzielone")
                
                // Sprawdź szczegóły ustawień powiadomień
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    DispatchQueue.main.async {
                        print("🔔 Status powiadomień: \(settings.authorizationStatus.rawValue)")
                        print("🔔 Status powiadomień na ekranie blokady: \(settings.lockScreenSetting.rawValue)")
                        print("🔔 Status powiadomień w centrum powiadomień: \(settings.notificationCenterSetting.rawValue)")
                        print("🔔 Status dźwięków powiadomień: \(settings.soundSetting.rawValue)")
                        print("🔔 Status odznak powiadomień: \(settings.badgeSetting.rawValue)")
                        
                        if settings.authorizationStatus == .authorized {
                            // Wyślij testowe powiadomienie
                            self.sendTestNotification()
                        } else {
                            print("❌ Powiadomienia nie są autoryzowane")
                        }
                    }
                }
            } else if let error = error {
                print("❌ Błąd podczas prośby o pozwolenie na powiadomienia: \(error.localizedDescription)")
            } else {
                print("❌ Użytkownik nie udzielił pozwolenia na powiadomienia")
            }
        }
    }
    
    static func sendTestNotification() {
        // Tworzymy treść powiadomienia
        let content = UNMutableNotificationContent()
        content.title = "Test powiadomienia BASEstat"
        content.body = "To jest testowe powiadomienie z aplikacji BASEstat 💰"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("cash_register.wav"))
        
        // Dodajemy dane użytkownika
        content.userInfo = [
            "testId": "123",
            "testValue": 199.99
        ]
        
        // Ustawiamy trigger do natychmiastowego wysłania
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Tworzymy żądanie powiadomienia
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        // Wysyłamy powiadomienie
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Błąd podczas wysyłania powiadomienia: \(error.localizedDescription)")
            } else {
                print("✅ Powiadomienie zostało pomyślnie wysłane")
                
                // Sprawdź oczekujące i dostarczone powiadomienia
                self.checkPendingNotifications()
            }
        }
    }
    
    static func checkPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("📋 Liczba oczekujących powiadomień: \(requests.count)")
            
            UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
                print("📬 Liczba dostarczonych powiadomień: \(notifications.count)")
                
                // Dla każdego dostarczonego powiadomienia wypisz informacje
                if !notifications.isEmpty {
                    print("📬 Lista dostarczonych powiadomień:")
                    for (index, notification) in notifications.enumerated() {
                        print("  \(index + 1). \(notification.request.content.title)")
                    }
                }
            }
        }
    }
}

// Wywołaj test powiadomień
print("🚀 Uruchamiam tester powiadomień...")
NotificationTester.testNotifications()

// Utrzymaj działanie programu przez 10 sekund, aby mieć czas na przetworzenie powiadomień
print("⏳ Oczekiwanie na zakończenie testów...")
Thread.sleep(forTimeInterval: 10)
print("✅ Testy zakończone!") 