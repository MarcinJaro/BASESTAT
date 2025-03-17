import SwiftUI
import UserNotifications

@main
struct NotificationTestApp: App {
    @StateObject private var notificationManager = NotificationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notificationManager)
        }
    }
}

class NotificationManager: ObservableObject {
    @Published var notificationStatus: String = "Nieznany"
    @Published var testResults: [String] = []
    
    init() {
        checkNotificationStatus()
    }
    
    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationStatus = "Status: \(settings.authorizationStatus.rawValue)"
                self.addResult("🔔 Status powiadomień: \(settings.authorizationStatus.rawValue)")
            }
        }
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.addResult("✅ Pozwolenie uzyskane")
                    self.checkNotificationStatus()
                } else if let error = error {
                    self.addResult("❌ Błąd: \(error.localizedDescription)")
                } else {
                    self.addResult("❌ Odmowa pozwolenia")
                }
            }
        }
    }
    
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test BASEstat"
        content.body = "To jest testowe powiadomienie z aplikacji BASEstat 💰"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("cash_register.wav"))
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.addResult("❌ Błąd powiadomienia: \(error.localizedDescription)")
                } else {
                    self.addResult("✅ Powiadomienie wysłane")
                }
            }
        }
    }
    
    func clearResults() {
        testResults.removeAll()
    }
    
    private func addResult(_ message: String) {
        testResults.insert(message, at: 0)
    }
}

struct ContentView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Tester Powiadomień BASEstat")
                    .font(.title)
                    .padding()
                
                Text(notificationManager.notificationStatus)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                HStack(spacing: 20) {
                    Button("Sprawdź status") {
                        notificationManager.checkNotificationStatus()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Poproś o pozwolenie") {
                        notificationManager.requestPermission()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Wyślij test") {
                        notificationManager.sendTestNotification()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                
                Divider()
                
                Text("Wyniki testów")
                    .font(.headline)
                
                List {
                    ForEach(notificationManager.testResults, id: \.self) { result in
                        Text(result)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                
                Button("Wyczyść wyniki") {
                    notificationManager.clearResults()
                }
                .padding()
            }
            .navigationTitle("Tester Powiadomień")
        }
    }
} 