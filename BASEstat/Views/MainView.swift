import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// Definicja TabItem dla MainView
enum TabItem: String, CaseIterable {
    case dashboard = "Dashboard"
    case orders = "Zamówienia"
    case products = "Produkty"
    case summary = "Podsumowanie"
    
    var icon: String {
        switch self {
        case .dashboard:
            return "chart.bar.fill"
        case .orders:
            return "bag.fill"
        case .products:
            return "cube.fill"
        case .summary:
            return "calendar"
        }
    }
}

// Definicja MainTopBar dla MainView
struct MainTopBar: View {
    var title: String
    var showSettingsButton: Bool = true
    var onSettingsTapped: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            if showSettingsButton {
                Button(action: {
                    onSettingsTapped?()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                }
            }
        }
    }
}

// Definicja CardView dla MainView
struct MainCardView: View {
    var title: String
    var value: String
    var change: String
    var icon: String
    var color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(color)
                    .cornerRadius(10)
                
                Spacer()
                
                Text(change)
                    .font(.caption)
                    .foregroundColor(change.hasPrefix("+") ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (change.hasPrefix("+") ? Color.green : Color.red)
                            .opacity(0.1)
                            .cornerRadius(12)
                    )
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .frame(maxWidth: .infinity)
    }
}

// Definicja CustomTabBar dla MainView
struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22))
                        
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? Color.blue : Color.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        ZStack {
                            if selectedTab == tab {
                                Color.blue.opacity(0.1)
                                    .cornerRadius(12)
                            }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 20) // Dodatkowy padding na dole dla bezpieczeństwa (safe area)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: -4)
    }
}

struct MainView: View {
    @State private var selectedTab: TabItem = .dashboard
    @State private var showSettings: Bool = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                MainTopBar(
                    title: selectedTab.rawValue,
                    showSettingsButton: true,
                    onSettingsTapped: {
                        withAnimation {
                            showSettings.toggle()
                        }
                    }
                )
                .padding(.horizontal)
                .padding(.top)
                
                TabView(selection: $selectedTab) {
                    // Dashboard View
                    ScrollView {
                        VStack(spacing: 16) {
                            // Stats Cards
                            HStack(spacing: 16) {
                                MainCardView(
                                    title: "Zamówienia",
                                    value: "24",
                                    change: "+12%",
                                    icon: "bag",
                                    color: Color.blue
                                )
                                
                                MainCardView(
                                    title: "Przychód",
                                    value: "4,256 zł",
                                    change: "+8%",
                                    icon: "dollarsign.circle",
                                    color: Color.pink
                                )
                            }
                            
                            HStack(spacing: 16) {
                                MainCardView(
                                    title: "Produkty",
                                    value: "124",
                                    change: "+3%",
                                    icon: "cube",
                                    color: Color.cyan
                                )
                                
                                MainCardView(
                                    title: "Klienci",
                                    value: "48",
                                    change: "+24%",
                                    icon: "person",
                                    color: Color.orange
                                )
                            }
                            
                            // Recent Orders
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Ostatnie zamówienia")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                ForEach(0..<5) { index in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("Zamówienie #\(10245 + index)")
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            
                                            Text("12 maja 2023")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(120 + index * 15) zł")
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                }
                            }
                            .padding(.top)
                        }
                        .padding()
                    }
                    .tag(TabItem.dashboard)
                    
                    // Orders View
                    ScrollView {
                        Text("Zamówienia")
                            .font(.title)
                    }
                    .tag(TabItem.orders)
                    
                    // Products View
                    ScrollView {
                        Text("Produkty")
                            .font(.title)
                    }
                    .tag(TabItem.products)
                    
                    // Notifications View
                    ScrollView {
                        Text("Powiadomienia")
                            .font(.title)
                    }
                    .tag(TabItem.summary)
                }
                .background(
                    Group {
                        #if os(iOS)
                        AnyView(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(UIColor.systemBackground),
                                    Color(UIColor.systemBackground).opacity(0.8)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        #else
                        AnyView(Color.white)
                        #endif
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                #if os(iOS)
                CustomTabBar(selectedTab: $selectedTab)
                #endif
            }
            
            // Settings Panel
            if showSettings {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showSettings = false
                        }
                    }
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Ustawienia")
                        .font(.title)
                        .foregroundColor(.primary)
                    
                    Divider()
                    
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "person.circle")
                            Text("Profil")
                        }
                        .foregroundColor(.primary)
                    }
                    
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "bell")
                            Text("Powiadomienia")
                        }
                        .foregroundColor(.primary)
                    }
                    
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "lock")
                            Text("Prywatność")
                        }
                        .foregroundColor(.primary)
                    }
                    
                    Divider()
                    
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                            Text("Wyloguj")
                        }
                        .foregroundColor(.red)
                    }
                    
                    Spacer()
                }
                .padding()
                .frame(width: 250)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 0)
                .transition(.move(edge: .trailing))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding()
            }
        }
        #if os(iOS)
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        #else
        // Na macOS używamy domyślnego stylu
        #endif
    }
}

// Komponent karty statystyk
struct MainViewStatCard: View {
    var title: String
    var value: String
    var icon: String
    var color: Color
    var isDark: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isDark ? .white : color)
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isDark ? .white : Color.primary)
            }
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(isDark ? .white.opacity(0.8) : Color.secondary)
        }
        .padding(16)
        .background(
            isDark ? color.opacity(0.2) : Color.white
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isDark ? color.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
} 