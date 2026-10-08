# Import & Export

Bring your dives in from other apps and dive computers, and take your whole log
back out in open, portable formats. In the app, this lives under **Transfer**.

> [!NOTE]
> **Where to find it:** Open **Transfer** from the navigation. It has four
> sections: **File Import**, **File Export**, **Dive Computers** and **Cloud**. This page covers
> importing and exporting; downloading directly from a dive computer is covered
> in [Dive Computer](dive-computer.md).

Submersion is built so your data is never locked in. Everything you log can be
exported to formats that other dive software, spreadsheets, and Google Earth can
read, and dives from most popular apps and computers can be brought in.

<!-- screenshot: images/import-export/import-wizard.png: import wizard -->

## Importing

All file imports go through a single **import wizard**. You point it at a file,
it figures out what the file is, and it walks you through bringing the data in.
Open it from **Transfer > File Import**.

### How the wizard works

The wizard is the same regardless of which format you give it. It moves through a
short series of steps:

1. **Select file**: choose the file to import. Submersion inspects the file's
   *contents* (not just its extension) to detect the format and the app it came
   from.
2. **Confirm source**: the wizard shows what it detected, for example
   "Subsurface (XML)" or "Shearwater Cloud database." If it guessed wrong, expand
   **Not right? Select the correct source:** and pick the right one.
3. **Map fields**: for CSV files from other apps, match the columns in your file to
   Submersion's fields (see [CSV files](#csv-files-with-field-mapping) below).
   Other formats, and CSV files Submersion exported itself, skip this step.
4. **Review**: see exactly what will be imported, grouped by type (dives, sites,
   buddies, and so on). Deselect anything you do not want, resolve any
   [duplicates](#duplicate-handling), and add [tags](#import-tags).
5. **Import**: Submersion writes the selected items into your log.
6. **Done**: a summary shows what was imported, with a shortcut to view the new
   dives.

> [!TIP]
> You can import far more than dives. A single file can also carry dive sites,
> trips, buddies, dive centers, equipment, certifications, courses, tags, and
> custom dive types, and you choose what to bring in at the Review step.

### Supported import formats

Submersion reads the following formats. The wizard recognises each one
automatically; you only need to override the source if detection is uncertain.

| Format | Typical source | Notes |
|--------|----------------|-------|
| **UDDF** | Most dive software (Suunto DM5, Scubapro LogTRAK, and others export it) | Universal Dive Data Format, the open standard for dive-data exchange. Carries dives, profiles, sites, buddies, and more. |
| **Subsurface XML** | Subsurface | Subsurface's native `.ssrf` / XML log. A companion CSV of sample data can be added during import. |
| **CSV** | Spreadsheets, exports from many apps, and Submersion's own CSV exports | Comma-separated values, with column mapping. See [CSV files](#csv-files-with-field-mapping). |
| **Garmin FIT** | Garmin Descent and other Garmin dive watches | The binary `.fit` activity file. Contains dive data only; non-dive activities are ignored. With the watch connected to a desktop by cable, **Import from Garmin Device** reads its activity folder directly. |
| **Shearwater Cloud** | Shearwater Cloud desktop app | The app's `.db` database file. Imports dives and their sites. |
| **MacDive (XML)** | MacDive | MacDive's native XML log export. |
| **MacDive (SQLite)** | MacDive | MacDive's SQLite database, read directly. |
| **Diving Log (SQLite)** | Diving Log | Diving Log's database file. |
| **DAN DL7** | DAN dive logs and DiveCloud | The DAN DL7 export, including the ZIP DiveCloud produces. |
| **Ratio XML** | Ratio computers | Ratio's XML export. |

In addition, you can import without a file:

- From a **dive computer** over Bluetooth or USB, or, on iOS, from **Apple Watch** via Apple Health. See [Dive Computer](dive-computer.md).
- From an online account under **Transfer > Cloud**: **Garmin** (Garmin Connect), **Suunto** (the Suunto app or app.suunto.com), and **divelogs.de** (your logbook, sites, gear, certifications and photos).

All of them run through the same review.

> [!NOTE]
> A few formats are recognised but not yet readable: **Diving Log XML**,
> **Suunto SML**, **Suunto DM5** and **Scubapro**. If you import one of these,
> the wizard tells you and suggests exporting from that app as **UDDF** or
> **CSV** instead, which Submersion does read.

### CSV files with field mapping

CSV is the catch-all for spreadsheets and for apps that have no other export.
Because every app lays out its columns differently, the wizard adds a **Map
fields** step where you tell Submersion which column means what, for example
that your "Max. Depth" column is the maximum depth and "Bottom Time" is the
duration.

Submersion already knows the column layouts of several common apps (including
Subsurface, MacDive, Diving Log, DiveMate, Garmin Connect, Shearwater, and SSI
MyDiveGuide). When it recognises one, the mapping is filled in for you and you
can go straight to Review. For an unrecognised layout, map the columns yourself.

A CSV that Submersion exported itself (dives, sites, equipment, or cylinder
fills) is recognised from its header row and imports with no mapping step, in
whichever units it was exported.

> [!TIP]
> Save a mapping you have set up by hand as a **preset**, and the wizard reuses it
> automatically the next time you import a file with the same columns.

### Drag-and-drop and sharing

You do not have to open the wizard first.

- **On desktop**, drag a supported file anywhere onto the Submersion window. A
  **Drop to Import** overlay appears; release the file and the wizard opens with
  it already loaded.
- **On mobile**, use your device's **Share** sheet from another app (or a file
  manager) and choose Submersion as the destination.

