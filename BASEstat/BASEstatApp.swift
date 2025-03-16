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
    
    var body: some Scene {
        WindowGroup {
            ContentView(baselinkerService: baselinkerService)
                .environmentObject(baselinkerService)
                .environmentObject(notificationService)
                .onAppear {
                    // Pobierz dane przy starcie aplikacji
                    baselinkerService.fetchOrders()
                    
                    // Rozpocznij monitorowanie nowych zamówień
                    notificationService.startMonitoringForNewOrders(baselinkerService: baselinkerService)
                }
            
            // Nowy design aplikacji - zakomentowany do czasu pełnej implementacji
            // MainView()
        }
    }
}
