# Diver and buddy profile photos

Status: approved design, ready for an implementation plan
Date: 2026-08-29
Branch: `worktree-profile-photos` (rebased onto `origin/main` at schema v180; this feature claims v181)

## Goal

Let divers and buddies have a profile photo. Store the image bytes in the
database so it travels with the row across devices, and bound the size so the
database and the sync changeset do not grow without limit.

## Background: what already exists

Three findings shaped this design.

**A half-built path-based implementation is already in the tree.** `Divers`,
`Buddies`, and `Species` each carry a `photoPath` TEXT column, fully wired
through the entities, repositories, and merge repositories. Nothing writes it
for divers or buddies. Two places read it, and they disagree:
`buddy_list_tile.dart:293` correctly uses `FileImage` guarded by
`existsSync()`, while `buddy_detail_page.dart:417` uses
`AssetImage(buddy.photoPath!)`, which resolves against the bundled asset
manifest and could never load a filesystem path. `buddy_edit_page.dart:307` is
a stub: a camera badge over the initials avatar and the string
`buddies_label_photoComingSoon` ("Photo support coming in v2.0").

A device-local file path is the wrong storage for a synced app. It does not
survive sync to a second device, does not survive an iOS app-container UUID
change between installs, and on Android SAF a picked file frequently has no
usable path at all.

**Storing image bytes in a synced row is established practice here.** Four
tables already do it and are marked `blob: true` in the sync serializer's
`_baseTables`: `media.imageData` (signatures), `certifications.photoFront` and
`photoBack`, `gpsTracks.points`, and `diveDataSources.rawData`. Sync encodes
these as base64 rather than the default JSON array of byte ints, via
`_SyncBlobValueSerializer` (`sync_data_serializer.dart:32`).

`Certifications` in particular has already performed exactly the migration
this feature needs: `photoFrontPath` and `photoBackPath` are marked
"deprecated, kept for migration" and superseded by the `photoFront` and
`photoBack` blobs.

**The existing size limiting is broken on desktop.** Certification photos are
bounded by passing `maxWidth: 2000, maxHeight: 2000, imageQuality: 85` to
`ImagePicker.pickImage` (`certification_edit_page.dart:205`). Both
`image_picker_macos` and `image_picker_windows` state verbatim that these
arguments "are not currently supported. If any of these arguments are supplied,
they will be silently ignored." On macOS, Windows, and Linux a full-size camera
JPEG therefore enters SQLite whole and rides into every sync changeset at
roughly 1.33x as base64. Android and iOS honor the caps, which is why this has
stayed invisible.

The lesson that drives this design: resizing must happen in Dart on the write
path, never as a picker argument.

## Decisions

| Decision | Choice |
| --- | --- |
| Storage | `BlobColumn` directly on `divers` and `buddies` |
| Stored format | 512x512 square JPEG, quality 85, roughly 50-80 KB |
| Crop | Pan and zoom crop surface, not automatic center-crop |
| Contacts | Per-buddy via the native picker, no address-book enumeration |
| Surfaces | All in-app avatars, table rows, and picker chips. Not PDF export |
| Certifications | Rerouted through the new codec so their cap becomes real |

### Why a blob on the row rather than a side table

A separate `profile_photos` table would ship photo bytes only when the photo
changes, whereas a column on `buddies` re-ships them whenever any field on that
buddy changes, because `_exportBuddies` selects whole rows where `hlc > since`.

The column still wins. A new synced entity costs roughly 14 registration sites
plus the FK parent map, conflict-reference resolver, merge ordering, HLC
targets, and the structural tests that lock all of them, and it adds a join or
second query to every buddy and diver read. That is a large permanent cost to
avoid re-shipping about 60 KB on an edit to an entity that is edited rarely.
The column also matches four existing precedents, so the pattern is
recognizable.

Reusing the `media` table was rejected. Media rows are entangled with the media
store's upload pipeline, library grid filtering, resolvers, and thumbnails.
Buddy signatures already leak into the media library grid because
`kSignatureFileTypes` omits `'buddy_signature'`, and they pass the upload
pipeline's eligibility check. Adding another pseudo-media type repeats a
mistake this codebase has already made.

### Why 512px

The largest avatar in the app is `radius: 50`, so 100 logical pixels across,
which is 300 physical pixels at 3x. 512 stores deliberate headroom for a
possible future tap-to-enlarge view, because the source is discarded at pick
time and re-encoding upward later is impossible.

