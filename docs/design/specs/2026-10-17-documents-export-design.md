# Documents: export all as a password-protected ZIP

Issues: #3397 (export all documents), #3391 (one dive label for "File under").

## Intent

A diver keeps certification cards, insurance papers, medicals, permits and
receipts in Submersion. Today the only way to get a file out is to open one
page at a time. The diver wants an **offline archive**: a copy of every
document that can be opened without Submersion, in case the app, the device
or the database is gone.

The database backup already holds every page (pages are BLOBs in
`document_pages`), but a backup is not browsable outside the app. This export
is the browsable copy. It is not a restore path.

## Goals

- One action exports every document of the **active diver** into one ZIP.
- The ZIP is **always password protected**, using **ZipCrypto** (traditional
  PKWARE encryption), so it opens by double-clicking on macOS and Windows.
- Inside, files sit in folders by what they are filed under, with readable
  names, plus a `manifest.csv` holding every document's details.
- Progress is shown while the ZIP is built; the user can cancel.
- Delivery through the existing Share / Save to file choice
  (`showExportDestinationSheet`), as every other export does.
- As part of the same PR, fix #3391: one dive label used by the File-under
  field, the list/detail label and the ZIP folder names.

## Non-goals

- Other divers' documents. Only the active diver's.
- Picking or filtering documents. The export always takes everything.
- Importing the ZIP back into the app.
- AES or any format choice. ZipCrypto only, every time.
- Hiding file and folder names (ZIP encryption never covers them).

## Anti-goals (a failure even if it works)

- Presenting ZipCrypto as strong encryption. It is breakable by a
  known-plaintext attack (PDF and JPEG headers are predictable); the UI says
  so plainly.
- Storing, remembering or logging the password anywhere.
- Running out of memory or freezing the UI on a large library.
- A cancelled or failed export leaving a partial ZIP in a temp folder.
- An archive that the OS unzip tools reject. The targets are macOS Archive
  Utility, Windows Explorer (File Explorer's built-in ZIP support) and Linux
  `unzip`. Phone file apps are not a target (the iOS Files app does not
  open password-protected ZIPs); the sheet's note says the ZIP is meant to
  be opened on a computer. Builder's call: to stay inside what those tools
  accept, entries use Deflate or Stored, no ZIP64, and no data descriptor
  (bit 3) on encrypted entries (the CRC is known before writing, since each
  page is in memory while it is written).

## Decided with the maintainer

| Decision | Choice |
| --- | --- |
| Purpose | Offline archive of everything |
| Scope | Active diver's documents only |
| #3391 | Fixed in this PR; one shared dive label |
| Encryption | Always on, ZipCrypto only (no AES, no option) |
| Password source | Typed each export, entered twice, never stored |
| Entry points | Documents page app bar menu, and a Documents row in Transfer > Export |

## The ZIP

File name: `Submersion documents <yyyy-MM-dd>.zip` (localized prefix).

```
manifest.csv
Personal/
  DAN insurance 2026.pdf
Certifications/
  PADI Advanced Open Water/
    PADI AOW card - front.jpg
    PADI AOW card - back.jpg
Dives/
  #142 Blue Hole 2026-10-12/
    Boat booking.pdf
Dive sites/  Trips/  Equipment/  Courses/  Buddies/  Dive centers/
```

- **Top-level folders:** one per `DocumentOwnerKind` that has at least one
  document, named with the plural localized kind label. Personal documents sit
  directly in `Personal/`.
- **Record folders:** one per owner record, named with that record's label.
  A dive uses the shared dive label (below) with the date as `yyyy-MM-dd`.
  An owner whose record no longer exists falls into a localized "Unknown"
  folder rather than being dropped.
- **File names:** the document's display title (its title, or the localized
  type name when empty).
  - One page: `<title>.<ext>`.
  - Card faces: `<title> - front.<ext>`, `<title> - back.<ext>` (localized).
  - Other multi-page documents: `<title> - page <n>.<ext>` (localized).
  - The extension comes from the page's stored `fileName`, falling back to
    one derived from `mimeType`.
- **Sanitizing:** characters invalid on Windows, macOS or Linux
  (`<>:"/\|?*` and control characters) become `_`; trailing dots and spaces
  are trimmed; Windows reserved names (`CON`, `NUL`, ...) get a suffix;
  each path segment is capped to a safe length.
