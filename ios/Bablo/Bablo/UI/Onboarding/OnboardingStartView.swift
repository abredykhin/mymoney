//
//  OnboardingStart.swift
//  Bablo
//
//  Created by Anton Bredykhin on 12/14/24.
//

import SwiftUI

struct OnboardingStartView : View {
    var body: some View {
        VStack {
            Text("Welcome to BabloApp!")
                .font(.title)
                .foregroundStyle(.primary)
                .padding(.bottom, 24)
            
            Text("At the next screen you can connect your accounts to start tracking your financial health. ")
                .font(.headline)
                .padding(.bottom, 24)
            
            Text("Linking your bank accounts make it easy for you to see the whole picture at once, see the patterns in income and spending, and improve your finances.")
                .font(.headline)
                .padding(.bottom, 24)
            

            Text("TODO: add a screenshot of the dashboard!")
                .font(.largeTitle)
            
            Spacer()
        }.padding()
    }
}

#Preview {
    OnboardingStartView()
}
