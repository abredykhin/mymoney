//
//  LinkButtonView.swift
//  mymoney
//
//  Created by Anton Bredykhin on 2/20/24.
//

import SwiftUI
import LinkKit

@MainActor
struct LinkButtonView : View {
    @EnvironmentObject var userAccount: UserAccount
    @EnvironmentObject var bankAccountsManager: BankAccountsManager
    @State private var linkViewModel: LinkViewModel = LinkViewModel()
    
    var body: some View {
        ZStack(alignment: .leading) {
            Button {
                Task {
                    debugPrint("Add new account pressed!")
                    try? await linkViewModel.getLinkToken()
                }
            } label: {
                Text("Link new account")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.primaryColor)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .shadow(radius: 2)
            }
        }
        .onAppear() {
            linkViewModel.bankAccountsManager = self.bankAccountsManager
            linkViewModel.client = self.userAccount.client
        }
        .sheet(
            isPresented: $linkViewModel.shouldShowLink,
            onDismiss: {
                linkViewModel.shouldShowLink = false
            },
            content: {
                let createResult = linkViewModel.handler
                switch createResult {
                case .failure(let createError):
                    Text("Link Creation Error: \(createError.localizedDescription)")
                        .font(.title2)
                case .success(let handler):
                    LinkController(handler: handler)
                case .none:
                    EmptyView()
                }
            }
        )
    }
}
