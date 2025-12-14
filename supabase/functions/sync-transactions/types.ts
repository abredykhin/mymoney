/**
 * TypeScript type definitions for sync-transactions Edge Function
 *
 * Defines interfaces for Plaid API responses and database records.
 */

/**
 * Plaid transaction from transactionsSync() API
 */
export interface PlaidTransaction {
  account_id: string;
  amount: number;
  iso_currency_code: string | null;
  date: string;
  authorized_date?: string | null;
  name: string;
  merchant_name?: string | null;
  logo_url?: string | null;
  website?: string | null;
  payment_channel: string;
  transaction_id: string;
  personal_finance_category?: {
    primary: string;
    detailed: string;
  } | null;
  pending: boolean;
  pending_transaction_id?: string | null;
}

/**
 * Removed transaction from Plaid transactionsSync() API
 */
export interface PlaidRemovedTransaction {
  transaction_id: string;
}

/**
 * Account with balances from Plaid accountsGet() API
 */
export interface PlaidAccount {
  account_id: string;
  name: string;
  mask: string;
  official_name?: string;
  balances: {
    available: number | null;
    current: number | null;
    iso_currency_code: string;
    unofficial_currency_code?: string;
  };
  type: string;
  subtype: string;
}

/**
 * Database item record
 */
export interface Item {
  id: number;
  user_id: string;
  plaid_access_token: string;
  transactions_cursor: string | null;
  plaid_item_id: string;
}

/**
 * Request body for sync-transactions Edge Function
 */
export interface SyncRequest {
  plaid_item_id: string;
}

/**
 * Response body for sync-transactions Edge Function
 */
export interface SyncResponse {
  success: boolean;
  message: string;
  plaid_item_id: string;
  stub?: boolean;
  added: number;
  modified: number;
  removed: number;
}

/**
 * Result from fetchTransactionUpdates()
 */
export interface TransactionUpdates {
  added: PlaidTransaction[];
  modified: PlaidTransaction[];
  removed: PlaidRemovedTransaction[];
  nextCursor: string | null;
}
