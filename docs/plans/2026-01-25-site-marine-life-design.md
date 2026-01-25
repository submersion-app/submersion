# Common Marine Life for Dive Sites - Design Document

**Date**: 2026-01-25
**Status**: Approved
**Feature**: Link species to dive sites

## Overview

Add the ability to see what marine life is commonly found at each dive site. This includes both:
1. **Derived sightings** - Automatically aggregated from actual dive logs at the site
2. **Expected species** - Manually curated list of species you expect to see

## Data Model

### New Table: `site_species`

Junction table for manually curated expected species at each site.

```sql
CREATE TABLE site_species (
  id TEXT PRIMARY KEY,
  site_id TEXT NOT NULL REFERENCES dive_sites(id) ON DELETE CASCADE,
  species_id TEXT NOT NULL REFERENCES species(id) ON DELETE CASCADE,
  notes TEXT DEFAULT '',
  created_at INTEGER NOT NULL
);

CREATE INDEX idx_site_species_site ON site_species(site_id);
```

### New Domain Entity: `SiteSpeciesSummary`

Represents aggregated sighting data for a species at a site.

```dart
class SiteSpeciesSummary {
  final String speciesId;
  final String speciesName;
  final SpeciesCategory category;
  final int sightingCount;  // Total times spotted across all dives at site
  final int diveCount;      // Number of dives where spotted
}
```

## Repository Methods

Add to `SpeciesRepository`:

```dart
// Derived sightings - aggregate from actual dives at site
Future<List<SiteSpeciesSummary>> getSpeciesSpottedAtSite(String siteId);

// Manual curation
Future<List<Species>> getExpectedSpeciesForSite(String siteId);
Future<void> addExpectedSpecies(String siteId, String speciesId, {String? notes});
Future<void> removeExpectedSpecies(String siteId, String speciesId);
Future<void> removeAllExpectedSpeciesForSite(String siteId);
```

### SQL Query for Derived Sightings

```sql
SELECT
  sp.id as species_id,
  sp.common_name,
  sp.category,
  COUNT(*) as sighting_count,
  COUNT(DISTINCT d.id) as dive_count
FROM sightings s
JOIN species sp ON s.species_id = sp.id
JOIN dives d ON s.dive_id = d.id
WHERE d.site_id = ?
GROUP BY sp.id
ORDER BY sighting_count DESC, sp.common_name ASC
```

## Riverpod Providers

```dart
// Derived sightings for a site
final siteSpottedSpeciesProvider = FutureProvider.family<List<SiteSpeciesSummary>, String>

// Expected species for a site
final siteExpectedSpeciesProvider = FutureProvider.family<List<Species>, String>

// Notifier for managing expected species
final siteExpectedSpeciesNotifierProvider = AsyncNotifierProvider.family<...>
```

## UI Components

### 1. Site Marine Life Section (`site_marine_life_section.dart`)

Displays on the Site Detail Page after the Depth Range section.

**Structure**:
- Section header: "Marine Life" with fish icon
- Two subsections:
  - "Spotted Here" - chips with species name + count badge
  - "Expected Species" - chips with edit button in header
- Grouped by category (Fish, Sharks, Rays, etc.)
- Tapping chip shows species details in bottom sheet

**Empty States**:
- "No marine life spotted yet" when no sightings
- "No expected species added" when manual list empty
- Combined: "Log a dive here or add expected species"

### 2. Species Picker Dialog (`species_picker_dialog.dart`)

Modal for adding/removing expected species.

**Features**:
- Search box for filtering species
- Category tabs or grouped list
- Checkboxes for multi-select
- Shows currently selected species
- "Add New Species" option if not found

### 3. Site Edit Page Integration

Add "Expected Marine Life" section to site edit form:
- Uses same `SpeciesPickerDialog`
- Shows selected species as chips with remove button
- "Add Species" button to open picker

## File Changes

| File | Action | Purpose |
|------|--------|---------|
| `lib/core/database/database.dart` | Modify | Add `SiteSpecies` table + migration v18 |
| `lib/features/marine_life/domain/entities/species.dart` | Modify | Add `SiteSpeciesSummary` entity |
| `lib/features/marine_life/data/repositories/species_repository.dart` | Modify | Add site-species methods |
| `lib/features/marine_life/presentation/providers/species_providers.dart` | Modify | Add site providers |
| `lib/features/dive_sites/presentation/pages/site_detail_page.dart` | Modify | Add section |
| `lib/features/dive_sites/presentation/pages/site_edit_page.dart` | Modify | Add picker |
| `lib/features/marine_life/presentation/widgets/site_marine_life_section.dart` | Create | Section widget |
| `lib/features/marine_life/presentation/widgets/species_picker_dialog.dart` | Create | Picker modal |

## Implementation Order

1. Database schema + migration (v18)
2. Domain entity (`SiteSpeciesSummary`)
3. Repository methods
4. Riverpod providers
5. UI: `SiteMarineLifeSection` widget
6. UI: `SpeciesPickerDialog` widget
7. Integrate into `SiteDetailPage`
8. Integrate into `SiteEditPage`
9. Tests

## Sync Considerations

The `site_species` table needs sync support:
- Add to sync entity types
- Track in `sync_records` table
- Include in deletion log
