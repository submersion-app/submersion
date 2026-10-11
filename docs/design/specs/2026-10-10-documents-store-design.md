# Documents: one home for insurance, medical, certification and other papers

Issue: #2613 (also covers #2929, insurance card as an image or PDF).
Release: v1.8.2.

## Problem

Divers keep paperwork that matters at a dive center counter and that expires:
insurance cards, medical clearances, certification cards, permits, bookings.
Today the app scatters it:

- Insurance is five columns on the `divers` row (provider, policy number,
  expiry, emergency phone, office phone). One policy per diver, no image.
- Medical clearance is one expiry column on `divers`. No image, no chip.
- Certification cards keep `photoFront` / `photoBack` BLOBs on their own row.
- Dives, sites and equipment have media-based document attachments that store
  a pointer to a file and only reach another device through an optional media
  store.
- Trips, courses, buddies and dive centers cannot hold a document at all.

Requests: heruhur80 (Discussion #2309, converted to #2929), schtibal (#2515)
and two earlier asks. The need: one document store with optional expiry and a
reminder, with images (front and back) and files, available offline on every
synced device.

## Goals

- A synced `documents` entity with any number of pages, each page an embedded
  file (image, PDF, Word or text, 10 MB max) so it is available offline on
  every device.
- Documents are owned by the diver (personal) or by one of: dive, site, trip,
  equipment, course, certification, buddy, dive center.
- Documents appear in their owner's area and in a top-level Documents
  destination that manages them all.
- Insurance and medical clearance move from the diver row into documents;
  certification card images move into a per-cert card document.
- Expiry reminders as home chips and OS notifications.

## Non-goals

- The existing media document attachments on dives, sites and equipment stay
  as they are. No conversion between the two systems.
- No document import from other apps. UDDF carries only the fields it already
  carries.
- No mirroring of insurance or clearance back into the old diver columns. An
  older app version on another synced device shows stale insurance until it
  updates (accepted).
- No OCR of card images.

## Data model

Tables live in `lib/core/database/tables/document_tables.dart` (never in
`database.dart`). The migration rung lives under `migrations/`. The schema is
at v276 on main today; the plan takes the next free rung at implementation
time.

### `documents` (synced, HLC)

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text PK | |
| `diverId` | text FK divers, required | Library the document belongs to; scopes the global page. |
| `diveId` | text FK dives, nullable | Owner link. |
| `siteId` | text FK dive_sites, nullable | Owner link. |
| `tripId` | text FK trips, nullable | Owner link. |
| `equipmentId` | text FK equipment, nullable | Owner link. |
| `courseId` | text FK courses, nullable | Owner link. |
| `certificationId` | text FK certifications, nullable | Owner link. |
| `buddyId` | text FK buddies, nullable | Owner link. |
| `diveCenterId` | text FK dive_centers, nullable | Owner link. |
| `type` | text | `insurance`, `medicalClearance`, `certificationCard`, `permit`, `booking`, `receipt`, `manual`, `map`, `other`. |
| `title` | text, default '' | Empty renders the type's localized name, so a default title follows the app language. |
| `issuer` | text, nullable | Insurer, doctor, agency, vendor. |
| `referenceNumber` | text, nullable | Policy, card or booking number. |
| `issueDate` | int, nullable | Epoch ms. |
| `expiryDate` | int, nullable | Epoch ms. Not used by `certificationCard`. |
| `reminderLeadDays` | int, nullable | Null means 30; 0 means no reminder. |
| `emergencyPhone` | text, nullable | Insurance only: 24-hour assistance line. |
| `phone` | text, nullable | Insurance only: office line. |
| `isPrimary` | bool, default false | Insurance only. |
| `notes` | text, default '' | |
| `createdAt`, `updatedAt` | int | |
| `hlc` | text, nullable | |

Invariants:

- At most one owner link is set. All null means a personal document.
- At most one `isPrimary` insurance per diver. The repository clears the other
  primaries in the same transaction. If a sync merge produces two, readers
  pick the most recently updated (ties broken by id).
- At most one `certificationCard` document per certification (the card).
  A certification may own any number of other documents.
- Owner FKs use SET NULL at the SQL level only as a safety net; the
  repository deletes owned documents explicitly (see Deletion).

### `document_pages` (synced child, own HLC)

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text PK | |
| `documentId` | text FK documents, cascade | |
| `pageIndex` | int | Display order, 0-based. |
| `side` | text, nullable | `front` or `back` for card types; null otherwise. |
| `fileName` | text | Original name, for "Open with" and share. |
| `mimeType` | text | `image/jpeg`, `application/pdf`, `application/msword`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document`, `text/plain`. |
| `sizeBytes` | int | |
| `bytes` | blob | The file. |
| `createdAt`, `updatedAt` | int | |
| `hlc` | text, nullable | Child clock (#1769 pattern). |

Capture rules:

- Camera and gallery images are re-encoded with
  `ImageEncodeSpec.certificationCard` (2000 px max edge, JPEG 85) and refused
  above `maxSourcePixels`, exactly as the cert edit page does today.
- PDF, `.doc`, `.docx` and `.txt` files are stored as-is.
- Any file above 10 MB (10 * 1024 * 1024 bytes) after re-encoding is refused
  with a message naming the limit. Other types are refused.

### Deterministic migration ids

Every row the migration creates gets an id derived from its source, a UUIDv5
in a fixed Submersion namespace over:

- `insurance:<diverId>` for the insurance document
- `medicalClearance:<diverId>` for the clearance document
- `certificationCard:<certificationId>` for a card document
- `<documentId>:front` / `<documentId>:back` for card pages

Two devices that upgrade independently produce identical rows, which merge by
id instead of duplicating. UDDF and MacDive import reuse the same derivation
for the primary insurance and clearance documents.

## Migration

One rung:

1. For each diver with any insurance column set: insert a primary
   `insurance` document (provider to `issuer`, policy to `referenceNumber`,
   expiry, both phones). Title empty (renders as the type name).
2. For each diver with `medicalClearanceExpiryDate` set: insert a
   `medicalClearance` document with that expiry.
3. For each certification with `photoFront` or `photoBack`: insert a
   `certificationCard` document (owner `certificationId`, `diverId` from the
   cert, or for a buddy-owned cert the diver who owns that buddy) with
   `front` / `back` pages carrying the BLOBs as `image/jpeg`.
4. New rows carry `hlc = NULL`, so any real edit after the migration wins.
5. Old columns are left untouched and are never written again.
6. Idempotent: `INSERT OR IGNORE` on the deterministic ids.

A certification with no diver and no buddy owner (legacy ownerless rows) gets
its card document under the default diver.

## Deletion

`DocumentRepository.deleteForOwner(ownerKind, ownerId)` deletes an owner's
documents and pages and writes their tombstones. Every owner repository's
delete path calls it inside its own transaction: dive, site, trip, equipment,
course, certification, buddy, dive center. Diver deletion (#1957) reaches both
tables through the FK map. `deleteAllRecords` clears both tables.

## User interface

### Top-level Documents destination

- New `documents` entry in `kNavDestinations`, after Certifications. Phone:
  in the More overflow by default. Rail: shown. Saved nav orders are not
  rewritten.
- Global Documents page, following the app's list pattern (master-detail on
  wide screens):
  - "Expiring soon" strip: expired or due within lead time.
  - Groups by owner kind: Personal, Certifications, Trips, Dives, Sites,
    Equipment, Courses, Buddies, Dive centers. Each row: first-page thumbnail,
    title, owner name, expiry badge.
  - Search over title, issuer and reference number; filter chips for type and
    owner kind.
  - FAB adds a personal document. Owned documents are added from the owner's
    page.

### Document detail

Page viewer: swipe between pages, tap for full screen with pinch zoom. Images
render directly; PDFs through the existing pdfrx renderer; Word and text show
a file tile with "Open with" (OS opener on desktop, share sheet on mobile)
from a temp copy of the bytes. Below: metadata, expiry badge, owner link,
edit and delete.

### Document editor

Type, then type-specific fields (insurance shows both phones and the primary
toggle; clearance shows issuer and dates; card type shows no expiry). Page
strip: add from camera, gallery or file; reorder; delete. Card types show
Front and Back slots first. Reminder lead time field (hidden for card type).

### Owner pages

Dive, site, trip, equipment, course, certification, buddy and dive center
detail pages each get a Documents section: compact tiles plus "Add document"
with the owner pre-filled. On dive, site and equipment pages it sits apart
from the existing media attachments section, which is unchanged.

### Diver profile hub

- Insurance row: summarises the primary insurance document; opens Documents
  filtered to insurance. `InsuranceEditPage` is retired and its route
  redirects to the filtered list.
- New Documents row: personal documents.
- Medical info page keeps blood type, allergies, medications and notes. The
  clearance expiry field becomes a "Medical clearances" list linking to those
  documents.

### Certifications

- Edit page front/back pickers read and write the cert's card document.
- E-card wallet, detail page and the dashboard mini cards read card images
  from that document.
- Detail page gains a Documents section for other papers.

### Emergency card and home chips

Read the primary insurance document, mapped to the existing `DiverInsurance`
value object so their rendering barely changes.

## Reminders

- A document reminds when it has `expiryDate` and `reminderLeadDays > 0`,
  except `certificationCard`, whose expiry stays on the certification and is
  covered by the currency warnings (#2267).
- `documentExpiryStatus(document, now)` is one pure function returning
  expired / dueSoon(daysLeft) / ok / none, shared by chips, badges and the
  scheduler. Calendar-day arithmetic (`DateTime(y, m, d + n)`), DST-safe.
- `HomeChipType.insurance` keeps its key and hardening; it reads the primary
  insurance document.
- New `HomeChipType.documents` covers every other expiring or expired
  document of the active diver, any owner. One due: names it. Several: a
  count. Tap opens the Expiring strip, or the document when only one. An
  expired medical clearance is hardened; the rest is hideable. New chip
  destinations go into `app_router_test`.
- `NotificationScheduler.scheduleAll` gains `_scheduleDocumentReminders`,
  modelled on trip reminders: respects `notificationsEnabled` and
  `reminderTime`; one notification on the lead day and one on the expiry day;
  reconciled through `ScheduledNotificationRepository`. A documents provider
  listener triggers `rescheduleAll` on change.

## Sync, backup, import, export

- `documents`: normal synced entity. `document_pages`: `blob: true` (base64),
  in `parentGatedChildEntities`.
- A 10 MB page is about 13.4 MB in base64. Base export already pages BLOB
  tables at 4 MiB with at least one row per page. The plan verifies that
  incremental changesets page `document_pages` by bytes as well, and adds it
  if not, so a burst of scans cannot approach the envelope's inflate cap.
- Conflict catalogue: diver insurance fields and cert photo fields leave
  `people_planning_fields.dart`; a documents catalogue covers document fields,
  pages shown as "page changed".
- Backup: automatic (database file). Undo and restore treat pages as children
  (#2670 rules).
- UDDF export: primary insurance to the existing insurance fields; latest
  clearance expiry to `medicalclearanceexpirydate`. UDDF import and the
  MacDive / universal adapter insurance values create or update the primary
  insurance and clearance documents by deterministic id.
- PDF logbook export reads cert card images from the card document.

## Error handling

- Capture refusals (too large, unsupported, undecodable) show a SnackBar and
  write nothing.
- A document and its pages save in one transaction; a failed save keeps the
  editor's input and shows an error.
- A page that fails to render shows a "Can't display this page" placeholder
  with "Open with".
- Migration skips sources with nothing to move and is idempotent.

## Testing

- Pure: `documentExpiryStatus` across DST and month ends; id derivation; file
  gate; primary selection.
- Repository (in-memory Drift): CRUD, page order, `deleteForOwner` tombstones
  for all eight owner kinds, primary invariant.
- Migration: ladder test from the previous schema with insurance, clearance
  and cert photos; two independent upgrades produce identical ids; old
  columns untouched.
- Sync: round trip with pages, child HLC guard, byte paging, conflict
  catalogue.
- Widgets: Documents page (groups, search, filters, Expiring strip), editor
  page strip, detail viewer, owner Documents sections, hub rows, Medical
  clearances list, cert edit page writing and wallet reading the card
  document.
- Chips and notifications: insurance chip from the primary document,
  documents chip including clearance hardening, scheduler reconcile on edit
  and delete.
- Integration: emergency card, UDDF round trip, MacDive insurance mapping.
- Guards: `test/architecture/`, `test/shared/`, `app_router_test`.
