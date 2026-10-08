# Entity Duplicate Comparison UI

Extend the import wizard's duplicate resolution to show expandable comparison cards for all entity types, not just dives.

## Problem

When the import wizard detects duplicate non-dive entities (sites, buddies, trips, etc.), they appear as simple rows with a Skip/Import toggle but no way to compare existing vs incoming data. Users can't verify whether the detected duplicate is actually the same entity before deciding to skip or import.

Dives already have `DuplicateActionCard` with an expandable `DiveComparisonCard` showing profile overlays, same/diff field analysis, and action buttons. Non-dive entities need a similar (but simpler) comparison experience.

## Goals

1. All duplicate entities show expandable comparison cards in the review step.
2. Expanded view shows existing vs incoming data in a simple two-column layout.
3. The duplicate checker stores which existing entity matched, not just that a match was found.
4. Dives retain their existing comparison UI (profile chart, scored matching).

## Non-Goals

- Same/diff field classification with tolerance matching for non-dive entities. Just show both values side by side.
- Scoring for non-dive entities. Name-based matching is sufficient.

## Data Model

### EntityMatchResult

New class alongside `DiveMatchResult`:

```dart
class EntityMatchResult {
  final String existingId;
  final String existingName;
  final Map<String, String?> existingFields;
  final Map<String, String?> incomingFields;

  const EntityMatchResult({
    required this.existingId,
    required this.existingName,
    required this.existingFields,
    required this.incomingFields,
  });
}
```

Fields are pre-formatted display strings keyed by human-readable labels (e.g., `{'Location': '25.0N, -80.1W', 'Max Depth': '30m'}`). The UI renders them directly without needing to know entity-specific field types.

### Per-Entity Comparison Fields

| Entity | Fields |
|--------|--------|
| Site | Name, Location (lat/lon), Max Depth, Country, Region |
| Buddy | Name, Email, Phone |
| Trip | Name, Start Date, End Date, Location |
| Equipment | Name, Type, Brand, Model, Serial |
| Dive Center | Name, Location, Phone, Email |
| Certification | Agency, Level, Date |
| Tag | Name |
| Dive Type | Name |
| Course | Name, Agency |
| Equipment Set | Name |

### EntityGroup Changes

Add `entityMatches` alongside existing `matchResults`:

```dart
class EntityGroup {
  final List<EntityItem> items;
  final Set<int> duplicateIndices;
  final Map<int, DiveMatchResult>? matchResults;     // dives only
  final Map<int, EntityMatchResult>? entityMatches;   // non-dive entities
}
```

## Duplicate Checker Changes

### ImportDuplicateChecker

Currently returns `ImportDuplicateResult` with `Map<ImportEntityType, Set<int>> duplicates` (indices only). Extend to also return match results:

```dart
class ImportDuplicateResult {
  final Map<ImportEntityType, Set<int>> duplicates;
  final Map<int, DiveMatchResult> diveMatches;
  final Map<ImportEntityType, Map<int, EntityMatchResult>> entityMatches; // NEW
}
```

Each duplicate detection method (`_checkNameDuplicates`, `_checkSiteDuplicates`, etc.) returns not just indices but also the matched existing entity's fields. The checker extracts display fields from both the import data map and the existing entity at detection time.

### UddfDuplicateChecker

Same changes — add `entityMatches` to its result type and populate during detection.

## UI Changes

### EntityDuplicateCard

New widget replacing `_SimpleDuplicateRow`. Structure mirrors `DuplicateActionCard`:

**Collapsed state:**
- Entity name (title) + subtitle
- SKIP / IMPORT badge
- Expand/collapse chevron

**Expanded state:**
- Two-column comparison table:
  - Column headers: "Existing" and "Incoming"
  - One row per field from `EntityMatchResult.existingFields` / `incomingFields`
  - Values that differ are highlighted; matching values are dimmed
- Skip / Import as New action buttons

### EntityReviewList Changes

Replace `_buildSimpleDuplicateRow` with `EntityDuplicateCard`, passing the `EntityMatchResult` from `group.entityMatches`.

### Dive Cards Unchanged

`DuplicateActionCard` + `DiveComparisonCard` remain as-is for dives. The profile chart, scored matching, and consolidate action are dive-specific.

## Adapter Changes

### UniversalAdapter.checkDuplicates

After calling `checker.check()`, map the returned `entityMatches` onto `EntityGroup.entityMatches` for each non-dive entity type.

### UddfAdapter.checkDuplicates

Same pattern.

## Testing

- Unit tests: `EntityMatchResult` creation and field extraction for each entity type.
- Widget tests: `EntityDuplicateCard` renders collapsed/expanded states, shows correct fields.
- Integration: duplicate detection populates `entityMatches` with correct existing entity data.
