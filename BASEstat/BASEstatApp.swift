//
//  BASEstatApp.swift
//  BASEstat
//
//  Created by Marcin Jaroszewicz on 15/03/2025.
//

import SwiftUI

@main
struct BASEstatApp: App {
    @StateObject private var baselinkerService = BaselinkerService()
    @StateObject private var notificationService = NotificationService()
    
    init() {
        // Inicjalizacja domyślnych wartości dla UserDefaults
        self.initializeDefaultSettings()
    }
    
    private func initializeDefaultSettings() {
        // Ustawienie domyślnych wartości dla ustawień powiadomień przy pierwszym uruchomieniu
        if UserDefaults.standard.object(forKey: "notificationsEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "notificationsEnabled")
        }
        if UserDefaults.standard.object(forKey: "newOrdersNotificationsEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "newOrdersNotificationsEnabled")
        }
        if UserDefaults.standard.object(forKey: "statusChangeNotificationsEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "statusChangeNotificationsEnabled")
        }
        if UserDefaults.standard.object(forKey: "lowStockNotificationsEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "lowStockNotificationsEnabled")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(baselinkerService: baselinkerService)
                .environmentObject(baselinkerService)
                .environmentObject(notificationService)
                .onAppear {
                    // Pobierz dane przy starcie aplikacji
                    baselinkerService.fetchOrders()
                    
                    // Pobierz dane produktów z magazynu
                    baselinkerService.fetchInventories()
                    
                    // Rozpocznij monitorowanie nowych zamówień
                    notificationService.startMonitoringForNewOrders(baselinkerService: baselinkerService)
                    
                    // Uruchamiamy automatyczne odświeżanie podsumowania dziennego
                    baselinkerService.startDailySummaryAutoRefresh()
                }
            
            // Nowy design aplikacji - zakomentowany do czasu pełnej implementacji
            // MainView()
        }
    }
}
