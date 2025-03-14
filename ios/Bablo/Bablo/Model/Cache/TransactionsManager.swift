import CoreData
import Foundation

class TransactionsManager {
    private let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack = .shared) {
        self.coreDataStack = coreDataStack
    }
    
    func saveTransactions(_ transactions: [Transaction], for accountId: Int) {
        let context = coreDataStack.newBackgroundContext()
        
        context.perform {
                // Find the account entity
            let accountFetchRequest: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
            accountFetchRequest.predicate = NSPredicate(format: "id == %d", accountId)
            
            guard let accountEntity = try? context.fetch(accountFetchRequest).first else {
                Logger.e("Could not find account with ID \(accountId)")
                return
            }
            
                // Fetch existing transactions for this account to avoid duplicates
            let transactionFetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
            transactionFetchRequest.predicate = NSPredicate(format: "accountId == %d", accountId)
            let existingTransactions = try? context.fetch(transactionFetchRequest)
            
            for transaction in transactions {
                    // Check if transaction already exists (using transaction_id as unique identifier)
                if let existingTransaction = existingTransactions?.first(where: { $0.transactionId == transaction.transaction_id }) {
                        // Update existing transaction
                    self.updateTransactionEntity(existingTransaction, with: transaction)
                } else {
                        // Create new transaction entity
                    let transactionEntity = TransactionEntity(context: context)
                    self.configureTransactionEntity(transactionEntity, with: transaction)
                    transactionEntity.account = accountEntity
                }
            }
            
                // Save context
            do {
                try context.save()
                Logger.i("Successfully saved \(transactions.count) transactions to CoreData for account \(accountId)")
            } catch {
                Logger.e("Failed to save transactions to CoreData: \(error)")
            }
        }
    }
    
    func fetchTransactions(for accountId: Int) -> [Transaction] {
        let context = coreDataStack.viewContext
        let fetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "accountId == %d", accountId)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            let transactionEntities = try context.fetch(fetchRequest)
            return transactionEntities.map { self.mapTransactionEntityToTransaction($0) }
        } catch {
            Logger.e("Failed to fetch transactions from CoreData: \(error)")
            return []
        }
    }
    
    func fetchRecentTransactions(limit: Int = 10) -> [Transaction] {
        let context = coreDataStack.viewContext
        let fetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = limit
        
        do {
            let transactionEntities = try context.fetch(fetchRequest)
            return transactionEntities.map { self.mapTransactionEntityToTransaction($0) }
        } catch {
            Logger.e("Failed to fetch recent transactions from CoreData: \(error)")
            return []
        }
    }
    
        // Helper methods
    private func configureTransactionEntity(_ entity: TransactionEntity, with transaction: Transaction) {
            // Required fields
        entity.accountId = Int64(transaction.account_id)
        entity.amount = transaction.amount
        entity.isoCurrencyCode = transaction.iso_currency_code
        entity.name = transaction.name
        entity.paymentChannel = transaction.payment_channel
        entity.transactionId = transaction.transaction_id
        entity.pending = transaction.pending
        
            // Optional fields
        if let id = transaction.id {
            entity.id = Int64(id)
        }
        entity.userId = transaction.user_id != nil ? Int64(transaction.user_id!) : 0
        entity.merchantName = transaction.merchant_name
        entity.logoUrl = transaction.logo_url
        entity.website = transaction.website
        entity.personalFinanceCategory = transaction.personal_finance_category
        entity.personalFinanceSubcategory = transaction.personal_finance_subcategory
        entity.pendingTransactionId = transaction.pending_transaction_transaction_id
        
            // Date conversions
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = dateFormatter.date(from: transaction.date) {
            entity.date = date
        } else {
            entity.date = Date()
            Logger.w("Could not parse transaction date: \(transaction.date)")
        }
        
        if let authorizedDateString = transaction.authorized_date,
           let authorizedDate = dateFormatter.date(from: authorizedDateString) {
            entity.authorizedDate = authorizedDate
        }
        
        entity.createdAt = transaction.created_at
        entity.updatedAt = transaction.updated_at
    }
    
    private func updateTransactionEntity(_ entity: TransactionEntity, with transaction: Transaction) {
            // Update fields that might change
        entity.amount = transaction.amount
        entity.pending = transaction.pending
        entity.merchantName = transaction.merchant_name
        entity.personalFinanceCategory = transaction.personal_finance_category
        entity.personalFinanceSubcategory = transaction.personal_finance_subcategory
        
            // Update the date if it's changed
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = dateFormatter.date(from: transaction.date) {
            entity.date = date
        }
        
        if let authorizedDateString = transaction.authorized_date,
           let authorizedDate = dateFormatter.date(from: authorizedDateString) {
            entity.authorizedDate = authorizedDate
        }
        
        entity.createdAt = transaction.created_at
        entity.updatedAt = transaction.updated_at
    }
    
    private func mapTransactionEntityToTransaction(_ entity: TransactionEntity) -> Transaction {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let dateString = entity.date != nil ? dateFormatter.string(from: entity.date!) : dateFormatter.string(from: Date())
        let authorizedDateString = entity.authorizedDate != nil ? dateFormatter.string(from: entity.authorizedDate!) : nil
        
        return Transaction(
            id: Int32(entity.id),
            account_id: Int32(entity.accountId),
            user_id: Int32(entity.userId),
            amount: entity.amount,
            iso_currency_code: entity.isoCurrencyCode ?? "USD",
            date: dateString,
            authorized_date: authorizedDateString,
            name: entity.name ?? "",
            merchant_name: entity.merchantName,
            logo_url: entity.logoUrl,
            website: entity.website,
            payment_channel: entity.paymentChannel ?? "",
            transaction_id: entity.transactionId ?? "",
            personal_finance_category: entity.personalFinanceCategory,
            personal_finance_subcategory: entity.personalFinanceSubcategory,
            pending: entity.pending,
            pending_transaction_transaction_id: entity.pendingTransactionId,
            created_at: entity.createdAt,
            updated_at: entity.updatedAt
        )
    }
}