## Section 1: Data layer and sync

### Schema

```dart
// Divers (database.dart:19) and Buddies (database.dart:1966)
TextColumn get photoPath => text().nullable()();  // deprecated, superseded by photo
BlobColumn get photo => blob().nullable()();      // 512px square JPEG
```

`photoPath` is deprecated in place rather than dropped, following the comment
style `Certifications` uses. Nothing writes it for divers or buddies, so there
is no data to migrate and no backfill rung.

### Migration

Follows the repo's idempotent assert idiom, modeled on
`_assertBuddyFavoriteColumn` (`database.dart:5494`):

```dart
Future<void> _assertProfilePhotoColumns() async {
  for (final table in const ['divers', 'buddies']) {
    final cols = await customSelect("PRAGMA table_info('$table')").get();
    if (cols.isEmpty) continue;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('photo')) {
      await customStatement('ALTER TABLE $table ADD COLUMN photo BLOB');
    }
  }
}
```

Wired in five places: the `if (from < 181)` rung and its `reportProgress()`, an
appended `181` in `migrationVersions` with a comment naming the claim, the
`currentSchemaVersion` bump, and a `beforeOpen` backstop call so databases
arriving by restore or sync-adopt, which never run `onUpgrade`, still get the
column.

`minimumCompatibleSchemaVersion` stays at 170. A nullable column is additive
and Drift's generated `fromJson` ignores unknown keys, so a v180 peer keeps
syncing with a v181 peer and simply ignores `photo`.

The rung number must be re-verified against `origin/main` at implementation
time. It already moved once: PR #1374 landed and took 180 while this design
was being written, so the claim is now 181. A rung at or below
main's scalar merges with no conflict marker and its step then never runs.

### Entities

`Uint8List? photo` on both `Diver` and `Buddy`.

`Diver.copyWith` uses the sentinel pattern, so `photo: null` genuinely clears
the field. `Buddy.copyWith` is the plain `??` style, where `photo: null` falls
through to `this.photo` and is a silent no-op. Wiring the two identically would
make "Remove photo" work for a diver and silently fail for a buddy.

`Buddy` therefore gains a separate `Buddy clearPhoto()` method, mirroring
`Certification.clearPhotos({bool clearFront, bool clearBack})`
(`certification.dart:125-146`), which rebuilds through the constructor rather
than routing a flag through `copyWith`. That is this codebase's established
idiom for clearing a photo blob. Copying it avoids converting `Buddy` to the
sentinel pattern, which would touch every existing caller.

Note that `buddy_edit_page.dart` constructs a `Buddy(...)` directly rather than
going through `copyWith`, so the primary user-facing "Remove photo" path does
not depend on this method. It exists so that no future caller reaching for
`copyWith(photo: null)` gets a silent no-op.

### Repositories

Every site that reads a row into a `Buddy`/`Diver` or writes a companion must
carry `photo`, or it silently fails to persist on that path. The complete list,
against the worktree base:

`buddy_repository.dart`
- `_mapRowToBuddy` `:1100`
- inline row-to-`Buddy` construction feeding `_withPrimaryCerts`, `:140-162`
- `createBuddy` companion `:165-206`
- `updateBuddy` companion `:277-312`
- two further `BuddiesCompanion` writes at `:887` and `:918`

`diver_repository.dart`
- `_mapRowToDiver` `:660`
- `createDiver` companion `:128-194`
- `updateDiver` companion `:196-239`
- (`:551` writes only `isDefault` and `updatedAt`; it needs no change)

`buddy_merge_repository.dart` carries `photoPath` at `:115`, `:446`, and `:594`
and needs the same treatment, as does `buddy_merge_form_controller.dart:81`, so
a merge picks a winning photo the way it picks other fields.

Existing `markRecordPending` calls already stamp the HLC, so no new sync
bookkeeping is needed in the repositories.

### Sync

Six edits per entity, following the `certifications` pattern. Line numbers are
against the worktree base (`origin/main` at v180, after the rebase of 2026-08-29):

| Site | divers | buddies | Change |
| --- | --- | --- | --- |
| `_baseTables` | `:654` | `:718` | `blob: false` becomes `blob: true` |
| delta exporter | `_exportDivers` `:4535` | `_exportBuddies` `:4803` | `r.toJson(serializer: _syncBlobSerializer)` |
| `fetchRecord` | `:1555` | `:1650` | `row?.toJson(serializer: _syncBlobSerializer)` |
| `fetchRecords` (batch) | `:1971` | `:2026` | same serializer in the map comprehension |
| `upsertRecord` | `:2444` | `:2549` | `fromJson(data, serializer: _syncBlobSerializer)` |
| `upsertRecords` (batch) | `:2951` | `:3115` | same serializer |

