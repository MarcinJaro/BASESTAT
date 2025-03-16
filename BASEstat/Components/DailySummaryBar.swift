import SwiftUI
import Combine

struct DailySummaryBar: View {
    @EnvironmentObject var baselinkerService: BaselinkerService
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Podsumowanie dzienne")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .padding(.top, 4)
            
            if let summary = baselinkerService.dailySummary {
                HStack(spacing: 16) {
                    Spacer()
                    
                    // Zamówienia
                    VStack(alignment: .center) {
                        Text("Zamówienia")
                            .font(.caption)
                            .foregroundColor(.gray)
                        HStack {
                            Text("\(summary.ordersCount)")
                                .font(.headline)
                                .fontWeight(.bold)
                            Image(systemName: "cart")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Divider()
                        .frame(height: 30)
                    
                    // Przychód
                    VStack(alignment: .center) {
                        Text("Przychód")
                            .font(.caption)
                            .foregroundColor(.gray)
                        HStack {
                            Text(summary.formattedRevenue())
                                .font(.headline)
                                .fontWeight(.bold)
                            Image(systemName: "dollarsign.circle")
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.bottom, 4)
            } else {
                Button(action: {
                    baselinkerService.calculateDailySummary()
                }) {
                    HStack {
                        Text("Oblicz podsumowanie dzienne")
                        Image(systemName: "arrow.clockwise")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
    }
}

struct DailySummaryBar_Previews: PreviewProvider {
    static var previews: some View {
        DailySummaryBar()
            .environmentObject(BaselinkerService())
    }
} 