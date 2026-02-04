# Excel & KML Export Feature Design

**Date:** 2026-02-03
**Status:** Approved
**Scope:** Export dive data to Excel (.xlsx) and Google Earth KML formats

---

## Overview

Add two new export formats to Submersion:
1. **Excel Export** - Multi-sheet workbook with dives, sites, equipment, and statistics
2. **KML Export** - Google Earth placemarks for dive sites with dive history

DAN DL7 export was researched but deferred due to lack of public documentation. UDDF already covers universal data exchange.

---

## Excel Export

### Package

Use `excel: ^4.0.6` (pure Dart, cross-platform compatible).

### Workbook Structure

```
submersion_export_YYYY-MM-DD.xlsx
├── Sheet 1: Dives
├── Sheet 2: Sites
├── Sheet 3: Equipment
└── Sheet 4: Statistics
```

### Sheets 1-3: Data Sheets

Mirror existing CSV export column structure exactly:
- Header row in row 1
- Data starts row 2
- All values converted to user's preferred units (from AppSettings)
- Dates formatted per user's dateFormat preference

### Sheet 4: Statistics

| Row Range | Content |
|-----------|---------|
| 1-5 | **Summary Stats**: Total dives, total bottom time, deepest dive, longest dive, date range |
| 7-20 | **Dives by Year**: Year, count, total time |
| 22-35 | **Dives by Month** (current year): Month name, count |
| 37-45 | **Gas Usage**: Air count, EANx count, Trimix count, CCR count |
| 47-55 | **Special Dives**: Night dives, deep dives (>30m), cold water (<10C) |
| 57-65 | **Top 5 Sites**: Site name, dive count |
| 67-75 | **Equipment Usage**: Item name, dive count |

### Error Handling

| Scenario | Handling |
|----------|----------|
| No dives exist | Export with empty data rows, headers intact |
| Very large export (1000+ dives) | Process in chunks, show progress indicator |
| Missing optional fields | Export empty cell |
| Special characters in text | Excel package handles escaping automatically |

---

## KML Export

### Format

Standard KML 2.2 XML format compatible with Google Earth.

### File Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Submersion Dive Sites</name>
    <description>Exported from Submersion on YYYY-MM-DD</description>

    <Placemark>
      <name>Site Name</name>
      <description><![CDATA[...]]></description>
      <Point>
        <coordinates>longitude,latitude,0</coordinates>
      </Point>
    </Placemark>
  </Document>
</kml>
```

### Placemark Description Content

HTML-formatted bubble with:
- Site name (h3)
- Location (country/region)
- Depth range (min-max)
- Difficulty level
- Description text
- Hazards
- Access notes
- Horizontal rule
- List of all dives at this site with date, depth, duration

### Visual Style

Standard Google Earth red pins (simple, no color coding).

### Filter Logic

- Only export sites with GPS coordinates
- Sites without coordinates are skipped
- Show count of skipped sites to user

### Error Handling

| Scenario | Handling |
|----------|----------|
| Site has no GPS coordinates | Skip site, track skipped count |
| No sites have coordinates | User-friendly error message |
| HTML special chars in descriptions | Escape with htmlEscape() before CDATA |
| Very long dive lists | Show all dives (comprehensive as requested) |

---

## Integration

### Files to Modify

| File | Changes |
|------|---------|
| lib/core/services/export_service.dart | Add exportToExcel() and exportToKml() methods |
| lib/features/settings/presentation/providers/export_providers.dart | Add methods to ExportNotifier |
| pubspec.yaml | Add excel: ^4.0.6 dependency |

### New Methods

```dart
// In ExportService

Future<String> exportToExcel({
  required List<Dive> dives,
  required List<DiveSite> sites,
  required List<EquipmentItem> equipment,
  required AppSettings settings,
}) async { ... }

Future<String> exportToKml({
  required List<DiveSite> sites,
  required List<Dive> dives,
  required AppSettings settings,
}) async { ... }
```

### Unit Preferences

Both exports respect active diver's settings:
- Depths in meters or feet
- Temperatures in Celsius or Fahrenheit
- Pressures in bar or PSI
- Dates in user's preferred format

### UI Integration

Add Excel and KML buttons to existing export UI in settings, following same pattern as CSV/PDF/UDDF exports.

---

## Shared Error Handling

| Scenario | Handling |
|----------|----------|
| File write fails | Catch exception, show error toast, return null |
| Share cancelled by user | Treat as success (file was created) |
| Export during active import | Use ExportState.status to prevent concurrent ops |

---

## Out of Scope

- DAN DL7 export (deferred - no public specification available)
- Excel formatting/styling (keeping simple, mirroring CSV)
- KML color-coded pins (using standard pins)
- KML dive tracks/paths (only site placemarks)
