# Underwater Photography Feature Design

**Date:** 2026-01-25
**Status:** Approved
**Version:** 1.0

## Overview

Add photo/video support to Submersion as a **metadata enrichment layer**, not a digital asset manager. Photos remain in the device's gallery; Submersion stores references and adds dive-specific context (depth, temperature, species tags) that no photo app can provide.

## Design Principles

1. **Reference-only storage** - Never duplicate photo files
2. **Enrichment over management** - Add dive data to photos, don't manage the photos themselves
3. **Graceful degradation** - Handle deleted photos without data loss
4. **Progressive disclosure** - Simple by default, power features available

## Architecture

```
+-------------------------------------------------------------+
|                    Device Photo Library                      |
|  (User manages photos here - Apple Photos, Google Photos)    |
+-------------------------------------------------------------+
                              |
                              | Reference (platform asset ID)
                              v
+-------------------------------------------------------------+
|                    Submersion Database                       |
|  +-------------+    +--------------+    +---------------+   |
|  |   Media     |--->|MediaEnrichment|<---|    Dives      |   |
|  | (reference) |    | (dive data)  |    |   (profile)   |   |
|  +-------------+    +--------------+    +---------------+   |
|         |                                                    |
|         v                                                    |
|  +-------------+                                             |
|  |MediaSpecies |                                             |
|  +-------------+                                             |
+-------------------------------------------------------------+
```

### What Submersion Stores

- Platform asset identifier (not file path)
- Calculated depth, temperature, GPS from dive profile at photo timestamp
- Species tags, captions, favorite flag
- Thumbnail cache (regenerated if lost)

### What Submersion Does NOT Store

- Original photo/video files
- Duplicate copies
- Edit history or filters

## Database Schema

### Modified Media Table

```sql
CREATE TABLE media (
  id TEXT PRIMARY KEY,
  dive_id TEXT REFERENCES dives(id) ON DELETE SET NULL,
  site_id TEXT REFERENCES dive_sites(id) ON DELETE SET NULL,

  -- Reference (replacing filePath for photos from gallery)
  platform_asset_id TEXT,               -- iOS PHAsset.localIdentifier / Android MediaStore ID
  file_path TEXT,                       -- Legacy: for app-created files (signatures)
  original_filename TEXT,               -- For display: "IMG_4523.jpg"
  media_type TEXT NOT NULL DEFAULT 'photo',  -- photo, video, instructor_signature

  -- Cached/extracted metadata (from EXIF on first import)
  taken_at INTEGER,                     -- Unix timestamp from EXIF
  original_latitude REAL,               -- GPS from photo EXIF
  original_longitude REAL,
  width INTEGER,
  height INTEGER,
  duration_seconds INTEGER,             -- For video only

  -- User-entered data
  caption TEXT,
  is_favorite INTEGER NOT NULL DEFAULT 0,

  -- Thumbnail cache path (app documents folder, regenerable)
  thumbnail_path TEXT,
  thumbnail_generated_at INTEGER,

  -- Orphan tracking
  last_verified_at INTEGER,             -- When we last confirmed asset exists
  is_orphaned INTEGER NOT NULL DEFAULT 0,

  -- Signature fields (existing, for instructor signatures)
  signer_id TEXT REFERENCES buddies(id) ON DELETE SET NULL,
  signer_name TEXT,

  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX idx_media_dive ON media(dive_id);
CREATE INDEX idx_media_platform_asset ON media(platform_asset_id);
```

### New Table: Media Enrichment

```sql
CREATE TABLE media_enrichment (
  id TEXT PRIMARY KEY,
  media_id TEXT NOT NULL REFERENCES media(id) ON DELETE CASCADE,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,

  -- Calculated from dive profile at photo timestamp
  depth_meters REAL,                    -- Interpolated from profile
  temperature_celsius REAL,             -- From nearest profile point
  elapsed_seconds INTEGER,              -- Seconds into dive when taken

  -- Confidence/quality
  match_confidence TEXT DEFAULT 'exact', -- exact, interpolated, estimated, no_profile
  timestamp_offset_seconds INTEGER,     -- How far from nearest profile point

  created_at INTEGER NOT NULL,

  UNIQUE(media_id, dive_id)
);

CREATE INDEX idx_media_enrichment_media ON media_enrichment(media_id);
CREATE INDEX idx_media_enrichment_dive ON media_enrichment(dive_id);
```

### New Table: Media Species Tags

```sql
CREATE TABLE media_species (
  id TEXT PRIMARY KEY,
  media_id TEXT NOT NULL REFERENCES media(id) ON DELETE CASCADE,
  species_id TEXT NOT NULL REFERENCES species(id) ON DELETE CASCADE,
  sighting_id TEXT REFERENCES sightings(id) ON DELETE SET NULL,

  -- Reserved for future spatial annotation (nullable for now)
  bbox_x REAL,                          -- 0.0-1.0 normalized coordinates
  bbox_y REAL,
  bbox_width REAL,
  bbox_height REAL,

  notes TEXT,
  created_at INTEGER NOT NULL,

  UNIQUE(media_id, species_id)
);

CREATE INDEX idx_media_species_media ON media_species(media_id);
CREATE INDEX idx_media_species_species ON media_species(species_id);
```

### New Table: Pending Photo Suggestions

