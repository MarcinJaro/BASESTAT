import SwiftUI

struct ContentView: View {
    @EnvironmentObject var orderManager: OrderManager
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack {
                if orderManager.isLoading {
                    ProgressView("Ładowanie danych...")
                } else if let statistics = orderManager.statistics {
                    StatisticsView(statistics: statistics)
                }
                
                OrderListView(orders: orderManager.orders)
            }
            .navigationTitle("BaseLinker Stats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { orderManager.fetchOrders() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
        .onAppear {
            orderManager.fetchOrders()
        }
    }
}

struct StatisticsView: View {
    let statistics: OrderStatistics
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 30) {
                StatCard(
                    title: "Sprzedaż całkowita",
                    value: String(format: "%.2f zł", statistics.totalSales)
                )
                
                StatCard(
                    title: "Liczba zamówień",
                    value: "\(statistics.orderCount)"
                )
            }
            
            StatCard(
                title: "Średnia wartość zamówienia",
                value: String(format: "%.2f zł", statistics.averageOrderValue)
            )
        }
        .padding()
    }
}

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .bold()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct OrderListView: View {
    let orders: [Order]
    
    var body: some View {
        List(orders) { order in
            VStack(alignment: .leading) {
                Text("Zamówienie #\(order.orderNumber)")
                    .font(.headline)
                Text(order.customerName)
                    .font(.subheadline)
                Text(String(format: "%.2f \(order.currency)", order.totalAmount))
                    .font(.caption)
            }
        }
    }
} 