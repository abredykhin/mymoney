import SwiftUI

struct OnboardingStartView: View {
    var body: some View {
        ZStack {
            // Expansive Background Glow
            Circle()
                .fill(Color(red: 0.4, green: 1.0, blue: 0.8).opacity(0.4))
                .frame(width: 600, height: 600)
                .blur(radius: 100)
                .offset(x: -150, y: -100)
                .allowsHitTesting(false)
            
            Circle()
                .fill(Color(red: 0.2, green: 0.8, blue: 1.0).opacity(0.3))
                .frame(width: 500, height: 500)
                .blur(radius: 120)
                .offset(x: 200, y: 100)
                .allowsHitTesting(false)

            VStack(spacing: 24) {
                Spacer()
                
                // Glassmorphic Graphic (Central Illustration)
                ZStack {
                    // Main Glass Card
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 200, height: 130)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(.white.opacity(0.5), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                    
                    // Card Details (Simulated)
                    VStack(alignment: .leading, spacing: 8) {
                        Circle()
                            .fill(.white.opacity(0.3))
                            .frame(width: 20, height: 20)
                        
                        HStack(spacing: 4) {
                            ForEach(0..<4) { _ in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white.opacity(0.3))
                                    .frame(width: 25, height: 4)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .frame(width: 200, height: 130, alignment: .topLeading)
                    
                    // Floating Icons
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(LinearGradient(colors: [.green.opacity(0.6), .teal.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .offset(x: -70, y: -50)
                    
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.5), .purple.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .offset(x: 80, y: -30)
                    
                    Image(systemName: "shield.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.7), .cyan.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .offset(x: 60, y: 50)
                        .shadow(color: .blue.opacity(0.2), radius: 10, x: 5, y: 5)
                    
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(LinearGradient(colors: [.teal.opacity(0.5), .green.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .offset(x: -80, y: 40)
                }
                .padding(.top, 20)
                
                VStack(spacing: 12) {
                    Text("Master your money, effortlessly.")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .minimumScaleFactor(0.8)
                    
                    Text("Track net worth, manage spending, and unlock your true discretionary budget.")
                        .font(.system(size: 16))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 30)
                }
                
                Spacer()
            }
            .padding(.bottom, 60) // Add space for footer buttons
        }
    }
}

#Preview {
    OnboardingStartView()
}
