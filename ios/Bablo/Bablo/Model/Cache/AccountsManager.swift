//
//  AccountsManager.swift
//  Bablo
//
//  Created by Anton Bredykhin on 3/13/25.
//

import CoreData
import Foundation

class AccountManager {
    private let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack = .shared) {
        self.coreDataStack = coreDataStack
    }
    
    func saveAccounts(_ accounts: [BankAccount], for bankId: Int) {
        let context = coreDataStack.newBackgroundContext()
        
        context.perform {
                // Find the bank entity
            let bankFetchRequest: NSFetchRequest<BankEntity> = BankEntity.fetchRequest()
            bankFetchRequest.predicate = NSPredicate(format: "id == %d", bankId)
            
            guard let bankEntity = try? context.fetch(bankFetchRequest).first else {
                Logger.e("Could not find bank with ID \(bankId)")
                return
            }
            
                // Fetch existing accounts for this bank to avoid duplicates
            let accountFetchRequest: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
            accountFetchRequest.predicate = NSPredicate(format: "bank.id == %d", bankId)
            let existingAccounts = try? context.fetch(accountFetchRequest)
            
            for account in accounts {
                    // Check if account already exists
                if let existingAccount = existingAccounts?.first(where: { $0.id == Int64(account.id) }) {
                        // Update existing account
                    self.updateAccountEntity(existingAccount, with: account)
                } else {
                        // Create new account entity
                    let accountEntity = AccountEntity(context: context)
                    self.configureAccountEntity(accountEntity, with: account)
                    accountEntity.bank = bankEntity
                }
            }
            
                // Save context
            do {
                try context.save()
                Logger.i("Successfully saved \(accounts.count) accounts to CoreData for bank \(bankId)")
            } catch {
                Logger.e("Failed to save accounts to CoreData: \(error)")
            }
        }
    }
    
    func fetchAccounts(for bankId: Int) -> [BankAccount] {
        let context = coreDataStack.viewContext
        let fetchRequest: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "bank.id == %d", bankId)
        
        do {
            let accountEntities = try context.fetch(fetchRequest)
            return accountEntities.map { self.mapAccountEntityToBankAccount($0) }
        } catch {
            Logger.e("Failed to fetch accounts from CoreData: \(error)")
            return []
        }
    }
    
        // Helper methods
    private func configureAccountEntity(_ accountEntity: AccountEntity, with account: BankAccount) {
        accountEntity.id = Int64(account.id)
        accountEntity.name = account.name
        accountEntity.currentBalance = account.current_balance
        accountEntity.isoCurrencyCode = account.iso_currency_code
        accountEntity.type = account._type
        accountEntity.mask = account.mask
        accountEntity.officialName = account.official_name
        accountEntity.updatedAt = account.updated_at
        accountEntity.hidden = account.hidden ?? false
    }
    
    private func updateAccountEntity(_ accountEntity: AccountEntity, with account: BankAccount) {
        accountEntity.name = account.name
        accountEntity.currentBalance = account.current_balance
        accountEntity.isoCurrencyCode = account.iso_currency_code
        accountEntity.type = account._type
        accountEntity.mask = account.mask
        accountEntity.officialName = account.official_name
        accountEntity.updatedAt = account.updated_at
        // Only update hidden status if it's provided
        if let hidden = account.hidden {
            accountEntity.hidden = hidden
        }
    }
    
    private func mapAccountEntityToBankAccount(_ accountEntity: AccountEntity) -> BankAccount {
        return BankAccount(
            id: Int(accountEntity.id),
            name: accountEntity.name ?? "",
            mask: accountEntity.mask,
            official_name: accountEntity.officialName,
            current_balance: accountEntity.currentBalance,
            iso_currency_code: accountEntity.isoCurrencyCode ?? "USD",
            _type: accountEntity.type ?? "unknown",
            hidden: accountEntity.hidden,
            updated_at: accountEntity.updatedAt ?? Date()
        )
    }
    
    func updateAccountHiddenStatus(_ accountId: Int, hidden: Bool) {
        let context = coreDataStack.newBackgroundContext()
        
        context.perform {
            let fetchRequest: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %d", accountId)
            
            do {
                let results = try context.fetch(fetchRequest)
                if let accountEntity = results.first {
                    accountEntity.hidden = hidden
                    try context.save()
                    Logger.i("Updated account \(accountId) hidden status to \(hidden) in CoreData")
                } else {
                    Logger.w("Account with ID \(accountId) not found in CoreData")
                }
            } catch {
                Logger.e("Failed to update account hidden status in CoreData: \(error)")
            }
        }
    }
}
