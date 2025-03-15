import Foundation
import UserNotifications

class NotificationManager: ObservableObject {
    init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if let error = error {
                print("Błąd autoryzacji powiadomień: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleNotification(for order: Order) {
        let content = UNMutableNotificationContent()
        content.title = "Nowe zamówienie!"
        content.body = "Otrzymano nowe zamówienie #\(order.orderNumber) od \(order.customerName)"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
} 