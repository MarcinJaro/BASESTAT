import SwiftUI

struct TopBar: View {
    var title: String
    var showSettingsButton: Bool = true
    var onSettingsTapped: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.primary)
            
            Spacer()
            
            if showSettingsButton {
                Button(action: {
                    onSettingsTapped?()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct TopBar_Previews: PreviewProvider {
    static var previews: some View {
        TopBar(title: "Dashboard")
            .previewLayout(.sizeThatFits)
    }
} 