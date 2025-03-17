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
                    
                    // Test powiadomień - używamy metody testowej z serwisu powiadomień
                    print("🔔 Uruchamiam test powiadomień...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        print("⏰ Czas na test powiadomień...")
                        notificationService.testNotifications()
                    }
                    
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
