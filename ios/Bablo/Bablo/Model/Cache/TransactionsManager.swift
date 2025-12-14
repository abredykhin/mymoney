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
    
    // New method to support paginated fetching from cache
    func fetchPaginatedTransactions(limit: Int = 50, offset: Int = 0) -> [Transaction] {
        let context = coreDataStack.viewContext
        let fetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = limit
        fetchRequest.fetchOffset = offset
        
        do {
            let transactionEntities = try context.fetch(fetchRequest)
            return transactionEntities.map { self.mapTransactionEntityToTransaction($0) }
        } catch {
            Logger.e("Failed to fetch paginated transactions from CoreData: \(error)")
            return []
        }
    }
    
    // New method to support paginated fetching from cache for a specific account
    func fetchPaginatedTransactions(for accountId: Int, limit: Int = 50, offset: Int = 0) -> [Transaction] {
        let context = coreDataStack.viewContext
        let fetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "accountId == %d", accountId)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = limit
        fetchRequest.fetchOffset = offset
        
        do {
            let transactionEntities = try context.fetch(fetchRequest)
            return transactionEntities.map { self.mapTransactionEntityToTransaction($0) }
        } catch {
            Logger.e("Failed to fetch paginated transactions for account from CoreData: \(error)")
            return []
        }
    }
    
        // Helper methods
    private func configureTransactionEntity(_ entity: TransactionEntity, with transaction: Transaction) {
            // Required fields
        entity.id = Int64(transaction.id)
        entity.accountId = Int64(transaction.account_id)
        entity.amount = transaction.amount
        entity.isoCurrencyCode = transaction.iso_currency_code
        entity.name = transaction.name
        entity.paymentChannel = transaction.payment_channel
        entity.transactionId = transaction.transaction_id
        entity.pending = transaction.pending

        // Optional fields
        entity.userId = transaction.user_id ?? 0
        entity.merchantName = transaction.merchant_name
        entity.logoUrl = transaction.logo_url
        entity.website = transaction.website
        entity.personalFinanceCategory = transaction.personal_finance_category
        entity.personalFinanceSubcategory = transaction.personal_finance_subcategory
        entity.pendingTransactionId = transaction.pending_transaction_transaction_id

        // Date conversions with improved ISO-8601 support
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Try ISO-8601 format first
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = iso8601Formatter.date(from: transaction.date) {
            entity.date = date
        } else if let date = dateFormatter.date(from: transaction.date) {
            entity.date = date
        } else {
            entity.date = Date()
            Logger.w("Could not parse transaction date: \(transaction.date)")
        }

        if let authorizedDateString = transaction.authorized_date {
            if let authorizedDate = iso8601Formatter.date(from: authorizedDateString) {
                entity.authorizedDate = authorizedDate
            } else if let authorizedDate = dateFormatter.date(from: authorizedDateString) {
                entity.authorizedDate = authorizedDate
            }
        }

        // Parse timestamp strings to Date
        if let createdAtString = transaction.created_at {
            entity.createdAt = iso8601Formatter.date(from: createdAtString)
        }
        if let updatedAtString = transaction.updated_at {
            entity.updatedAt = iso8601Formatter.date(from: updatedAtString)
        }
    }
    
    private func updateTransactionEntity(_ entity: TransactionEntity, with transaction: Transaction) {
            // Update fields that might change
        entity.amount = transaction.amount
        entity.pending = transaction.pending
        entity.merchantName = transaction.merchant_name
        entity.personalFinanceCategory = transaction.personal_finance_category
        entity.personalFinanceSubcategory = transaction.personal_finance_subcategory

            // Update the date if it's changed with improved ISO-8601 support
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Try ISO-8601 format first
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = iso8601Formatter.date(from: transaction.date) {
            entity.date = date
        } else if let date = dateFormatter.date(from: transaction.date) {
            entity.date = date
        }

        if let authorizedDateString = transaction.authorized_date {
            if let authorizedDate = iso8601Formatter.date(from: authorizedDateString) {
                entity.authorizedDate = authorizedDate
            } else if let authorizedDate = dateFormatter.date(from: authorizedDateString) {
                entity.authorizedDate = authorizedDate
            }
        }

        // Parse timestamp strings to Date
        if let createdAtString = transaction.created_at {
            entity.createdAt = iso8601Formatter.date(from: createdAtString)
        }
        if let updatedAtString = transaction.updated_at {
            entity.updatedAt = iso8601Formatter.date(from: updatedAtString)
        }
    }
    
    private func mapTransactionEntityToTransaction(_ entity: TransactionEntity) -> Transaction {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let dateString = entity.date != nil ? dateFormatter.string(from: entity.date!) : dateFormatter.string(from: Date())
        let authorizedDateString = entity.authorizedDate != nil ? dateFormatter.string(from: entity.authorizedDate!) : nil
        let createdAtString = entity.createdAt != nil ? iso8601Formatter.string(from: entity.createdAt!) : nil
        let updatedAtString = entity.updatedAt != nil ? iso8601Formatter.string(from: entity.updatedAt!) : nil

        return Transaction(
            id: Int(entity.id),
            account_id: Int(entity.accountId),
            amount: entity.amount,
            date: dateString,
            authorized_date: authorizedDateString,
            name: entity.name ?? "",
            merchant_name: entity.merchantName,
            pending: entity.pending,
            category: nil, // Category array not stored in CoreData
            transaction_id: entity.transactionId ?? "",
            pending_transaction_transaction_id: entity.pendingTransactionId,
            iso_currency_code: entity.isoCurrencyCode ?? "USD",
            payment_channel: entity.paymentChannel ?? "",
            user_id: entity.userId != 0 ? Int64(entity.userId) : nil,
            logo_url: entity.logoUrl,
            website: entity.website,
            personal_finance_category: entity.personalFinanceCategory,
            personal_finance_subcategory: entity.personalFinanceSubcategory,
            created_at: createdAtString,
            updated_at: updatedAtString
        )
    }
}
