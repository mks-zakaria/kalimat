# Data schema

No SQL database: content ships as JSON, state is a local JSON document.

## content/clues.csv (authoring source, not shipped)

| column | type | rule |
| --- | --- | --- |
| id | string | unique, e.g. `c0001` |
| answer | Arabic text | normalised by the generator; 2–9 letters after normalisation |
| clue_ar | Arabic text | ≤ 90 chars; unique across the sheet |
| category | enum | `general, religion, geography, flags, sport, science, language, gulf, food, history` |
| region | enum | `gulf, general` |
| difficulty | 1–3 | |
| image | string? | asset name for picture clues |
| source | string | URL or book for the fact / image licence |
| reviewed_by | string | **required** — rows without it are skipped |
| reviewed_at | date | |

## Resources/Packs/<pack_id>.json (shipped, read-only)

```json
{
  "id": "gulf-1",
  "title_ar": "الخليج ١",
  "order": 1,
  "region": "gulf",
  "levels": [
    {
      "id": "gulf-1-001",
      "number": 1,
      "width": 7,
      "height": 6,
      "entries": [
        { "id": "c0001", "answer": "دبي", "row": 0, "col": 0, "dir": "across",
          "clue_ar": "...", "image": null, "category": "gulf", "difficulty": 1 }
      ]
    }
  ]
}
```
`col` 0 is the **rightmost** column. `across` runs right→left, `down` top→bottom.

## progress.json (Application Support; mirrored to iCloud KVS key `p1`)

```json
{
  "version": 1,
  "updated_at": "2026-11-20T10:05:00Z",
  "current_level_id": "gulf-1-004",
  "levels": {
    "gulf-1-001": { "filled": {"0,0": "د"}, "solved": ["c0001"],
                    "hints_used": 1, "stars": 2, "completed_at": "2026-11-20T10:00:00Z" }
  },
  "coins": 140,
  "processed_transactions": ["2000000123456789"],
  "settings": { "sound": true, "haptics": true, "font_scale": 1.0 }
}
```
Merge rule (device vs iCloud): per level, keep the one with more `solved`;
coins = value from the newer `updated_at`; `processed_transactions` = union.
`ads_removed` is never stored — always read from `Transaction.currentEntitlements`.
