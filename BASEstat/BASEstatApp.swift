//
//  BASEstatApp.swift
//  BASEstat
//
//  Created by Marcin Jaroszewicz on 15/03/2025.
//

import SwiftUI
import BackgroundTasks
#if os(iOS)
import UIKit
#endif

@main
struct BASEstatApp: App {
    @StateObject private var baselinkerService = BaselinkerService()
    @StateObject private var notificationService = NotificationService()
    
    init() {
        // Inicjalizacja domyślnych wartości dla UserDefaults
        self.initializeDefaultSettings()
        
        // Rejestracja zadań w tle
        registerBackgroundTasks()
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
        if UserDefaults.standard.object(forKey: "backgroundRefreshEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "backgroundRefreshEnabled")
        }
        if UserDefaults.standard.object(forKey: "backgroundRefreshInterval") == nil {
            UserDefaults.standard.set(2, forKey: "backgroundRefreshInterval") // 2 minuty
        }
    }
    
    private func registerBackgroundTasks() {
        #if os(iOS)
        // Rejestracja zadania odświeżania aplikacji w tle
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.basestat.refresh", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        // Planowanie pierwszego zadania w tle
        scheduleAppRefresh()
        #endif
    }
    
    #if os(iOS)
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Upewnij się, że zadanie zostanie anulowane, jeśli aplikacja zostanie zamknięta
        let backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            task.setTaskCompleted(success: false)
        }
        
        // Dodaj zadanie zakończenia, które zostanie wywołane, gdy zadanie zostanie zakończone lub anulowane
        task.expirationHandler = {
            // Anuluj wszystkie operacje związane z zadaniem
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        
        // Sprawdź, czy odświeżanie w tle jest włączone
        let backgroundRefreshEnabled = UserDefaults.standard.bool(forKey: "backgroundRefreshEnabled")
        if !backgroundRefreshEnabled {
            task.setTaskCompleted(success: true)
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            return
        }
        
        // Wykonaj zadania w tle
        baselinkerService.fetchOrdersInBackground { success in
            // Pobierz dane produktów z magazynu
            self.baselinkerService.fetchInventoriesInBackground { success in
                // Oblicz podsumowanie dzienne
                self.baselinkerService.calculateDailySummary()
                
                // Sprawdź nowe zamówienia
                self.notificationService.checkForNewOrdersInBackground(baselinkerService: self.baselinkerService)
                
                // Zaplanuj kolejne zadanie
                self.scheduleAppRefresh()
                
                // Oznacz zadanie jako zakończone
                task.setTaskCompleted(success: success)
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
            }
        }
    }
    
    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.basestat.refresh")
        
        // Pobierz interwał odświeżania z UserDefaults (w minutach)
        let intervalMinutes = UserDefaults.standard.integer(forKey: "backgroundRefreshInterval")
        // Konwertuj minuty na sekundy
        let intervalSeconds = max(60, intervalMinutes * 60) // Minimum 60 sekund
        request.earliestBeginDate = Date(timeIntervalSinceNow: TimeInterval(intervalSeconds))
        
        do {
            // Anuluj wszystkie poprzednie zaplanowane zadania
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.basestat.refresh")
            
            // Dodaj nowe zadanie
            try BGTaskScheduler.shared.submit(request)
            print("✅ Zaplanowano zadanie odświeżania w tle za \(intervalMinutes) minut (\(intervalSeconds) sekund)")
        } catch {
            print("❌ Nie udało się zaplanować zadania odświeżania w tle: \(error.localizedDescription)")
        }
    }
    #endif
    
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
                    
                    #if os(iOS)
                    // Zaplanuj zadanie odświeżania w tle
                    scheduleAppRefresh()
                    #endif
                }
            
            // Nowy design aplikacji - zakomentowany do czasu pełnej implementacji
            // MainView()
        }
    }
}