Note this is six sites, not five. The batch `fetchRecords` path
(`sync_data_serializer.dart:1951`) is easy to miss because it sits between the
single-record fetch and the upserts, and it has its own switch.

Missing any one of these fails silently: the blob still round-trips correctly,
just as a JSON byte array at roughly 3x the size. `sync_blob_base64_test.dart`
exists to lock this and gains diver and buddy cases.

## Section 2: The image pipeline

New shared file: `lib/core/services/images/profile_photo_codec.dart`.

```dart
class ImageEncodeSpec {
  final int maxDimension;
  final int jpegQuality;
  final bool square;

  /// 512px square avatar, roughly 50-80 KB.
  static const avatar =
      ImageEncodeSpec(maxDimension: 512, jpegQuality: 85, square: true);

  /// Certification card face. Card text must stay readable, so the ceiling is
  /// higher and the source aspect ratio is preserved.
  static const certificationCard =
      ImageEncodeSpec(maxDimension: 2000, jpegQuality: 85, square: false);
}
```

The entry point mirrors `image_resize_job.dart`: a `compute`-dispatched wrapper
plus a `@visibleForTesting` top-level isolate body tests can call directly
without spawning an isolate.

```dart
Future<ImageEncodeResult> encodeStoredImage(ImageEncodeRequest r) =>
    compute(runImageEncodeRequest, r);

@visibleForTesting
ImageEncodeResult runImageEncodeRequest(ImageEncodeRequest r);
```

The isolate body, in strict order:

1. Decode: `decodeNamedImage` when the source name is known, else
   `decodeImage`. Null yields `undecodable`.
2. `img.bakeOrientation`.
3. Crop: the caller's explicit `cropRect` if given, else the largest centered
   square when `spec.square`.
4. `copyResize` to `maxDimension`, skipped when the source is already smaller
   so it never upscales.
5. `encodeJpg(quality: spec.jpegQuality)`.

Step 2 is mandatory and its position matters. The `image` package's JPEG
decoder performs no orientation handling, so a portrait phone photo decodes as
a sideways buffer carrying `exif.orientation = 6`. Baking after the crop would
apply a rectangle chosen in the upright preview to a rotated buffer and select
the wrong region.

Re-encoding also strips EXIF, so GPS coordinates embedded in a gallery or
contact photo cannot ride into a blob that syncs to every device and cloud
provider.

`resizeToJpegFile` was not reused because it only writes a JPEG to a
destination path, has no crop step, and has no orientation step. Reusing it
would mean inventing a temp file and reading it straight back for something
whose destination is a blob.

The request carries a `maxSourcePixels` ceiling returning a distinct `tooLarge`
outcome, because decoding is what allocates and nothing caps a desktop pick.

### Certification reroute

`_pickPhoto` in `certification_edit_page.dart` drops `maxWidth`, `maxHeight`,
and `imageQuality` from its `pickImage` call and pipes the bytes through
`encodeStoredImage(spec: certificationCard)`. The 2000px cap becomes real on
macOS, Windows, and Linux for the first time. Existing oversized rows are not
backfilled.

## Section 3: The crop sheet

Placement: `lib/shared/widgets/profile_photo/`.

| File | Role |
| --- | --- |
| `profile_photo_source_sheet.dart` | Camera (mobile only), Photo Library / Choose File, Contacts (buddies on mobile only), Remove Photo (only when a photo exists) |
| `profile_photo_crop_dialog.dart` | The pan and zoom crop surface |
| `profile_photo_crop_geometry.dart` | Pure viewport-to-source-pixel math |
| `profile_avatar.dart` | Shared display widget |

The crop surface is a `Dialog.fullscreen` shown via `showDialog<Uint8List?>`,
not a bottom sheet. A crop wants maximum area, and a full-screen dialog
sidesteps the `isScrollControlled` sheet-ceiling problem from issue #1188
rather than re-solving it.

Inside sits an `InteractiveViewer` over the decoded image with a square
viewport, a circular mask, and dimmed surroundings. `minScale` is the cover
scale, so zooming out far enough to expose a gap is not representable.

Confirm computes geometry rather than rasterizing:

