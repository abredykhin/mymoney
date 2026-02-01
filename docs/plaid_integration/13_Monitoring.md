## 13. Monitoring & Observability

### Key Metrics to Track:
1. **Sync Performance**
   - Average sync-recurring-transactions execution time
   - Number of streams detected per sync
   - Error rate

2. **User Engagement**
   - % of users who override at least one stream
   - Average overrides per user
   - Most commonly overridden categories

3. **Accuracy**
   - Compare Plaid stream count vs previous Gemini pattern count
   - Track user feedback on budget accuracy
   - Monitor support tickets related to recurring transactions

### Logging:
```typescript
console.log(`🔄 Recurring sync started for user: ${userId}`);
console.log(`📊 Plaid returned ${inflow_streams.length} income streams, ${outflow_streams.length} expense streams`);
console.log(`✅ Synced ${allStreams.length} streams, updated ${transactionCount} transaction flags`);
console.log(`👤 User has ${overrideCount} manual overrides`);
```
