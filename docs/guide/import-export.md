# Import & Export

Move your dive data in and out of Submersion using industry-standard formats.

## Supported Formats

| Format | Import | Export | Description |
|--------|--------|--------|-------------|
| **UDDF** | Yes | Yes | Universal Dive Data Format |
| **CSV** | Yes | Yes | Spreadsheet format |
| **Garmin FIT** | Yes | No | Garmin dive activity files |
| **Subsurface XML** | Yes | No | Subsurface native format |
| **DAN DL7** | Yes | No | DiverLog+ / DiveCloud exports (.zxu, .zxl, ZIP) |
| **HealthKit** | Yes | No | Apple Watch dive workouts (iOS only) |
| **PDF** | No | Yes | Printable logbook |
| **SQLite** | Yes | Yes | Full database backup |

## UDDF (Universal Dive Data Format)

UDDF is the industry standard for dive data exchange, used by most dive logging software.

### Importing UDDF

1. Go to **Settings** > **Import/Export**
2. Tap **Import**
3. Select **UDDF File**
4. Choose the `.uddf` file
5. Review imported dives
6. Confirm import

<div class="tip">
<strong>What's Imported:</strong> Dives, profiles, sites, tanks, equipment references, and buddies.
</div>

### Exporting UDDF

1. Go to **Settings** > **Import/Export**
2. Tap **Export**
3. Select **UDDF Format**
4. Choose date range (or all dives)
5. Select destination
6. File saved as `.uddf`

### UDDF Compatibility

Submersion supports UDDF 3.2, compatible with:

- Subsurface
- MacDive
- DiveLog
- Most dive computer software

## CSV Import/Export

### CSV Import

For spreadsheet data or other sources:

1. Go to **Settings** > **Import/Export**
2. Tap **Import**
3. Select **CSV File**
4. Choose the `.csv` file
5. **Map columns** to Submersion fields
6. Review mapping
7. Import

#### Column Mapping

The import wizard shows your CSV headers and lets you match them:

| Your Column | Maps To |
|-------------|---------|
| "Date" | Dive Date |
| "Max Depth (m)" | Max Depth |
| "Duration (min)" | Duration |
| "Location" | Site Name |
| ... | ... |

<div class="tip">
<strong>Tip:</strong> Save column mappings for repeated imports from the same source.
</div>

### CSV Export

Export dives to a spreadsheet:

1. Go to **Settings** > **Import/Export**
2. Tap **Export**
3. Select **CSV Format**
4. Choose which fields to include
5. Select date range
6. Export

Exported CSV includes:

- All standard dive fields
- Tank information
- Site details
- Equipment links

## PDF Export

Create printable logbook pages:

### Full Logbook

1. Go to **Settings** > **Import/Export**
2. Tap **Export**
3. Select **PDF Logbook**
4. Choose date range
5. Select style/template
6. Generate PDF

### Single Dive

From any dive detail page:

1. Tap the **share icon**
2. Select **Export as PDF**
3. Share or save the PDF

### PDF Contents

Each dive page includes:

- Dive header (number, date, site)
- Dive profile graph
- Key statistics
- Conditions
- Notes
- Equipment used

<div class="screenshot-placeholder">
  <strong>Screenshot: PDF Export Sample</strong><br>
  <em>Sample page from PDF logbook export</em>
</div>

## Database Backup

### Creating a Backup

Full database backup for safety:

1. Go to **Settings** > **Import/Export**
2. Tap **Backup**
3. Choose destination
4. Backup saved as `.sqlite` file

<div class="warning">
<strong>Important:</strong> Create regular backups, especially before major updates or device changes.
</div>

### Restoring from Backup

1. Go to **Settings** > **Import/Export**
2. Tap **Restore**
3. Select backup file
4. Confirm restoration

<div class="warning">
<strong>Warning:</strong> Restoring replaces ALL current data. Create a backup first if you have new data.
</div>

## Cloud Sync vs Backup

Cloud Sync keeps devices in sync using an app-managed JSON file stored in your
cloud provider. It is not a replacement for backups:

- **Cloud Sync** keeps multiple devices aligned.
- **Backups** are point-in-time snapshots you can restore later.

Use backups before major changes or when moving between devices.

## Importing from Other Apps

### From Subsurface

1. In Subsurface: **File** > **Export** > **UDDF**
2. Transfer file to your device
3. Import UDDF in Submersion

### From MacDive

1. In MacDive: **File** > **Export** > **UDDF**
2. Import UDDF in Submersion