```dart
@visibleForTesting
Rect cropRectInSourcePixels({
  required Matrix4 transform,   // TransformationController.value
  required Size viewport,       // the square crop window, logical px
  required Size childSize,      // the image as laid out in the viewer
  required Size sourceSize,     // decoded pixel dimensions
});
```

Invert the transform, map the viewport corners into child space, scale by
`sourceSize / childSize`, clamp. The result feeds `ImageEncodeRequest.cropRect`.

Returning a rect in source pixels makes the output independent of device pixel
ratio and dialog size, so the same gesture yields the same stored image on a 1x
Linux window and a 3x iPhone, and the whole thing unit-tests as a matrix and
four numbers with no widget tree and no golden files.

`InteractiveViewer` owns its recognizer and consumes trackpad pan-zoom
internally, so there is no `Listener` to pair with it and no way to reproduce
the double-apply bug from issue #1188. `trackpadScrollCausesScale` stays at its
default, so two-finger scroll pans and pinch zooms.

Save and Cancel pop from inside the dialog's own `builder` context. `showDialog`
already defaults to `useRootNavigator: true`, so this is the correct-by-
construction case and specifically not the bare `Navigator.of(context).pop()`
from a page `State` that blanked master-detail in PR #1312.

Flow: the source sheet returns a source, bytes are obtained, the crop dialog
opens, Save computes the rect and runs `encodeStoredImage` behind a progress
state, and the dialog pops with ready-to-store bytes. The caller never holds
unbounded bytes.

### When the crop dialog is shown

One rule, applied consistently: the crop dialog opens whenever the user
explicitly chose a photo, and does not open when a photo arrives as a side
effect of another action. Concretely, every source in the source sheet opens
the dialog, while the photo that comes along with a contact during buddy import
is centered automatically. The imported photo can be adjusted afterwards from
the buddy edit page, so nothing is unreachable.

## Section 4: Contacts and entry points

`flutter_contacts: ^2.0.2` is already a dependency,
`NSContactsUsageDescription` already reads "This app uses your contacts to
import dive buddies", and the Podfile already compiles in `PERMISSION_CONTACTS`.
This feature adds no new permission surface.

`FlutterContacts.native.showPicker()` returns only a contact ID, so the
follow-up `FlutterContacts.get()` is what reads data and does require contacts
permission. The existing permission check therefore stays.

### The existing import gains a photo

In `buddy_list_content.dart:365`:

```dart
final fullContact = await FlutterContacts.get(
  contactId,
  properties: {
    ContactProperty.name, ContactProperty.email, ContactProperty.phone,
    ContactProperty.photoFullRes, ContactProperty.photoThumbnail,
  },
);
final raw = fullContact.photo?.fullSize ?? fullContact.photo?.thumbnail;
```

Full resolution first, thumbnail as fallback, since thumbnails are only 96x96
or 150x150. The bytes go through `encodeStoredImage(spec: avatar)` with an
automatic centered crop and no dialog, because the user is mid-import and did
not ask to frame a photo. They can adjust it afterwards from the edit page.

The route builder gains `initialPhoto: extra?['photo'] as Uint8List?` and
`BuddyEditPage` gains a matching `initialPhoto` parameter.

### Master-detail data loss, fixed here

The current code branches:

```dart
if (ResponsiveBreakpoints.isMasterDetail(context)) {
  final state = GoRouterState.of(context);
  context.go('${state.uri.path}?mode=new');        // carries nothing
} else {
  context.push('/buddies/new', extra: {'name': name, 'email': email, 'phone': phone});
}
```

The comment above it says data is passed via query params, but nothing is
passed. Master-detail means viewports at or above 1100pt and contact import is
enabled on iOS, so an iPad in landscape imports a contact and lands on a blank
form, discarding the name, email, and phone just read. A photo would inherit
the same loss.

The fix is deletion. `/buddies/new` already declares
`parentNavigatorKey: rootNavigatorKey` so it renders in the foreground rather
than under a shell or open dialog, which means the plain `context.push` branch
is already correct on every layout and the master-detail special case is
unnecessary.

### Contacts as a photo source for existing buddies

The source sheet gains "Choose from Contacts", shown only for buddies and only
on iOS and Android. The platform guard currently lives as the private
`_isContactImportSupported` getter in `buddy_list_content.dart:80` and is
lifted to a shared helper so both call sites agree by construction rather than
by duplication. It
runs the same permission check and native picker, requests only the two photo
properties, and routes the result through the crop dialog, because here the
user is explicitly choosing a photo.

