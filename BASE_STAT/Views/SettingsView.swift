import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var orderManager: OrderManager
    @State private var apiToken: String = UserDefaults.standard.string(forKey: "baselinkerApiToken") ?? ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API BaseLinker")) {
                    SecureField("Token API", text: $apiToken)
                    Button("Zapisz") {
                        orderManager.setApiToken(apiToken)
                        dismiss()
                    }
                    .disabled(apiToken.isEmpty)
                }
                
                Section(header: Text("Informacje")) {
                    Text("Token API można znaleźć w panelu BaseLinker w zakładce Ustawienia > API")
                }
            }
            .navigationTitle("Ustawienia")
            .navigationBarItems(trailing: Button("Zamknij") {
                dismiss()
            })
        }
    }
} 