### From Aqualung DiverLog+ / DiverLog (DAN DL7)

Submersion imports DAN DL7 (`.zxu` / `.zxl`) files, including the extended
dive data DiverLog+ embeds in them: dive site and GPS, city/state/country,
tank pressures and gas mixes, ratings, dive stats, and dive computer
identity.

**Getting your data out of DiverLog+ (mobile):** the mobile app has no file
export. Sync your dives to DiveCloud from within DiverLog+, then sign in at
divecloud.net in a browser, select your dives, and choose Export. This
downloads a ZIP of per-dive `.zxu` files plus any attached photos.

**Importing:** drop the DiveCloud ZIP (or individual `.zxu` files) onto
Submersion, or use Transfer > File Import. Every dive in the archive is
imported in one pass, photos are attached to their dives automatically, and
dives you already downloaded from the same dive computer are flagged as
duplicates with consolidation offered.

**Desktop DiverLog:** the discontinued Full version can export `.zxu` files
directly (Export Dive Data > DL7 Standard); the Lite versions cannot export.
Lite users should Wi-Fi-sync to the mobile app and use the DiveCloud path.

### From Dive Computer Software

Most manufacturers support UDDF export:

- **Shearwater Cloud** - Export UDDF
- **Suunto DM5** - Export UDDF
- **Mares Dive Organizer** - Export UDDF

### From Spreadsheets

If you have dives in Excel/Google Sheets:

1. Save as CSV
2. Use CSV import with column mapping

## Duplicate Handling

When importing, Submersion detects duplicates:

### Detection Criteria

Dives are considered duplicates if they match:

- Date/time (within 5 minutes)
- Max depth (within 1m)
- Duration (within 2 minutes)

### Duplicate Options

When duplicates are found:

- **Skip** - Don't import duplicates
- **Replace** - Overwrite existing
- **Import Anyway** - Create duplicates

## Export Tips

### Regular Backups

- Schedule weekly backups
- Store in multiple locations
- Test restore occasionally

### Before Major Changes

Always backup before:

- Device migration
- App updates
- Bulk imports

### Sharing Dives

To share individual dives:

1. Open dive detail
2. Tap share icon
3. Choose format (PDF for non-divers, UDDF for divers)

## HealthKit / Apple Watch Import

On iOS, Submersion can import dive data recorded by Apple Watch directly from HealthKit. The app fetches underwater diving workouts along with associated heart rate data.

### Importing from HealthKit

1. Go to **Transfer** > **Apple Watch**
2. Grant HealthKit read permissions when prompted
3. Select a date range to search for dives
4. Review the list of discovered dive workouts
5. Choose which dives to import
6. Handle any duplicates (skip or import)
7. Confirm import

Imported data includes start/end times, heart rate samples, and GPS coordinates when available. Depth and temperature depend on the watch model and sensor capabilities.

## Garmin FIT File Import

Garmin dive computers (Descent series) store dive activities in the FIT binary format. Submersion can parse these files to extract dive profiles, depth, temperature, heart rate, and GPS data.

### Importing FIT Files

1. Go to **Transfer** > **Garmin FIT Import**
2. Tap **Select FIT Files** and choose one or more `.fit` files
3. The parser filters for dive activities and skips non-dive files automatically
4. Review parsed dives and handle duplicates
5. Confirm import

Each imported dive receives a unique source ID based on the device serial number and start time, which prevents duplicate imports.

## Universal Import

The universal import wizard provides a single entry point for importing from many formats and applications. It auto-detects the file format and source application, then guides you through a six-step process.

### Supported Formats

The universal import wizard currently supports CSV, UDDF, Subsurface XML, and Garmin FIT files. Additional formats (Suunto SML/DM5, Shearwater Cloud, DAN DL7, and others) are planned.

### Using Universal Import

1. Go to **Transfer** > **Import from File**
2. Select a file -- the format and source application are detected automatically
3. Confirm or override the detected source
4. For CSV files, map your columns to Submersion fields
5. Review and select which entities (dives, sites, buddies, etc.) to import
6. Wait for import to complete
7. Review the summary of imported items

## Troubleshooting

### Import Fails

- Check file isn't corrupted
- Verify format matches selection
- Check file permissions

### Missing Data

- Some fields may not map between apps
- Profile data requires UDDF format
- Check column mapping for CSV

### Encoding Issues

- Ensure CSV is UTF-8 encoded
- Special characters may need attention
