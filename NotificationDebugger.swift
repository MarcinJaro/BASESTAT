import SwiftUI
import UserNotifications

struct NotificationDebuggerApp: App {
    @StateObject private var notificationDebugger = NotificationDebugger()
    
    var body: some Scene {
        WindowGroup {
            NotificationDebuggerView()
                .environmentObject(notificationDebugger)
        }
    }
}

class NotificationDebugger: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var logs: [String] = []
    @Published var authorizationStatus = "Nieznany"
    
    override init() {
        super.init()
        
        // Ustaw delegata dla centrum powiadomień
        UNUserNotificationCenter.current().delegate = self
        
        addLog("📱 Inicjalizacja NotificationDebugger")
        checkPermissions()
    }
    
    func addLog(_ message: String) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            self.logs.insert("[\(timestamp)] \(message)", at: 0)
            print("📋 \(message)")
        }
    }
    
    func checkPermissions() {
        addLog("🔍 Sprawdzanie uprawnień powiadomień...")
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = self.describeAuthorizationStatus(settings.authorizationStatus)
                
                self.addLog("🔔 Status uprawnień: \(self.authorizationStatus)")
                self.addLog("🔔 Alert: \(self.describeSettingStatus(settings.alertSetting))")
                self.addLog("🔔 Dźwięk: \(self.describeSettingStatus(settings.soundSetting))")
                self.addLog("🔔 Badge: \(self.describeSettingStatus(settings.badgeSetting))")
                self.addLog("🔔 Ekran blokady: \(self.describeSettingStatus(settings.lockScreenSetting))")
                
                if settings.authorizationStatus != .authorized {
                    self.addLog("⚠️ Brak wymaganych uprawnień!")
                }
            }
        }
    }
    
    func requestPermissions() {
        addLog("📝 Prośba o uprawnienia powiadomień...")
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    self.addLog("✅ Uprawnienia zostały przyznane")
                    self.checkPermissions()
                } else if let error = error {
                    self.addLog("❌ Błąd podczas prośby o uprawnienia: \(error.localizedDescription)")
                } else {
                    self.addLog("❌ Użytkownik odmówił uprawnień")
                }
            }
        }
    }
    
    func sendTestNotification() {
        addLog("📤 Wysyłanie testowego powiadomienia...")
        
        let content = UNMutableNotificationContent()
        content.title = "Test powiadomienia"
        content.body = "To jest testowe powiadomienie z aplikacji NotificationDebugger 💰"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("cash_register.wav"))
        
        // Dodaj dodatkowe dane
        content.userInfo = ["testId": UUID().uuidString]
        
        // Trigger natychmiastowy z minimalnym opóźnieniem
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.addLog("❌ Błąd wysyłania powiadomienia: \(error.localizedDescription)")
                } else {
                    self.addLog("✅ Powiadomienie wysłane pomyślnie")
                    
                    // Sprawdź liczbę powiadomień
                    self.checkPendingNotifications()
                }
            }
        }
    }
    
    func checkPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                self.addLog("📋 Oczekujące powiadomienia: \(requests.count)")
            }
        }
        
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            DispatchQueue.main.async {
                self.addLog("📬 Dostarczone powiadomienia: \(notifications.count)")
                
                if !notifications.isEmpty {
                    self.addLog("📬 Lista dostarczonych powiadomień:")
                    for (index, notification) in notifications.enumerated() {
                        self.addLog("  \(index + 1). \(notification.request.content.title)")
                    }
                }
            }
        }
    }
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        addLog("🧹 Wszystkie powiadomienia zostały usunięte")
    }
    
    // Metody pomocnicze do formatowania statusów
    private func describeAuthorizationStatus(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Nieustalony"
        case .denied:
            return "Odrzucony"
        case .authorized:
            return "Autoryzowany"
        case .provisional:
            return "Tymczasowy"
        case .ephemeral:
            return "Efemeryczny"
        @unknown default:
            return "Nieznany"
        }
    }
    
    private func describeSettingStatus(_ status: UNNotificationSetting) -> String {
        switch status {
        case .notSupported:
            return "Nieobsługiwany"
        case .disabled:
            return "Wyłączony"
        case .enabled:
            return "Włączony"
        @unknown default:
            return "Nieznany"
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Ta metoda pozwala wyświetlać powiadomienia w trybie foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               willPresent notification: UNNotification, 
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        addLog("📲 Powiadomienie otrzymane w foreground: \(notification.request.content.title)")
        
        // Wyświetl powiadomienie z bannerem, dźwiękiem i odznaką
        completionHandler([.banner, .sound, .badge])
    }
    
    // Ta metoda obsługuje reakcję użytkownika na powiadomienie
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               didReceive response: UNNotificationResponse, 
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        addLog("👆 Użytkownik kliknął powiadomienie: \(response.notification.request.content.title)")
        completionHandler()
    }
}

struct NotificationDebuggerView: View {
    @EnvironmentObject var notificationDebugger: NotificationDebugger
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Status uprawnień: \(notificationDebugger.authorizationStatus)")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal)
                
                HStack(spacing: 20) {
                    Button("Sprawdź uprawnienia") {
                        notificationDebugger.checkPermissions()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Poproś o uprawnienia") {
                        notificationDebugger.requestPermissions()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical)
                
                HStack(spacing: 20) {
                    Button("Wyślij test") {
                        notificationDebugger.sendTestNotification()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Sprawdź powiadomienia") {
                        notificationDebugger.checkPendingNotifications()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Wyczyść wszystkie") {
                        notificationDebugger.clearAllNotifications()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                .padding(.bottom)
                
                Divider()
                
                Text("Logi:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(notificationDebugger.logs, id: \.self) { log in
                            Text(log)
                                .font(.system(.callout, design: .monospaced))
                                .padding(.horizontal)
                                .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Debugger Powiadomień")
        }
    }
} 