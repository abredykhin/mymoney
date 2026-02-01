## 16. Future Enhancements (Phase 2)

After validating the MVP implementation, consider these sophisticated enhancements:

### 16.1 Advanced Pattern Matching

**Replace simple `match_pattern` TEXT with structured `matching_rules` JSONB:**

```sql
ALTER TABLE recurring_streams_table
ADD COLUMN matching_rules JSONB DEFAULT '{ 
  "merchant_pattern": "",
  "amount_min": 0,
  "amount_max": 999999,
  "category": null,
  "match_strategy": "fuzzy"
}'::jsonb;
```

**Benefits:**
- **Flexible Amount Ranges**: Handle price increases (Netflix $14.99 → $15.99)
- **Fuzzy Matching**: Match "NETFLIX.COM" vs "Netflix Inc" vs "NFLX"
- **Category Filtering**: Avoid false positives from different categories
- **Match Strategy Options**: Exact, substring, fuzzy, or regex

**Example Fuzzy Matching Algorithm:**

```typescript
function matchesPattern(tx: Transaction, rules: MatchingRules): boolean {
  // Use Levenshtein distance or similar
  const nameSimilarity = calculateSimilarity(
    tx.merchant_name || tx.name,
    rules.merchant_pattern
  );

  const amountInRange = 
    tx.amount >= rules.amount_min &&
    tx.amount <= rules.amount_max;

  const categoryMatch = 
    !rules.category || 
    tx.personal_finance_category === rules.category;

  return nameSimilarity >= 0.85 && amountInRange && categoryMatch;
}
```

### 16.2 Conflict Resolution: Plaid Detection Upgrade

**Problem:** User creates manual stream, then Plaid starts detecting it

**Solution:** Auto-upgrade manual streams when Plaid detects them

```typescript
async function detectAndUpgradeManualStreams(supabase: any, userId: string) {
  // For each Plaid stream, check if a similar manual stream exists
  const plaidStreams = await getPlaidStreams(userId);
  const manualStreams = await getManualStreams(userId);

  for (const plaidStream of plaidStreams) {
    for (const manualStream of manualStreams) {
      const similarity = compareSimilarity(plaidStream, manualStream);

      if (similarity > 0.9) {
        // Found a match - upgrade the manual stream
        await supabase
          .from('recurring_streams_table')
          .update({
            is_manual: false,
            plaid_stream_id: plaidStream.stream_id,
            superseded_at: new Date().toISOString(),
            status: 'upgraded_from_manual'
          })
          .eq('id', manualStream.id);

        // Notify user: "Plaid now detects this pattern automatically ✓"
        await sendNotification(userId, {
          type: 'stream_upgraded',
          message: `${manualStream.description} is now automatically detected by Plaid`
        });
      }
    }
  }
}
```

### 16.3 User Preview Before Creating Manual Stream

Show users what will be matched before confirming:

```swift
struct ManualStreamPreviewView: View {
    let transaction: Transaction
    let frequency: String
    @State private var previewResults: PreviewResults?

    var body: some View {
        List {
            Section("Pattern") {
                Text("Match: \"\(extractedPattern)\"")
                Text("Frequency: \(frequency.capitalized)")
            }

            Section {
                if let results = previewResults {
                    Text("Found \(results.matchedCount) matching transactions")

                    ForEach(results.samples) { tx in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(tx.name)
                                Text(tx.date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("$\(tx.amount, specifier: \"%.2f\")")
                        }
                    }

                    if results.hasOutliers {
                        Text("⚠️ Some transactions have different amounts")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
            } header: {
                Text("Matching Transactions")
            }

            Section {
                Button("Create Recurring Stream") {
                    confirmAndCreate()
                }
                .disabled(previewResults == nil)
            }
        }
        .task {
            previewResults = await fetchPreview()
        }
    }
}
```

### 16.4 Smart Amount Tolerance

Automatically adjust amount ranges based on historical variance:

```typescript
function calculateAmountTolerance(transactions: Transaction[]): [number, number] {
  const amounts = transactions.map(tx => tx.amount);
  const mean = amounts.reduce((a, b) => a + b) / amounts.length;
  const stdDev = calculateStdDev(amounts);

  // Allow 2 standard deviations (covers 95% of normal distribution)
  const tolerance = stdDev * 2;

  return [
    Math.max(0, mean - tolerance),
    mean + tolerance
  ];
}
```

### 16.5 Duplicate Prevention

Prevent users from creating multiple manual streams for the same pattern:

```typescript
async function checkForDuplicates(
  pattern: string,
  userId: string
): Promise<{ isDuplicate: boolean; existingStream?: Stream }> {

  const existingStreams = await supabase
    .from('recurring_streams_table')
    .select('*')
    .eq('user_id', userId)
    .or(`match_pattern.ilike.%${pattern}%,plaid_stream_id.not.is.null`);

  for (const stream of existingStreams) {
    const similarity = calculateSimilarity(stream.description, pattern);
    if (similarity > 0.85) {
      return { isDuplicate: true, existingStream: stream };
    }
  }

  return { isDuplicate: false };
}
```

### 16.6 Edit Manual Stream Pattern

Allow users to refine the matching pattern:

```swift
func updateManualStreamPattern(streamId: Int, newPattern: String) async throws {
    try await supabase
        .from("recurring_streams_table")
        .update(["match_pattern": newPattern])
        .eq("id", value: streamId)
        .eq("is_manual", value: true)
        .execute()

    // Re-run matcher to update linked transactions
    try await syncRecurringTransactions()
}
```

### 16.7 Orphaned Transaction Handling

When a manual stream is deleted, ensure transactions are properly unmarked:

```typescript
async function deleteManualStream(streamId: number, userId: string) {
  // 1. Get all linked transactions
  const { data: links } = await supabase
    .from('recurring_stream_transactions_table')
    .select('transaction_id')
    .eq('stream_id', streamId);

  // 2. Delete the stream (cascade will delete junction records)
  await supabase
    .from('recurring_streams_table')
    .delete()
    .eq('id', streamId)
    .eq('user_id', userId);

  // 3. Update transaction flags for affected transactions
  if (links && links.length > 0) {
    const txIds = links.map(l => l.transaction_id);
    await supabase
      .from('transactions_table')
      .update({ is_recurring: false })
      .in('id', txIds);
  }

  // 4. Recalculate budget
  await updateProfileRecurringSummary(supabase, userId);
}
```

### Implementation Priority

1. **Phase 1 (MVP)** - Shipped in initial release:
   - Simple text pattern matching
   - Manual stream CRUD operations
   - Basic UI for marking transactions

2. **Phase 2a** - First enhancement (2-4 weeks after launch):
   - Fuzzy matching algorithm
   - Preview before creating
   - Duplicate prevention

3. **Phase 2b** - Second enhancement (1-2 months after launch):
   - JSONB matching rules
   - Amount tolerance calculation
   - Conflict resolution with Plaid

4. **Phase 2c** - Polish (3+ months after launch):
   - Edit pattern functionality
   - Advanced analytics on manual vs Plaid accuracy
   - ML-powered pattern suggestions