The three existing snackbar strings cover unsupported platform, denied
permission, and failed contact load. One new string is needed for a contact
that has no photo, which is common and must not read as an error.

## Section 5: The shared widget

```dart
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.photo,        // Uint8List?
    required this.initials,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.ringColor,             // buddy_list_tile draws a role ring
  });
}
```

Photo present renders it, photo absent falls back to `initials`, preserving
today's behavior. Both entities already document their `initials` getter as
being for avatar display.

The widget wraps in `ResizeImage(MemoryImage(bytes), width: target, height:
target)` with the target computed from `radius * 2 * devicePixelRatio`. Flutter
decodes to intrinsic size, so a bare `MemoryImage` would hold a 512x512x4 byte
bitmap, about 1 MB, for an avatar drawn at 40 logical pixels. A list of 200
buddies would hold roughly 200 MB of decoded bitmaps.

The bytes must not be copied on the way through. `MemoryImage` equality is
identity-based on the `Uint8List`, and that is what keys Flutter's image cache,
so a defensive copy would mint a fresh cache key each rebuild and re-decode
every avatar every frame.

### Rollout

All 13 `CircleAvatar` sites: `buddy_summary_widget`, `buddy_edit_page` (x2),
`buddy_list_tile`, `buddy_detail_page` (x2), `buddy_picker` (x3),
`diver_switcher_sheet`, `diver_summary_widget` (x2), `diver_profile_hub_page`.

Three are substantive rather than mechanical:

- `buddy_detail_page.dart:417` loses the `AssetImage(photoPath)` bug entirely.
- `buddy_list_tile.dart:293` loses its `File` / `existsSync` / `FileImage`
  block, because `photoPath` is dead.
- `buddy_edit_page.dart:307` turns the stub into a real tappable avatar with
  the camera badge it already draws. `buddies_label_photoComingSoon` is deleted
  from all 11 locale files.

Table rows need one opt-in addition: an optional `leadingBuilder` on
`EntityTableView`, null for every other entity so no existing table changes. A
photo is not a sortable text value, so it does not join `BuddyField`, which
also avoids the saved-layout breakage that renaming that enum causes.

The diver entry point is the active-diver card at
`diver_profile_hub_page.dart:130`, which becomes tappable.

## Section 6: Testing

| Layer | Coverage |
| --- | --- |
| Pure geometry | `cropRectInSourcePixels` at identity, zoomed, panned, clamped; same matrix at two surface sizes proves DPR independence |
| Codec | Square guarantee, never upscales, EXIF orientation 6 fixture comes out upright, `undecodable`, `tooLarge`, cert spec preserves aspect ratio |
| Migration | `migration_v180_profile_photo_test.dart`, plus a `beforeOpen` backstop case for a database that never ran `onUpgrade` |
| Sync | `sync_blob_base64_test.dart` gains diver and buddy round-trips asserting the wire value is a base64 string, not a byte array |
| Repository | Create, update, read round-trip, and that `Buddy.copyWith(clearPhoto: true)` actually clears |
| Widget | Initials fallback, crop dialog Save returns bytes, source sheet hides Contacts on desktop |
| Contacts | Import with a fake contact, the no-photo case, and an iPad-landscape regression test via `testAppInShell` |

Progress-state tests pump manually rather than using `pumpAndSettle`.
Multi-pointer gesture tests end with a trailing 500ms pump to drain the
double-tap recognizer timer.

## Localization

New strings for the source sheet, crop dialog, remove-photo confirmation, and
the contact-has-no-photo case, across all 11 locales.
`buddies_label_photoComingSoon` is removed. The ARB parity test enforces both.

## Out of scope

To be filed rather than built:

- PDF export embedding of profile photos.
- Bulk address-book matching of existing buddies.
- `Species.photoPath`, which is genuinely reference data.
- Backfilling already-oversized certification photos.
- The missing `bakeOrientation` in `image_resize_job.dart`, which leaves
  media-store thumbnails of EXIF-rotated photos rendering rotated.

## Risks

- PR #1374 landed and took v180, so this feature claims v181. Re-verify against
  `origin/main` again before claiming it: the ladder moved twice while this
  design was being written.
- Decode memory on desktop, mitigated by the `maxSourcePixels` ceiling.
- Image cache pressure, mitigated by `ResizeImage`.
