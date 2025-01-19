    //
    //  OnboardingWizazard.swift
    //  Bablo
    //
    //  Created by Anton Bredykhin on 12/18/24.
    //

import SwiftUI

enum OnboardingStep: CaseIterable, Identifiable { // CaseIterable for easy iteration, Identifiable for List/ForEach
    case welcome, budget, accounts, categories, complete
    var id: Self { self } // For Identifiable
}


struct OnboardingWizard: View {
    @State private var currentStep: OnboardingStep = .welcome // Start with the first step
    
    var body: some View {
        VStack {
            TabView(selection: $currentStep) {
                OnboardingStartView()
                    .tag(OnboardingStep.welcome)
                OnboardingBudgetView()
                    .tag(OnboardingStep.budget)
                OnboardingAccountsView()
                    .tag(OnboardingStep.accounts)
                OnboardingCategoriesView()
                    .tag(OnboardingStep.categories)
                OnboardingCompleteView()
                    .tag(OnboardingStep.complete)
            }
            .tabViewStyle(
                PageTabViewStyle(indexDisplayMode: .automatic)
            ) // Hide the default dots
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always)) // Optionally show dots
            
            
            HStack {
                    // Spacer on both sides to center the button
                Spacer()
                
                if currentStep != OnboardingStep.allCases.last {
                    Button {
                        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
                              currentIndex < OnboardingStep.allCases.count - 1 else { return }
                        currentStep = OnboardingStep.allCases[currentIndex + 1]
                    } label: {
                        Text("Next")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                } else {
                    Button {
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        //dismiss()
                    } label: {
                        Text("Finish")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    OnboardingWizard()
}