```sql
CREATE TABLE pending_photo_suggestions (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  platform_asset_id TEXT NOT NULL,
  taken_at INTEGER NOT NULL,
  thumbnail_path TEXT,
  dismissed INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,

  UNIQUE(dive_id, platform_asset_id)
);

CREATE INDEX idx_pending_suggestions_dive ON pending_photo_suggestions(dive_id);
```

## Timestamp Matching Algorithm

### Matching Process

1. Extract EXIF datetime from photo
2. Find dive with overlapping time window (entry_time to exit_time)
3. Query dive profile for data points around photo timestamp
4. Interpolate depth/temperature at exact photo time

### Match Confidence Levels

| Confidence | Criteria | UI Indicator |
|------------|----------|--------------|
| `exact` | Profile point within 10 seconds | Green checkmark |
| `interpolated` | Between two points < 60 sec apart | No indicator |
| `estimated` | Nearest point > 60 sec away | Yellow "~" prefix |
| `no_profile` | Dive has no profile data | Gray "manual" badge |

### Time Window for Suggestions

- Primary: `[dive_entry_time, dive_exit_time]` - "During this dive"
- Extended: `[dive_entry_time - 2 hours, dive_exit_time + 2 hours]` - "Same day"

## User Flows

### Flow 1: Manual Add Photos

1. User opens dive detail, taps "Add Photos"
2. App requests photo library permission (if not granted)
3. App queries library for photos in dive time window
4. Shows filtered picker with "During dive" and "Same day" sections
5. User selects photos, confirms
6. App creates media records, calculates enrichment
7. Thumbnails generated in background

### Flow 2: Background Scan Suggestions

Triggers:
- New dive logged (imported or manual)
- App opened after 24+ hours

Process:
1. For each dive in last 30 days without photos
2. Query photo library for matching timestamps
3. Store matches in `pending_photo_suggestions`
4. Show badge on dive card: "3 photos found"
5. User taps badge, sees suggestion picker
6. Confirm flow same as manual add

### Flow 3: Optional EXIF Writing

1. User opens photo detail, taps "Write to EXIF"
2. Confirmation dialog shows what will be written
3. App requests write permission (platform-specific)
4. Writes metadata to original photo file
5. Success/failure feedback

## EXIF/XMP Fields for Writing

| Dive Data | Target Field | Notes |
|-----------|--------------|-------|
| Depth | `XMP:DiveDepth` | Custom namespace |
| Water temp | `XMP:WaterTemperature` | Custom namespace |
| Site name | `IPTC:SubLocation` | Standard field |
| Site GPS | `Exif.GPSInfo.*` | Only if photo lacks GPS |
| Dive number | `XMP:DiveNumber` | Custom namespace |
| Species | `IPTC:Keywords` | Appended to existing |
| Caption | `IPTC:Caption-Abstract` | Standard field |

## Orphan Handling

### Detection

- On dive detail view load, verify referenced assets exist
- Mark as orphaned if asset not found
- Re-verify periodically (not on every access)

### Display

- Show placeholder thumbnail with "Photo unavailable" message
- Preserve and display metadata (depth, species, caption)
- Offer "Remove" action per-item

### Cleanup Tool

Settings > Storage > "Manage Photo References"
- List orphaned photos grouped by dive
- Bulk remove option
- Warning about metadata loss

## Scope Boundaries

### In Scope

| Feature | Priority |
|---------|----------|
| Reference photos from device library | Core |
| Auto-match by timestamp | Core |
| Enrich with depth/temp/location | Core |
| Simple species tagging | Core |
| Thumbnail caching | Core |
| Caption per photo | Core |
| Video support (same as photos) | Core |
| Background scan suggestions | Nice-to-have |
| Optional EXIF writing | Power user |
| Orphan detection & cleanup | Maintenance |

### Explicitly Out of Scope

| Feature | Reason |
|---------|--------|
| Photo editing/filters | Use Lightroom, Snapseed |
| Album organization | Device gallery handles this |
| Cloud photo backup | iCloud/Google Photos |
| Duplicate detection | Not our problem |
| RAW file support | Too specialized |
| Face recognition | Scope creep, privacy |
| Photo import from camera | OS handles this |
| Color correction | Dedicated UW photo editors exist |

## Platform Considerations

### iOS

- Use `PHPhotoLibrary` for read access
- Use `PHAsset.localIdentifier` as stable reference
- Request `.readWrite` access for EXIF writing
- Handle iCloud-only assets (download before EXIF write)

### Android

- Use `MediaStore` for access
- Use `MediaStore._ID` as reference
- Scoped storage (Android 10+) limits EXIF writing
- May need SAF picker for write access to existing files

## Future Considerations

These are intentionally deferred but the schema supports them:

1. **Spatial species annotation** - `media_species` has bbox fields ready
2. **ML species suggestions** - Can populate `media_species` with low confidence
3. **Photo on dive profile** - Show photo markers on depth chart at timestamp
4. **Shareable dive cards** - Generate image with photo + stats overlay
5. **Multi-dive photo** - `media_enrichment` supports same photo linked to multiple dives

## Migration Path

1. Modify existing `Media` table (add new columns)
2. Create `media_enrichment` table
3. Create `media_species` table
4. Create `pending_photo_suggestions` table
5. Migrate existing media records (set `file_path` for signatures, null `platform_asset_id`)
