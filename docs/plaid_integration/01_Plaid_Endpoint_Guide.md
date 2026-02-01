## 1. Understanding Plaid's Recurring Transactions Endpoint

Based on the official documentation:

**Key Features:**
- Automatically identifies recurring inflow (income) and outflow (expenses) streams
- Analyzes transactions based on description, amount, and cadence
- "Matured" streams require 3+ occurrences for high confidence
- Early detection available for streams with <3 occurrences
- Optimal results with 180+ days of transaction history

**Response Structure:**
```typescript
{
  inflow_streams: [/* recurring income */],
  outflow_streams: [/* recurring expenses */],
}
```

**Each Stream Contains:**
- `stream_id`: Unique identifier from Plaid
- `account_id`: Account this stream belongs to
- `description` / `merchant_name`: Transaction descriptor
- `personal_finance_category`: Object with `primary`, `detailed`, and `confidence_level`
- `frequency`: Cadence (WEEKLY, SEMI_MONTHLY, MONTHLY, ANNUALLY)
- `average_amount`: Object with `amount`, `iso_currency_code`, `unofficial_currency_code`
- `last_amount`: Same structure as average_amount
- `first_date`, `last_date`, `predicted_next_date`: Date strings (YYYY-MM-DD)
- `status`: Stream maturity ("MATURE" or potentially other values)
- `is_active`: Boolean indicating if stream is still active
- `is_user_modified`: Boolean indicating if user modified the stream
- `transaction_ids`: Array of Plaid transaction IDs in this stream
