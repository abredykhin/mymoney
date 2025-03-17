//
//  BankManager.swift
//  Bablo
//
//  Created by Anton Bredykhin on 3/13/25.
//

import CoreData
import Foundation

class BankManager {
    private let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack = .shared) {
        self.coreDataStack = coreDataStack
    }
    
    func saveBanks(_ banks: [Bank]) {
        let context = coreDataStack.newBackgroundContext()
        context.perform {
                // First, fetch existing banks to avoid duplicates
            let fetchRequest: NSFetchRequest<BankEntity> = BankEntity.fetchRequest()
            let existingBanks = try? context.fetch(fetchRequest)
            let existingBankIds = existingBanks?.map { $0.id } ?? []
            
            for bank in banks {
                    // Check if bank already exists
                if let existingBank = existingBanks?.first(where: { $0.id == Int64(bank.id) }) {
                        // Update existing bank
                    self.updateBankEntity(existingBank, with: bank, in: context)
                } else {
                        // Create new bank entity
                    let bankEntity = BankEntity(context: context)
                    bankEntity.id = Int64(bank.id)
                    bankEntity.bankName = bank.bank_name
                    
                        // Handle optional properties
                    if let logoBase64 = bank.logo, let logoData = Data(base64Encoded: logoBase64) {
                        bankEntity.logo = logoData
                    }
                    bankEntity.primaryColor = bank.primary_color
                    
                        // Save accounts for this bank
                    for account in bank.accounts {
                        let accountEntity = AccountEntity(context: context)
                        self.configureAccountEntity(accountEntity, with: account)
                        accountEntity.bank = bankEntity
                    }
                }
            }
            
                // Save context
            do {
                try context.save()
                Logger.i("Successfully saved \(banks.count) banks to CoreData")
            } catch {
                Logger.e("Failed to save banks to CoreData: \(error)")
            }
        }
    }
    
    func removeBank(withId bankId: Int) {
        let context = coreDataStack.newBackgroundContext()
        context.perform {
            let fetchRequest: NSFetchRequest<BankEntity> = BankEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %d", Int64(bankId))
            
            do {
                let results = try context.fetch(fetchRequest)
                if let bankToRemove = results.first {
                    // This will cascade delete associated accounts
                    context.delete(bankToRemove)
                    try context.save()
                    Logger.i("Successfully removed bank with ID \(bankId) from CoreData")
                } else {
                    Logger.w("Bank with ID \(bankId) not found in CoreData")
                }
            } catch {
                Logger.e("Failed to remove bank from CoreData: \(error)")
            }
        }
    }
    
    func fetchBanks() -> [Bank] {
        let context = coreDataStack.viewContext
        let fetchRequest: NSFetchRequest<BankEntity> = BankEntity.fetchRequest()
        
        do {
            let bankEntities = try context.fetch(fetchRequest)
            return bankEntities.map { self.mapBankEntityToBank($0) }
        } catch {
            Logger.e("Failed to fetch banks from CoreData: \(error)")
            return []
        }
    }
    
        // Helper methods
    private func updateBankEntity(_ bankEntity: BankEntity, with bank: Bank, in context: NSManagedObjectContext) {
        bankEntity.bankName = bank.bank_name
        
        if let logoBase64 = bank.logo, let logoData = Data(base64Encoded: logoBase64) {
            bankEntity.logo = logoData
        }
        bankEntity.primaryColor = bank.primary_color
        
            // Update accounts
            // This is more complex and would require comparing existing accounts with new ones
            // For simplicity, we're just adding new accounts here
        for account in bank.accounts {
                // Check if account already exists
            if let accounts = bankEntity.accounts as? Set<AccountEntity>,
               !accounts.contains(where: { $0.id == Int64(account.id) }) {
                let accountEntity = AccountEntity(context: context)
                configureAccountEntity(accountEntity, with: account)
                accountEntity.bank = bankEntity
            }
        }
    }
    
    private func configureAccountEntity(_ accountEntity: AccountEntity, with account: BankAccount) {
        accountEntity.id = Int64(account.id)
        accountEntity.name = account.name
        accountEntity.currentBalance = account.current_balance
        accountEntity.isoCurrencyCode = account.iso_currency_code
        accountEntity.type = account._type
        accountEntity.updatedAt = accountEntity.updatedAt ?? Date()
        
        accountEntity.mask = account.mask
        accountEntity.officialName = account.official_name
    }
    
    private func mapBankEntityToBank(_ bankEntity: BankEntity) -> Bank {
        let accounts = (bankEntity.accounts as? Set<AccountEntity> ?? []).map { accountEntity -> BankAccount in
            return BankAccount(
                id: Int(accountEntity.id),
                name: accountEntity.name ?? "",
                mask: accountEntity.mask,
                official_name: accountEntity.officialName,
                current_balance: accountEntity.currentBalance,
                iso_currency_code: accountEntity.isoCurrencyCode ?? "USD",
                _type: accountEntity.type ?? "unknown",
                updated_at: accountEntity.updatedAt ?? Date()
            )
        }
        
        return Bank(
            id: Int(bankEntity.id),
            bank_name: bankEntity.bankName ?? "",
            logo: bankEntity.logo?.base64EncodedString(),
            primary_color: bankEntity.primaryColor,
            accounts: accounts
        )
    }
}