Either way, Submersion detects the format and jumps straight to the Confirm
source step. If the file is not a type Submersion can read, it says so; if an
import is already in progress, finish that one first.

### Duplicate handling

Before anything is written, the wizard compares incoming data against what is
already in your log and flags likely duplicates so you never import the same dive
twice by accident.

- **Dives** are matched first by a hidden source identifier, so re-importing the
  *same* dive from a different format (say, MacDive SQLite and later UDDF)
  recognises it as one dive. Failing that, dives are matched by how closely their
  date and time, maximum depth, and duration line up.
- **Sites** match by name, or by being within about 100 metres of an existing
  site's coordinates.
- **Buddies, dive centers, trips, tags, and dive types** match by name;
  **equipment** and **certifications** match by name together with their type or
  agency.

For each flagged dive you choose how to resolve it:

| Choice | What it does |
|--------|--------------|
| **Skip** | Leave the existing dive untouched and do not import the incoming one. This is the default for matched dives. |
| **Import as New** | Add the incoming dive as a separate, brand-new entry. |
| **Consolidate** | Attach the incoming data to the matched dive as an additional dive-computer reading, rather than creating a second dive. |
| **Replace Source** | Swap the matched dive's recorded data for the incoming version. |

Items that are *not* duplicates start out selected; clear the checkbox on
anything you would rather leave out.

### Import tags

At the Review step you can apply one or more **tags** to everything in the import,
which makes a batch easy to find, or undo, later. Submersion suggests a default
tag based on the file name and today's date (for example,
`my-log.csv Import 2026-06-15`). Type to add your own tags; existing tags
autocomplete, and a new name creates a new tag.

> [!TIP]
> Tag a big import with something memorable before you run it. If the result is
> not what you expected, filtering the dive list by that tag makes the whole batch
> easy to review and remove.

### Dives and trips

Dives arrive in the trips their file assigns them. A dive with no trip of its
own joins your existing trip whose dates cover it, when the file has no trips at
all (MacDive, for example) or when the dive's trip was not imported. A file that
has trips but leaves a dive out of them is respected, and an undated dive is
never placed.

### Re-importing all dives from a computer

