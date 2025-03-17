//
//  BASEstatApp.swift
//  BASEstat
//
//  Created by Marcin Jaroszewicz on 15/03/2025.
//

import SwiftUI
import UserNotifications

@main
struct BASEstatApp: App {
    @StateObject private var baselinkerService = BaselinkerService()
    @StateObject private var notificationService = NotificationService()
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView(baselinkerService: baselinkerService)
                .environmentObject(baselinkerService)
                .environmentObject(notificationService)
                .onAppear {
                    // Przypisz serwis powiadomień do AppDelegate
                    appDelegate.notificationService = notificationService
                    
                    // Pobierz dane przy starcie aplikacji
                    baselinkerService.fetchOrders()
                    
                    // Pobierz dane produktów z magazynu
                    baselinkerService.fetchInventories()
                    
                    /* 
                    // Test powiadomień - zakomentowane, aby wyłączyć automatyczne testy powiadomień
                    print("🔔 Uruchamiam test powiadomień...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        print("⏰ Czas na test powiadomień...")
                        notificationService.testNotifications()
                    }
                    */
                    
                    // Uruchamiamy automatyczne odświeżanie podsumowania dziennego
                    baselinkerService.startDailySummaryAutoRefresh()
                    
                    // Uruchamiamy automatyczne pobieranie nowych zamówień co 30 sekund
                    baselinkerService.startDeltaUpdateAutoRefresh()
                }
            
            // Nowy design aplikacji - zakomentowany do czasu pełnej implementacji
            // MainView()
        }
    }
}

// Klasa delegata aplikacji do obsługi powiadomień
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    // Instancja serwisu powiadomień, dostępna publicznie dla innych komponentów
    var notificationService: NotificationService?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Ustaw delegata dla powiadomień
        UNUserNotificationCenter.current().delegate = self
        
        // Inicjalizacja domyślnych wartości dla ustawień powiadomień
        // przy pierwszym uruchomieniu aplikacji
        if UserDefaults.standard.object(forKey: "showNotificationBanners") == nil {
            UserDefaults.standard.set(true, forKey: "showNotificationBanners")
        }
        if UserDefaults.standard.object(forKey: "playNotificationSound") == nil {
            UserDefaults.standard.set(true, forKey: "playNotificationSound")
        }
        if UserDefaults.standard.object(forKey: "showNotificationBadges") == nil {
            UserDefaults.standard.set(true, forKey: "showNotificationBadges")
        }
        
        // Rejestracja kategorii powiadomień
        registerNotificationCategories()
        
        // Poproś o pozwolenie na powiadomienia przy starcie
        requestNotificationPermissions()
        
        // Inicjalizacja serwisu powiadomień
        self.notificationService = NotificationService()
        
        return true
    }
    
    // Ta metoda pozwala na wyświetlanie powiadomień, gdy aplikacja jest w trybie foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               willPresent notification: UNNotification, 
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Możliwe, że ograniczenia systemowe nie pozwalają na wyświetlanie bannerów w foreground
        // Próbujemy różnych kombinacji opcji prezentacji
        
        // Wymuszamy wyświetlenie powiadomienia zawsze z maksymalnymi opcjami
        if #available(iOS 14.0, *) {
            // iOS 14+ używa nowych opcji
            completionHandler([.banner, .list, .sound, .badge])
            print("📱 iOS 14+: Powiadomienie z opcjami banner, list, sound, badge")
        } else {
            // iOS 13 i starsze
            completionHandler([.alert, .sound, .badge])
            print("📱 iOS <14: Powiadomienie z opcjami alert, sound, badge")
        }
        
        print("📲 Powiadomienie wyświetlone w trybie foreground: \(notification.request.content.title)")
        
        // Dodatkowo, wyświetlimy informację o powiadomieniu na konsoli
        dump(notification)
    }
    
    // Ta metoda jest wywoływana, gdy użytkownik reaguje na powiadomienie
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               didReceive response: UNNotificationResponse, 
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        // Obsługa reakcji użytkownika na powiadomienie
        print("👆 Użytkownik kliknął powiadomienie: \(response.notification.request.content.title)")
        
        // Tutaj można dodać kod do obsługi kliknięcia w powiadomienie, np. przejście do konkretnego widoku
        
        completionHandler()
    }
    
    // Funkcja rejestrująca kategorie powiadomień
    private func registerNotificationCategories() {
        // Kategoria dla krytycznych powiadomień
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
        
        let criticalCategory = UNNotificationCategory(
            identifier: "CRITICAL_CATEGORY",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Kategoria dla nowych zamówień
        let viewOrderAction = UNNotificationAction(
            identifier: "VIEW_ORDER_ACTION",
            title: "Zobacz zamówienie",
            options: .foreground
        )
        
        let orderCategory = UNNotificationCategory(
            identifier: "ORDER_CATEGORY",
            actions: [viewOrderAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Rejestracja wszystkich kategorii
        UNUserNotificationCenter.current().setNotificationCategories([criticalCategory, orderCategory])
    }
    
    // Funkcja prosząca o uprawnienia do powiadomień
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Uprawnienia do powiadomień zostały przyznane przy starcie aplikacji")
            } else if let error = error {
                print("❌ Błąd przy prośbie o uprawnień do powiadomień: \(error.localizedDescription)")
            } else {
                print("❌ Użytkownik odmówił uprawnień do powiadomień")
            }
        }
    }
}
