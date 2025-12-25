import SwiftUI

struct HeroBudgetEmptyStateView: View {
    @EnvironmentObject var navigationState: NavigationState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Monthly Budget")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
            }
            
            Text("Set up your budget to unlock insights")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Text("Get Started")
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "arrow.right")
                    .font(.footnote)
            }
            .foregroundColor(.blue)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.4), lineWidth: 1)
                }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        HeroBudgetEmptyStateView()
            .environmentObject(NavigationState())
    }
}
