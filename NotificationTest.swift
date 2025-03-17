import SwiftUI
import UserNotifications
import UIKit

@main
struct NotificationTestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            NotificationTestView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               willPresent notification: UNNotification, 
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
        print("📲 Powiadomienie w foreground: \(notification.request.content.title)")
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               didReceive response: UNNotificationResponse, 
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        print("👆 Kliknięto powiadomienie: \(response.notification.request.content.title)")
        completionHandler()
    }
}

struct NotificationTestView: View {
    @State private var deviceInfo = ""
    @State private var showBanner = false
    @State private var bannerMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Test Powiadomień")
                .font(.largeTitle)
                .padding()
            
            if showBanner {
                Text(bannerMessage)
                    .padding()
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .cornerRadius(8)
            }
            
            Text(deviceInfo)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            
            Button("Sprawdź uprawnienia") {
                checkPermissions()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Wyślij powiadomienie testowe") {
                sendTestNotification()
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Wyślij powiadomienie krytyczne") {
                sendCriticalNotification()
            }
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Symuluj banner") {
                showFakeBanner("To jest symulowany banner")
            }
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .onAppear {
            getDeviceInfo()
        }
    }
    
    func getDeviceInfo() {
        let device = UIDevice.current
        let systemVersion = device.systemVersion
        let model = device.model
        
        deviceInfo = "Urządzenie: \(model)\niOS: \(systemVersion)"
    }
    
    func checkPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    deviceInfo = "✅ Powiadomienia WŁĄCZONE\nAlert: \(settings.alertSetting.rawValue)\nBanner: \(settings.alertSetting.rawValue)\nDźwięk: \(settings.soundSetting.rawValue)"
                    showFakeBanner("Powiadomienia są włączone")
                } else {
                    deviceInfo = "❌ Powiadomienia WYŁĄCZONE\nStatus: \(settings.authorizationStatus.rawValue)"
                    
                    // Poproś o uprawnienia
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        DispatchQueue.main.async {
                            if granted {
                                deviceInfo = "✅ Uprawnienia przyznane"
                                showFakeBanner("Uprawnienia zostały przyznane")
                            } else {
                                deviceInfo = "❌ Uprawnienia odrzucone"
                                showFakeBanner("Uprawnienia zostały odrzucone")
                            }
                        }
                    }
                }
            }
        }
    }
    
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test powiadomienia"
        content.subtitle = "Powiadomienie testowe"
        content.body = "To jest test powiadomień na urządzeniu 💰"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("cash_register.wav"))
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    deviceInfo = "❌ Błąd: \(error.localizedDescription)"
                    showFakeBanner("Błąd powiadomienia")
                } else {
                    deviceInfo = "✅ Powiadomienie wysłane"
                    showFakeBanner("Powiadomienie zostało wysłane")
                }
            }
        }
    }
    
    func sendCriticalNotification() {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ POWIADOMIENIE KRYTYCZNE"
        content.subtitle = "Wymagana natychmiastowa akcja"
        content.body = "To jest krytyczny test powiadomień na urządzeniu"
        content.sound = UNNotificationSound.defaultCritical
        content.categoryIdentifier = "CRITICAL_CATEGORY"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        // Rejestracja kategorii
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ACTION",
            title: "Pokaż",
            options: .foreground
        )
        
        let category = UNNotificationCategory(
            identifier: "CRITICAL_CATEGORY",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    deviceInfo = "❌ Błąd: \(error.localizedDescription)"
                    showFakeBanner("Błąd powiadomienia krytycznego")
                } else {
                    deviceInfo = "✅ Powiadomienie krytyczne wysłane"
                    showFakeBanner("Powiadomienie krytyczne zostało wysłane")
                }
            }
        }
    }
    
    func showFakeBanner(_ message: String) {
        withAnimation {
            bannerMessage = message
            showBanner = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showBanner = false
            }
        }
    }
} 