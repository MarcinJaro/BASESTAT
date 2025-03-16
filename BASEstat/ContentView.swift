//
//  ContentView.swift
//  BASEstat
//
//  Created by Marcin Jaroszewicz on 15/03/2025.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var baselinkerService: BaselinkerService
    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var showingConnectionAlert = false
    @StateObject private var tabSelection: TabSelection
    
    init(baselinkerService: BaselinkerService) {
        self.baselinkerService = baselinkerService
        // Inicjalizacja StateObject musi być w init
        let initialBinding = Binding<Int>(
            get: { 0 },
            set: { _ in }
        )
        _tabSelection = StateObject(wrappedValue: TabSelection(selection: initialBinding))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                // Zakładka Dashboard
                NavigationView {
                    DashboardView(baselinkerService: baselinkerService)
                }
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }
                .tag(0)
                
                // Zakładka Zamówienia
                NavigationView {
                    OrdersView(baselinkerService: baselinkerService)
                }
                .tabItem {
                    Label("Zamówienia", systemImage: "cart")
                }
                .tag(1)
                
                // Nowa zakładka Produkty
                NavigationView {
                    InventoryProductsView(baselinkerService: baselinkerService)
                }
                .tabItem {
                    Label("Produkty", systemImage: "cube.box")
                }
                .tag(2)
                
                // Nowa zakładka Podsumowanie Dzienne
                NavigationView {
                    TodaySummaryView()
                }
                .tabItem {
                    Label("Dziś", systemImage: "clock")
                }
                .tag(3)
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                tabSelection.selection = newValue
            }
            .environmentObject(tabSelection)
            
            // Obserwujemy zmiany statusu połączenia
            .onChange(of: baselinkerService.connectionStatus) { oldValue, newValue in
                if case .failed(_) = newValue {
                    showingConnectionAlert = true
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(baselinkerService: baselinkerService)
            }
            .alert(isPresented: $showingConnectionAlert) {
                if case .failed(let message) = baselinkerService.connectionStatus {
                    return Alert(
                        title: Text("Błąd połączenia"),
                        message: Text(message),
                        dismissButton: .default(Text("OK"))
                    )
                } else {
                    return Alert(
                        title: Text("Błąd"),
                        message: Text("Wystąpił nieznany błąd"),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
    }
}

class TabSelection: ObservableObject {
    @Published var selection: Int
    
    init(selection: Binding<Int>) {
        self.selection = selection.wrappedValue
    }
    
    func switchToSettings() {
        selection = 4
    }
}

struct DashboardView: View {
    @ObservedObject var baselinkerService: BaselinkerService
    @State private var showingSettings = false
    
    var body: some View {
        Group {
            if baselinkerService.isLoading {
                VStack {
                    ProgressView("Pobieranie danych...")
                        .padding()
                    Text("Trwa synchronizacja z Baselinker")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else if let error = baselinkerService.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error)
                        .multilineTextAlignment(.center)
                    Button("Spróbuj ponownie") {
                            baselinkerService.fetchOrders()
                        }
                        .buttonStyle(.bordered)
                }
                .padding()
            } else if !baselinkerService.connectionStatus.isConnected {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.slash")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Brak połączenia z Baselinker")
                        .font(.headline)
                    Text("Przejdź do ustawień, aby skonfigurować token API")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                    Button("Przejdź do ustawień") {
                        // Implementacja przejścia do ustawień
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Nagłówek
                        HStack {
                            VStack(alignment: .leading) {
                                Text("BASEstat")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                Text("Statystyki sprzedaży")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .foregroundColor(.blue)
                        }
                        .padding()
                        
                        // Karty statystyk
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            // Rzeczywista liczba zamówień
                            StatCard(title: "Zamówienia", value: "\(baselinkerService.orders.count)", icon: "cart", color: .blue)
                            
                            // Rzeczywista wartość zamówień
                            let totalValue = baselinkerService.orders.reduce(0) { $0 + $1.totalAmount }
                            StatCard(title: "Wartość", value: String(format: "%.2f zł", totalValue), icon: "dollarsign.circle", color: .green)
                            
                            // Rzeczywista liczba nowych zamówień
                            let newOrders = baselinkerService.orders.filter { $0.status == OrderStatus.new.rawValue }.count
                            StatCard(title: "Nowe", value: "\(newOrders)", icon: "sparkles", color: .orange)
                            
                            // Rzeczywista średnia wartość zamówienia
                            if !baselinkerService.orders.isEmpty {
                                let avgValue = totalValue / Double(baselinkerService.orders.count)
                                StatCard(title: "Średnia", value: String(format: "%.2f zł", avgValue), icon: "chart.bar.fill", color: .purple)
                            } else {
                                StatCard(title: "Średnia", value: "0.00 zł", icon: "chart.bar.fill", color: .purple)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Najlepiej sprzedające się produkty
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Najlepiej sprzedające się produkty")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if baselinkerService.getTopSellingProducts(limit: 5).isEmpty {
                                Text("Brak danych o produktach")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(baselinkerService.getTopSellingProducts(limit: 5), id: \.id) { product in
                                        HStack {
                                            // Obrazek produktu
                                            ProductImageView(imageUrl: product.imageUrl)
                                                .frame(width: 40, height: 40)
                                                .cornerRadius(6)
                                                .padding(.trailing, 8)
                                                
                                            Text(product.name)
                                                .lineLimit(1)
                                            Spacer()
                                            Text("\(product.quantity) szt.")
                                                .fontWeight(.bold)
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        
                                        if product.id != baselinkerService.getTopSellingProducts(limit: 5).last?.id {
                                            Divider()
                                                .padding(.horizontal)
                                        }
                                    }
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Upewniamy się, że mamy dane produktów z magazynu
            if baselinkerService.inventoryProducts.isEmpty {
                baselinkerService.fetchInventories()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    baselinkerService.fetchOrders()
                }) {
                    if baselinkerService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(baselinkerService.isLoading || !baselinkerService.connectionStatus.isConnected)
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(baselinkerService: baselinkerService)
        }
    }
}

struct StatCard: View {
    var title: String
    var value: String
    var icon: String
    var color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct OrdersView: View {
    @ObservedObject var baselinkerService: BaselinkerService
    @State private var searchText = ""
    @State private var selectedStatusFilter: String? = nil
    @State private var showingSettings = false
    
    var filteredOrders: [Order] {
        var filtered = baselinkerService.orders
        
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.orderNumber.lowercased().contains(searchText.lowercased()) ||
                $0.customerName.lowercased().contains(searchText.lowercased())
            }
        }
        
        if let status = selectedStatusFilter {
            filtered = filtered.filter { $0.status == status }
        }
        
        return filtered
    }
    
    var body: some View {
        Group {
            if !baselinkerService.connectionStatus.isConnected {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.slash")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Brak połączenia z Baselinker")
                        .font(.headline)
                    Text("Przejdź do ustawień, aby skonfigurować token API")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                    Button("Przejdź do ustawień") {
                        // Implementacja przejścia do ustawień
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                VStack {
                    // Filtry statusów
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            StatusFilterButton(title: "Wszystkie", isSelected: selectedStatusFilter == nil) {
                                selectedStatusFilter = nil
                            }
                            
                            ForEach(OrderStatus.allCases, id: \.rawValue) { status in
                                StatusFilterButton(
                                    title: status.displayName,
                                    isSelected: selectedStatusFilter == status.rawValue
                                ) {
                                    selectedStatusFilter = status.rawValue
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if baselinkerService.isLoading {
                        Spacer()
                        VStack {
                            ProgressView("Ładowanie zamówień...")
                                .padding()
                            Text("Trwa synchronizacja z Baselinker")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else if let error = baselinkerService.error {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                            Text(error)
                                .multilineTextAlignment(.center)
                                .padding()
                            Button("Spróbuj ponownie") {
                                baselinkerService.fetchOrders()
                            }
                            .buttonStyle(.bordered)
                        }
                        Spacer()
                    } else if filteredOrders.isEmpty {
                        Spacer()
                        VStack {
                            Image(systemName: "cart")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            if baselinkerService.orders.isEmpty {
                                Text("Brak zamówień")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                    .padding()
                                Text("Kliknij przycisk odświeżania, aby pobrać zamówienia")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Brak wyników dla wybranych filtrów")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredOrders) { order in
                                NavigationLink(destination: OrderDetailView(order: order)) {
                                    OrderRow(order: order)
                                }
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
            }
        }
        .navigationTitle("Zamówienia")
        .searchable(text: $searchText, prompt: "Szukaj zamówień")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    baselinkerService.fetchOrders()
                }) {
                    if baselinkerService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(baselinkerService.isLoading || !baselinkerService.connectionStatus.isConnected)
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(baselinkerService: baselinkerService)
        }
    }
}

struct StatusFilterButton: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct OrderRow: View {
    var order: Order
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("#\(order.orderNumber)")
                    .font(.headline)
                Spacer()
                OrderStatusBadge(status: order.status)
            }
            
            Text(order.customerName)
                .font(.subheadline)
            
            HStack {
                Text(formatDate(order.date))
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text(String(format: "%.2f %@", order.totalAmount, order.currency))
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct OrderStatusBadge: View {
    var status: String
    
    var statusInfo: (name: String, color: Color) {
        guard let orderStatus = OrderStatus(rawValue: status) else {
            return ("Nieznany", .gray)
        }
        
        let color: Color
        switch orderStatus.color {
        case "blue": color = .blue
        case "orange": color = .orange
        case "green": color = .green
        case "red": color = .red
        default: color = .gray
        }
        
        return (orderStatus.displayName, color)
    }
    
    var body: some View {
        Text(statusInfo.name)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusInfo.color.opacity(0.2))
            .foregroundColor(statusInfo.color)
            .cornerRadius(4)
    }
}

struct OrderDetailView: View {
    var order: Order
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Nagłówek zamówienia
                HStack {
                    VStack(alignment: .leading) {
                        Text("Zamówienie #\(order.orderNumber)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(formatDate(order.date))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    OrderStatusBadge(status: order.status)
                }
                
                Divider()
                
                // Dane klienta
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dane klienta")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                        Text(order.customerName)
                    }
                    
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                        Text(order.customerEmail)
                    }
                }
                
                Divider()
                
                // Produkty
                VStack(alignment: .leading, spacing: 8) {
                    Text("Produkty")
                        .font(.headline)
                    
                    ForEach(order.items) { item in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.subheadline)
                                Text("SKU: \(item.sku)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("\(item.quantity) x \(String(format: "%.2f", item.price))")
                                    .font(.subheadline)
                                Text(String(format: "%.2f", Double(item.quantity) * item.price))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        if item.id != order.items.last?.id {
                            Divider()
                        }
                    }
                }
                
                Divider()
                
                // Podsumowanie
                HStack {
                    Text("Razem")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.2f %@", order.totalAmount, order.currency))
                        .font(.headline)
                }
                
                // Przyciski akcji
                HStack {
                    Button(action: {
                        // Akcja zmiany statusu
                    }) {
                        Text("Zmień status")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        // Akcja drukowania
                    }) {
                        Text("Drukuj")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top)
            }
            .padding()
        }
        .navigationTitle("Szczegóły zamówienia")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TodaySummaryView: View {
    @EnvironmentObject private var baselinkerService: BaselinkerService
    @EnvironmentObject private var tabSelection: TabSelection
    @State private var showingSettings = false
    
    var body: some View {
        Group {
            if baselinkerService.isLoading {
                LoadingView()
            } else if let error = baselinkerService.error {
                ErrorView(error: error, retryAction: { baselinkerService.fetchOrders() })
            } else if !baselinkerService.connectionStatus.isConnected {
                ConnectionErrorView(action: { tabSelection.switchToSettings() })
            } else {
                TodaySummaryContent(todaySummary: baselinkerService.getTodaySummary(), salesData: baselinkerService.getSalesDataForLastWeek())
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    baselinkerService.fetchOrders()
                }) {
                    if baselinkerService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(baselinkerService.isLoading || !baselinkerService.connectionStatus.isConnected)
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(baselinkerService: baselinkerService)
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView("Pobieranie danych...")
                .padding()
            Text("Trwa synchronizacja z Baselinker")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct ErrorView: View {
    let error: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text(error)
                .multilineTextAlignment(.center)
            Button("Spróbuj ponownie") {
                retryAction()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

struct ConnectionErrorView: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Brak połączenia z Baselinker")
                .font(.headline)
            Text("Przejdź do ustawień, aby skonfigurować token API")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
            Button("Przejdź do ustawień") {
                action()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

struct TodaySummaryContent: View {
    let todaySummary: (orderCount: Int, totalValue: Double, newOrdersCount: Int, topProducts: [(name: String, quantity: Int, id: String, imageUrl: String?)])
    let salesData: [(day: String, value: Double, date: Date)]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Nagłówek
                TodaySummaryHeader()
                
                // Karty statystyk
                StatisticsGrid(todaySummary: todaySummary)
                
                // Najlepiej sprzedające się produkty dzisiaj
                TopProductsSection(topProducts: todaySummary.topProducts)
                
                // Porównanie z poprzednim dniem
                if salesData.count >= 2 {
                    ComparisonSection(salesData: salesData)
                }
            }
            .padding(.vertical)
        }
    }
}

struct TodaySummaryHeader: View {
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "pl_PL")
        return formatter.string(from: Date())
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Podsumowanie ostatnich 24h")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "clock")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundColor(.blue)
        }
        .padding()
    }
}

struct StatisticsGrid: View {
    let todaySummary: (orderCount: Int, totalValue: Double, newOrdersCount: Int, topProducts: [(name: String, quantity: Int, id: String, imageUrl: String?)])
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            // Liczba zamówień z ostatnich 24h
            StatCard(title: "Zamówienia (24h)", value: "\(todaySummary.orderCount)", icon: "cart", color: .blue)
            
            // Wartość zamówień z ostatnich 24h
            StatCard(title: "Wartość (24h)", value: String(format: "%.2f zł", todaySummary.totalValue), icon: "dollarsign.circle", color: .green)
            
            // Nowe zamówienia z ostatnich 24h
            StatCard(title: "Nowe (24h)", value: "\(todaySummary.newOrdersCount)", icon: "sparkles", color: .orange)
            
            // Średnia wartość zamówienia z ostatnich 24h
            if todaySummary.orderCount > 0 {
                let avgValue = todaySummary.totalValue / Double(todaySummary.orderCount)
                StatCard(title: "Średnia (24h)", value: String(format: "%.2f zł", avgValue), icon: "chart.bar.fill", color: .purple)
            } else {
                StatCard(title: "Średnia (24h)", value: "0.00 zł", icon: "chart.bar.fill", color: .purple)
            }
        }
        .padding(.horizontal)
    }
}

struct TopProductsSection: View {
    let topProducts: [(name: String, quantity: Int, id: String, imageUrl: String?)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Najlepiej sprzedające się produkty (24h)")
                .font(.headline)
                .padding(.horizontal)
            
            if topProducts.isEmpty {
                Text("Brak sprzedaży produktów w ostatnich 24h")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(topProducts, id: \.id) { product in
                        HStack {
                            // Obrazek produktu
                            ProductImageView(imageUrl: product.imageUrl)
                                .frame(width: 40, height: 40)
                                .cornerRadius(6)
                                .padding(.trailing, 8)
                            
                            Text(product.name)
                                .lineLimit(1)
                            Spacer()
                            Text("\(product.quantity) szt.")
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        if product.id != topProducts.last?.id {
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
            }
        }
    }
}

// Komponent do wyświetlania obrazka produktu
struct ProductImageView: View {
    let imageUrl: String?
    
    var body: some View {
        if let imageUrl = imageUrl {
            if imageUrl.hasPrefix("http") {
                // Jeśli to URL, używamy AsyncImage
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 40, height: 40)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        // Wyświetlamy placeholder w przypadku błędu ładowania obrazka
                        VStack {
                            Image(systemName: "photo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                                .foregroundColor(.gray)
                        }
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.1))
                    @unknown default:
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 40, height: 40)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onAppear {
                    print("🖼️ Ładowanie obrazka z URL: \(imageUrl)")
                }
            } else {
                // Jeśli to nazwa obrazu systemowego lub nieprawidłowy URL
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .foregroundColor(.gray)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onAppear {
                        print("⚠️ Nieprawidłowy URL obrazka: \(imageUrl)")
                    }
            }
        } else {
            // Domyślny obraz, gdy nie ma URL
            Image(systemName: "photo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundColor(.gray)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onAppear {
                    print("❌ Brak URL obrazka")
                }
        }
    }
}

struct ComparisonSection: View {
    let salesData: [(day: String, value: Double, date: Date)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Porównanie z poprzednim dniem")
                .font(.headline)
                .padding(.horizontal)
            
            let todayValue = salesData[salesData.count - 1].value
            let yesterdayValue = salesData[salesData.count - 2].value
            
            let difference = todayValue - yesterdayValue
            let percentChange = yesterdayValue > 0 ? (difference / yesterdayValue) * 100 : 0
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Dzisiaj")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(String(format: "%.2f zł", todayValue))
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Wczoraj")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(String(format: "%.2f zł", yesterdayValue))
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Zmiana")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    HStack(spacing: 4) {
                        Image(systemName: difference >= 0 ? "arrow.up" : "arrow.down")
                            .foregroundColor(difference >= 0 ? .green : .red)
                        Text(String(format: "%.1f%%", abs(percentChange)))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(difference >= 0 ? .green : .red)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
        }
        .padding(.bottom, 20)
    }
}

struct NotificationsPopupView: View {
    @Binding var isShowing: Bool
    @EnvironmentObject private var notificationService: NotificationService
    
    var body: some View {
        VStack {
            HStack {
                Text("Powiadomienia")
                    .font(.headline)
                Spacer()
                Button(action: {
                    isShowing = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            
            Divider()
            
            if notificationService.notifications.isEmpty {
                Spacer()
                VStack {
                    Image(systemName: "bell.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("Brak powiadomień")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(notificationService.notifications) { notification in
                            NotificationRow(notification: notification)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    notificationService.markAsRead(notification)
                                }
                            
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                }
            }
            
            if !notificationService.notifications.isEmpty {
                Button(action: {
                    notificationService.markAllAsRead()
                }) {
                    Text("Oznacz wszystkie jako przeczytane")
                        .font(.subheadline)
                }
                .padding()
            }
        }
    }
}

struct NotificationRow: View {
    let notification: Notification
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: notification.date)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: notification.isRead ? "circle" : "circle.fill")
                .foregroundColor(notification.isRead ? .gray : .blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.headline)
                    .foregroundColor(notification.isRead ? .gray : .primary)
                
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}

struct SettingsView: View {
    @State private var apiToken = ""
    @State private var notificationsEnabled = true
    @State private var newOrdersNotificationsEnabled = true
    @State private var statusChangeNotificationsEnabled = true
    @State private var lowStockNotificationsEnabled = true
    @State private var darkModeEnabled = false
    @State private var syncInterval = 15.0
    @State private var isTestingConnection = false
    @State private var showConnectionAlert = false
    @State private var connectionAlertMessage = ""
    @State private var showDebugInfo = false
    @ObservedObject var baselinkerService: BaselinkerService
    @EnvironmentObject private var notificationService: NotificationService
    
    init(baselinkerService: BaselinkerService) {
        self.baselinkerService = baselinkerService
        
        // Wczytaj zapisane ustawienia z UserDefaults
        _apiToken = State(initialValue: UserDefaults.standard.string(forKey: "baselinkerApiToken") ?? "")
        _notificationsEnabled = State(initialValue: UserDefaults.standard.bool(forKey: "notificationsEnabled"))
        _newOrdersNotificationsEnabled = State(initialValue: UserDefaults.standard.bool(forKey: "newOrdersNotificationsEnabled"))
        _statusChangeNotificationsEnabled = State(initialValue: UserDefaults.standard.bool(forKey: "statusChangeNotificationsEnabled"))
        _lowStockNotificationsEnabled = State(initialValue: UserDefaults.standard.bool(forKey: "lowStockNotificationsEnabled"))
        _darkModeEnabled = State(initialValue: UserDefaults.standard.bool(forKey: "darkModeEnabled"))
        _syncInterval = State(initialValue: UserDefaults.standard.double(forKey: "syncInterval") != 0 ? UserDefaults.standard.double(forKey: "syncInterval") : 15.0)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Baselinker API")) {
                    SecureField("Token API", text: $apiToken)
                    
                    Button(action: {
                        baselinkerService.saveApiToken(apiToken)
                        isTestingConnection = true
                    }) {
                        if baselinkerService.connectionStatus == .connecting || baselinkerService.isLoading {
                            HStack {
                                Text("Łączenie...")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            Text("Zapisz i przetestuj połączenie")
                        }
                    }
                    .disabled(apiToken.isEmpty || baselinkerService.connectionStatus == .connecting || baselinkerService.isLoading)
                    
                    HStack {
                        Text("Status połączenia")
                        Spacer()
                        ConnectionStatusView(status: baselinkerService.connectionStatus)
                    }
                    
                    if case .failed = baselinkerService.connectionStatus {
                        Button("Pokaż informacje debugowania") {
                            showDebugInfo.toggle()
                        }
                        
                        if showDebugInfo, let debugInfo = baselinkerService.lastResponseDebug {
                            Text("Odpowiedź API:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text(debugInfo)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                }
                
                Section(header: Text("Powiadomienia")) {
                    Toggle("Włącz powiadomienia", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { oldValue, newValue in
                            UserDefaults.standard.set(newValue, forKey: "notificationsEnabled")
                        }
                    
                    if notificationsEnabled {
                        Toggle("Nowe zamówienia", isOn: $newOrdersNotificationsEnabled)
                            .onChange(of: newOrdersNotificationsEnabled) { oldValue, newValue in
                                UserDefaults.standard.set(newValue, forKey: "newOrdersNotificationsEnabled")
                            }
                        Toggle("Zmiany statusu", isOn: $statusChangeNotificationsEnabled)
                            .onChange(of: statusChangeNotificationsEnabled) { oldValue, newValue in
                                UserDefaults.standard.set(newValue, forKey: "statusChangeNotificationsEnabled")
                            }
                        Toggle("Niski stan magazynowy", isOn: $lowStockNotificationsEnabled)
                            .onChange(of: lowStockNotificationsEnabled) { oldValue, newValue in
                                UserDefaults.standard.set(newValue, forKey: "lowStockNotificationsEnabled")
                            }
                    }
                }
                
                Section(header: Text("Synchronizacja")) {
                    VStack {
                        Text("Częstotliwość synchronizacji: \(Int(syncInterval)) min")
                        Slider(value: $syncInterval, in: 5...60, step: 5)
                    }
                    
                    Button(action: {
                        baselinkerService.fetchOrders()
                    }) {
                        if baselinkerService.isLoading {
                            HStack {
                                Text("Synchronizacja...")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            Text("Synchronizuj teraz")
                        }
                    }
                    .disabled(baselinkerService.isLoading || !baselinkerService.connectionStatus.isConnected)
                }
                
                Section(header: Text("Wygląd")) {
                    Toggle("Tryb ciemny", isOn: $darkModeEnabled)
                        .onChange(of: darkModeEnabled) { oldValue, newValue in
                            UserDefaults.standard.set(newValue, forKey: "darkModeEnabled")
                        }
                }
                
                Section(header: Text("O aplikacji")) {
                    HStack {
                        Text("Wersja")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                    
                    Link("Odwiedź stronę Baselinker", destination: URL(string: "https://baselinker.com")!)
                }
            }
            .navigationTitle("Ustawienia")
            .onChange(of: baselinkerService.connectionStatus) { oldValue, newStatus in
                if isTestingConnection {
                    isTestingConnection = false
                    
                    switch newStatus {
                    case .connected:
                        connectionAlertMessage = "Połączenie z Baselinker zostało ustanowione pomyślnie."
                        showConnectionAlert = true
                    case .failed(let message):
                        connectionAlertMessage = "Błąd połączenia: \(message)"
                        showConnectionAlert = true
                        showDebugInfo = true
                    default:
                        break
                    }
                }
            }
            .alert(isPresented: $showConnectionAlert) {
                Alert(
                    title: Text("Status połączenia"),
                    message: Text(connectionAlertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

struct ConnectionStatusView: View {
    var status: BaselinkerService.ConnectionStatus
    
    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
            Text(status.description)
                .foregroundColor(statusColor)
        }
    }
    
    var statusIcon: String {
        switch status {
        case .notConnected:
            return "wifi.slash"
        case .connecting:
            return "arrow.clockwise"
        case .connected:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
    
    var statusColor: Color {
        switch status {
        case .notConnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .failed:
            return .red
        }
    }
}

// Dodajemy nowy widok do wyświetlania produktów z magazynu
struct InventoryProductsView: View {
    @ObservedObject var baselinkerService: BaselinkerService
    @State private var searchText = ""
    @State private var showLowStockOnly = false
    @State private var showingSettings = false
    
    var filteredProducts: [InventoryProduct] {
        var result = baselinkerService.inventoryProducts
        
        // Filtrowanie według tekstu wyszukiwania
        if !searchText.isEmpty {
            result = result.filter { product in
                product.name.lowercased().contains(searchText.lowercased()) ||
                product.sku.lowercased().contains(searchText.lowercased()) ||
                (product.ean ?? "").lowercased().contains(searchText.lowercased())
            }
        }
        
        // Filtrowanie według niskiego stanu magazynowego
        if showLowStockOnly {
            result = result.filter { $0.isLowStock }
            
            // Sortowanie według daty ostatniej aktualizacji (od najnowszych)
            result.sort { (product1, product2) -> Bool in
                if let date1 = product1.lastUpdateDate, let date2 = product2.lastUpdateDate {
                    return date1 > date2
                } else if product1.lastUpdateDate != nil {
                    return true
                } else if product2.lastUpdateDate != nil {
                    return false
                } else {
                    return product1.name < product2.name // Jeśli brak dat, sortuj alfabetycznie
                }
            }
        }
        
        return result
    }
    
    var body: some View {
        VStack {
            // Wybór katalogu
            if !baselinkerService.inventories.isEmpty {
                HStack {
                    Text("Katalog:")
                        .font(.headline)
                    
                    Picker("Wybierz katalog", selection: Binding(
                        get: { baselinkerService.selectedInventoryId ?? "" },
                        set: { newValue in
                            if !newValue.isEmpty {
                                baselinkerService.fetchInventoryProducts(inventoryId: newValue)
                            }
                        }
                    )) {
                        ForEach(baselinkerService.inventories) { inventory in
                            Text(inventory.name).tag(inventory.id)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
            }
            
            // Pole wyszukiwania i przełącznik niskiego stanu
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Szukaj produktów...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // Przełącznik do filtrowania produktów z niskim stanem
                Toggle(isOn: $showLowStockOnly) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Pokaż tylko produkty z niskim stanem magazynowym")
                            .font(.subheadline)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .orange))
            }
            .padding(.horizontal)
            
            if baselinkerService.isLoadingProducts {
                Spacer()
                VStack {
                    ProgressView("Ładowanie produktów...")
                    
                    // Dodajemy pasek postępu
                    if baselinkerService.loadingProgress > 0 {
                        VStack {
                            ProgressView(value: baselinkerService.loadingProgress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                                .padding(.top, 8)
                            
                            Text("\(Int(baselinkerService.loadingProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                    }
                }
                Spacer()
            } else if filteredProducts.isEmpty {
                Spacer()
                VStack {
                    Image(systemName: "cube.box")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("Brak produktów")
                        .font(.headline)
                        .padding(.top)
                    if showLowStockOnly {
                        Text("Nie znaleziono produktów z niskim stanem magazynowym")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Text("Nie znaleziono żadnych produktów w wybranym katalogu")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                Spacer()
            } else {
                List {
                    ForEach(filteredProducts) { product in
                        InventoryProductRow(product: product)
                    }
                }
                .listStyle(PlainListStyle())
                
                // Informacja o liczbie produktów
                HStack {
                    Text("Liczba produktów: \(filteredProducts.count)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    
                    if showLowStockOnly {
                        Text("Filtr: Niski stan magazynowy")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
        .navigationTitle("Produkty w magazynie")
        .onAppear {
            if baselinkerService.inventories.isEmpty {
                baselinkerService.fetchInventories()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(baselinkerService: baselinkerService)
        }
    }
}

// Wiersz produktu
struct InventoryProductRow: View {
    var product: InventoryProduct
    
    var body: some View {
        HStack(spacing: 12) {
            // Obrazek produktu
            if let imageUrl = product.imageUrl, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 60, height: 60)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .cornerRadius(6)
                    case .failure:
                        Image(systemName: "photo")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                            .frame(width: 60, height: 60)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 60, height: 60)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 30))
                    .foregroundColor(.gray)
                    .frame(width: 60, height: 60)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
            }
            
            // Informacje o produkcie
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(product.name)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if product.isLowStock {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                    
                    Spacer()
                }
                
                HStack {
                    Text("SKU: \(product.sku)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if let ean = product.ean, !ean.isEmpty {
                        Text("EAN: \(ean)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                HStack {
                    Text(String(format: "%.2f zł", product.price))
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Wskaźnik stanu magazynowego
                    HStack(spacing: 4) {
                        Circle()
                            .fill(product.quantity > 0 ? (product.isLowStock ? Color.orange : Color.green) : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text("\(product.quantity) szt.")
                            .font(.caption)
                            .foregroundColor(product.quantity > 0 ? (product.isLowStock ? .orange : .primary) : .red)
                    }
                }
                
                // Dodajemy informację o dacie ostatniej aktualizacji dla produktów z niskim stanem
                if product.isLowStock, let updateDate = product.lastUpdateDate {
                    Text("Aktualizacja: \(formatDate(updateDate))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 8)
        .background(product.isLowStock ? Color.orange.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
    
    // Funkcja pomocnicza do formatowania daty
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView(baselinkerService: BaselinkerService())
        .environmentObject(BaselinkerService())
        .environmentObject(NotificationService())
}