- **Collisions:** a second identical path within a folder becomes
  `<name> (2).<ext>`, then `(3)`, compared case-insensitively.
- **Entry names are UTF-8** with the ZIP language-encoding flag (bit 11) set,
  so accented names survive on macOS and Windows.
- **Documents with no pages** appear only in the manifest.

### manifest.csv

UTF-8 with a BOM (so Excel reads accents), RFC 4180 quoting, header row,
**one row per file**, plus one row with an empty path for each document that
has no pages. Columns:

`Title, Type, Filed under (kind), Filed under, Issuer, Reference number,
Issue date, Expiry date, Notes, Page, Side, Path in ZIP`

Headers and type and kind values are localized. Dates are `yyyy-MM-dd`.
Insurance phone numbers are included as two further columns
(`Emergency phone`, `Phone`), empty for other types.

## The flow

1. **Entry.** "Export all documents" in a new overflow menu on the Documents
   page app bar (the page has no actions today), and a "Documents" row in
   Transfer > Export. With no documents, a snackbar says there is nothing to
   export and nothing else happens.
2. **Export sheet.** Shows how many documents and files will be exported,
   then Password and Confirm password fields (minimum 8 characters, must
   match, obscured with a show toggle), and a note:
   - **Password characters (builder's call):** printable ASCII only
     (space through `~`). ZipCrypto has no defined password encoding: macOS
     uses UTF-8 and Windows Explorer the system code page, so an accented
     password could open on one and fail on the other. Anything else is
     rejected with a localized message naming the rule. The encoder takes the
     password as ASCII bytes.
   - the password cannot be recovered;
   - the ZIP opens by double-clicking on a computer (not on a phone);
   - the protection stops casual snooping but is not strong encryption, and
     file and folder names stay readable without the password.
3. **Progress.** A progress bar with "file n of N". Building runs off the UI
   thread. Cancel stops it and deletes the temp file.
4. **Delivery.** The existing destination sheet
   (`lib/shared/widgets/export_destination_sheet.dart`) asks Share or Save to
   file, on every platform, as every other export does (builder's call: the
   project rule is that every export offers both). Save to file opens the
   save dialog suggesting the file name. Share hands the temp file to the
   share sheet; where `canShareFiles` is false (Linux) it falls back to the
   save dialog. A snackbar confirms; the temp file is deleted afterwards.
   The destination is asked before the password sheet, so a dismissed
   choice costs nothing.

## #3391: one dive label

- Format: `#142 · Blue Hole · 12 Oct 2026` with the diver's date format.
  No number: `Blue Hole · 12 Oct 2026`. No site: `#142 · 12 Oct 2026`.
- Used by the File-under field (`labelFor`), the list and detail
  `owner_label`, and (with an ISO date and spaces instead of ` · `) the ZIP
  folder name.
- The owner picker keeps its two-line layout (`#142` with "Blue Hole ·
  12 Oct 2026" under it, date as the title when unnumbered): #3391 asks the
  field to match the picker, not the reverse.
- The list/detail SQL currently prefers the dive's `name`; the shared label
  replaces that so the same dive reads the same everywhere.
- The label is built in one Dart function from (number, site name, dive
  date); SQL supplies the raw parts, so date formatting stays in Dart.

## Constraints

- Use the existing `archive: ^4.0.9` package for ZIP structure where it fits;
  its `ZipEncoder` only writes AES, so ZipCrypto encryption needs our own
  encoder. The package's `ZipDecoder` reads ZipCrypto and is the test oracle.
- The ZIP is written to a temp file as it goes; page bytes are read one
  document at a time, never the whole library at once.
- `FilePicker.saveFile` requires bytes and cannot stream (file_picker 12).
  Documents libraries are tens of MB at most, so the desktop save may read
  the finished temp file into memory once; mobile shares the temp file path
  without reading it.
- Paths built with `p.join`; temp space via the platform temp directory.
- Every user-visible string is localized (all ARB files).
- Dates on screen use the diver's date format setting.

## Left to the builder

- Whether to write the ZIP container by hand or reuse parts of `archive`.
- Whether compression is applied before encryption (Deflate is expected; it
  must stay readable by the OS tools).
- Isolate versus chunked async work for building, as long as the UI stays
  responsive and progress updates.
- The exact provider and service split, following the documents feature's
  existing layering.
- Where the shared dive label function lives.