When you download from a dive computer, Submersion normally fetches only dives it
has not seen before. If you deleted a dive by mistake, or an earlier download was
interrupted, open that computer from **Transfer**, choose **Re-import all
dives**, and confirm. Submersion pulls *every* dive off the device
and routes them through the same Review step, where each dive already in your log
is flagged as a duplicate for you to **Skip**, **Import as New**, or
**Consolidate**. Nothing is duplicated unless you say so. This applies to dive
computers only; re-running a file or Apple Watch import already produces the full
set.

<!-- screenshot: images/import-export/export-options.png: export format options -->

## Exporting

Exports live on the **Transfer** page. Pick a format and Submersion offers two
ways to deliver the result:

- **Share**: send it via email, messages, or any other app through your device's
  share sheet.
- **Save to File**: choose where to save it on your device.

### Supported export formats

| Format | Best for | What it contains |
|--------|----------|------------------|
| **PDF logbook** | Printing, or sharing with non-divers | A formatted logbook you can style with a template (see below). |
| **UDDF** | Moving your data to other dive software | The open Universal Dive Data Format. Export the dives you choose, or your entire library: dives, profiles, sites, buddies, equipment, certifications, trips, and more. |
| **CSV** | Spreadsheets | A comma-separated file. Choose **Dives**, **Sites**, **Equipment**, **Cylinder fills**, or **Gear check-ins** (every OK check and reported issue). For **Units**, **Metric** writes metric values and ISO dates; **My units** writes your unit, date and time settings, named in each column header. Submersion can import its own CSV exports back. |
| **Excel Workbook** | A single spreadsheet with everything | An `.xlsx` workbook with sheets for Dives, Sites, Equipment and Statistics, plus checklists, maintenance and gear check-ins when you have them. |
| **Google Earth KML** | Seeing where you have dived | A `.kml` file that plots your dive sites on the 3D globe in Google Earth. Sites without coordinates are skipped. |
| **Maintenance Log** | Gear servicing | Service history for all your equipment, as a spreadsheet. |

> [!NOTE]
> PDF, Excel and KML exports use your current unit and date-format preferences
> from [Settings](settings.md), so depths, temperatures, pressures, and dates come
> out the way you read them in the app. CSV lets you choose (see above).

### PDF logbook templates

Choosing **PDF Logbook** opens an options sheet before the export runs. You can
pick:

- **Template**: **Simple** (a compact table, many dives per page), **Detailed**
  (one dive per page with every field and a profile chart), **PADI Style**, or
  **NAUI Style** (laid out like those agencies' paper logbooks).
- **Page size**: **A4** or **Letter**.
- **Include Certification Cards**: add scanned certification card images to the PDF.

You can also export a single dive as a PDF from its own detail page. Exporting a
whole trip is not available yet; select the trip's dives in the dive list and use
**Export Selected** instead.

## Import & export vs. backup and sync

These three features look similar but do different jobs:

- **Import & export** moves dives between Submersion and *other* software using
  open formats. Use it to migrate in from another app, or to hand your data to a
  tool Submersion does not talk to directly.
- **Backup & restore** takes a complete, point-in-time snapshot of your entire
  database that you can restore later. Make one before a big import or a device
  change. See [Backup & Restore](backup-and-restore.md).
- **Multi-device sync** keeps several devices showing the same library
  automatically. It is not a backup. See [Multi-Device Sync](multi-device-sync.md).

> [!TIP]
> Exporting a full **UDDF** file is also a handy portable archive of your log,
> but for a true safety net that restores Submersion exactly as it was, use
> **Backup & Restore**.

## See also

- [Dive Computer](dive-computer.md): download dives over Bluetooth, USB, or Apple Watch
- [Dive Logging](dive-logging.md): what happens to dives once they are imported
- [Backup & Restore](backup-and-restore.md): full database snapshots
- [Multi-Device Sync](multi-device-sync.md): keep devices in step
- [Settings](settings.md): units, date format, and import defaults
- [Data Quality Assistant](data-quality-assistant.md): reviewing imported dives for clock, profile, and duplicate problems
