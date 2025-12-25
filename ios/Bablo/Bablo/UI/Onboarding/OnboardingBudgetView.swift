import SwiftUI

struct OnboardingBudgetView: View {
    @Binding var income: String
    @Binding var expenses: String
    
    var discretionary: Double {
        let inc = Double(income) ?? 0
        let exp = Double(expenses) ?? 0
        return max(0, inc - exp)
    }
    
    var body: some View {
        ZStack {
            // Background Glow
            Circle()
                .fill(Color(red: 0.5, green: 1.0, blue: 0.0).opacity(0.1))
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(y: 100)
            
            VStack(spacing: 24) {
                Text("Let's define your\n\"Fun Money\".")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)
                
                // Input Card
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monthly Income")
                            .font(.system(size: 14, weight: .bold))
                        
                        TextField("Amount", text: $income)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 20, weight: .medium))
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green.opacity(0.5), lineWidth: 2)
                                    .shadow(color: .green.opacity(0.3), radius: 8)
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mandatory Expenses (rent, bills, etc.)")
                            .font(.system(size: 14, weight: .bold))
                        
                        TextField("Amount", text: $expenses)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 20, weight: .medium))
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                                    .shadow(color: .orange.opacity(0.3), radius: 8)
                            }
                    }
                    
                    VStack(spacing: 4) {
                        Text(discretionary, format: .currency(code: "USD"))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                        
                        Text("Discretionary Budget")
                            .font(.system(size: 20, weight: .bold))
                        
                        Text("This is your flexible \"fun money\" for the month.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                    .padding(.top, 12)
                }
                .padding(24)
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 10)
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
    }
}

#Preview {
    OnboardingBudgetView(income: .constant("5500"), expenses: .constant("4300"))
}
