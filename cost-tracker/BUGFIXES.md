# Cost Tracker — Bug Fixes (2026-03-09)

## Bug 1: Random IDs → Massive Duplicates

**Problem:**
- ID generation using `Math.random().toString(36).substr(2, 9)` produced a different ID on each run
- Cache deduplication never worked (new ID ≠ old ID)
- Result: 21,848 entries accumulating, false monthly projection of ~$1,389/mo

**Root Cause:**
In `api-cost-tracker.js`, IDs were random per execution:
```javascript
// ❌ WRONG
const id = Math.random().toString(36).substr(2, 9);
// Example: "1773084823123-chappie-4zo2fcwk3"
```

**Solution:**
Generate deterministic IDs from request data:
```javascript
// ✅ CORRECT
const id = `${agent}-${fileHash}-L${lineIdx}`;
// Example: "chappie-b6547ed8-b31c-41db-a915-a0b670da93de.jsonl-L218"
```

**Key Learning:**
- Cache deduplication **only works with stable IDs**
- If you change ID format, you **must clean the cache** before next run
- Test deduplication by checking if the same request produces the same ID twice

---

## Bug 2: Per-Refresh Accumulation (TTL Cache)

**Problem:**
- Each API request to `/api/cost-tracker` re-aggregated all JSONL files into cache without TTL
- Refreshing the dashboard repeatedly grew costs artifactually
- Cache was never invalidated

**Root Cause:**
In `server.js`, metrics were computed fresh per request with no expiry:
```javascript
// ❌ WRONG
app.get('/api/cost-tracker', (req, res) => {
  const metrics = computeMetrics(); // No TTL, always recompute
  res.json(metrics);
});
```

**Solution:**
Add TTL cache with manual refresh:
```javascript
// ✅ CORRECT
const COST_METRICS_TTL_MS = 5 * 60 * 1000; // 5 minutes
let cachedMetrics = null;
let cacheTimestamp = 0;

app.get('/api/cost-tracker', (req, res) => {
  const now = Date.now();
  const isExpired = now - cacheTimestamp > COST_METRICS_TTL_MS;
  const forceRefresh = req.query.refresh === '1';
  
  if (!cachedMetrics || isExpired || forceRefresh) {
    cachedMetrics = computeMetrics();
    cacheTimestamp = now;
  }
  
  res.json(cachedMetrics);
});
```

**Key Learning:**
- Dashboard refreshes should **not recompute all metrics**
- Use TTL cache (5–15 min typical) to prevent artifactual growth
- Provide `?refresh=1` query param for manual cache invalidation
- Monitor cache hit rates to ensure patterns are working

---

## Bug 3: Cache Contamination (Format Migration)

**Problem:**
- After fixing ID format, `api-cost-requests.json` contained both old and new formats:
  - 5,750 old-format entries: `1773084823123-chappie-4zo2fcwk3`
  - 325 new-format entries: `chappie-b6547ed8-b31c-41db-a915-a0b670da93de.jsonl-L218`
- Deduplication couldn't match across formats → 6,048 total entries, false $441/mo projection

**Root Cause:**
Upgrading the ID generation didn't clean the old cache entries. Both formats coexisted and were treated as separate records.

**Solution:**
1. Clear the cache file:
```bash
echo '[]' > ~/.openclaw/cache/api-cost-requests.json
```

2. Force regeneration:
```bash
curl "http://YOUR_PI_IP:8080/api/cost-tracker?refresh=1"
```

3. Verify deduplication:
```bash
# Count entries in cache
jq '. | length' ~/.openclaw/cache/api-cost-requests.json
# Before: 6,048
# After: 333 (actual data)
```

**Result Post-Cleanup:**
- 333 entries (actual data)
- $0.96 total cost
- ~$29/mo projected (realistic, not $441)

**Key Learning:**
- **When changing ID format, always clean cache before first execution**
- Old format + new format = deduplication failure
- A "cleanup" function is worth adding to dashboards for migrations
- Test that monthly projection moves closer to actual spend post-cleanup

---

## Feature: Confidence Disclaimers (3 Levels)

**Problem:**
- Monthly projections based on <1 day of history were equally "confident" as projections from weeks
- Users couldn't judge reliability of the forecast

**Solution:**
Add `data_span_days` and `data_confidence` fields to metrics:

```javascript
{
  "total_cost": 0.96,
  "data_span_days": 0.5,
  "data_confidence": "low",
  "projected_monthly": 29.00,
  "confidence_message": "⚠️ Low confidence — only 0.5 days of data. Monitor for 7+ days for reliable projections."
}
```

**Confidence Thresholds:**
- `< 2 days` → **low** ⚠️ — "Still gathering data"
- `2–7 days` → **medium** 📊 — "Moderate confidence"
- `7+ days` → **high** ✅ — "Reliable projection"

**Dashboard Banner:**
```html
<div class="confidence-banner">
  ⚠️ Confidence: Low (0.5 days of history)
  <br/>
  Monitor for 7+ days for reliable monthly estimates.
</div>
```

**Key Learning:**
- Projections need **temporal context** to be meaningful
- Users should know how much historical data backs the forecast
- This prevents false confidence in early-stage deployments

---

## Summary

| Bug | Impact | Root Cause | Fix | Confidence |
|-----|--------|-----------|-----|------------|
| Random IDs | 21,848 dupes | ID uniqueness per run | Deterministic ID from data | 100% |
| TTL Cache | Accumulation per refresh | No cache expiry | 5-min TTL + manual refresh | 100% |
| Format Migration | 5,750 orphaned entries | Old cache not cleaned | `echo '[]'` + regenerate | 100% |
| Confidence | Misleading projections | No temporal context | `data_span_days` + disclaimer | ✅ Shipped |

