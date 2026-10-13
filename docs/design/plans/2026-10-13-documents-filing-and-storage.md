# Documents: filing, gear files, viewing and storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a document be filed under any record from the Documents form, bring the old gear attachments into the library, make PDFs readable on the detail page, surface trip documents, title certification cards by their certification, and give deleted document space back to the disk.

**Architecture:** Presentation changes in `features/documents`, `features/trips` and `features/settings`; one new data service (`EquipmentFileConverter`) that reuses `DocumentRepository.save` and `MediaRepository.deleteMedia`; a new `core/database/compaction/` unit (prefs, space reading, VACUUM runner, monitor) with a small hook in `DatabaseService.initialize` and the startup page. No schema change.

**Tech Stack:** Flutter, Riverpod 3, Drift (SQLCipher), SharedPreferences, go_router, pdfrx.

**Spec:** `docs/design/specs/2026-10-13-documents-filing-and-storage-design.md`

Issue: #3333. Release: v1.8.2.

## Global Constraints

- One owner per document; no schema change, no sync serializer change.
- Certification card documents: owner locked, Title field hidden, displayed title = certification name (derived, never stored).
- Converted gear file: id `documentEquipmentFileId(mediaId)` (UUIDv5, namespace `kDocumentNamespace`, key `equipmentFile:<mediaId>`), page id `documentEquipmentFilePageId(documentId)`, type `receipt`, title = file name without extension, notes = media caption.
- Library page cap: `kMaxDocumentPageBytes` (10 MB). Accepted kinds: `checkDocumentFile`.
- Compaction threshold: reclaimable >= 50 MB AND >= 25% of the file. Backoff after a failure: 7 days. Manual Compact shown at >= 1 MB reclaimable; it ignores threshold and backoff.
- Preference keys (per device, never synced): `compactDatabaseAtNextLaunch` (bool), `compactDatabaseBackoffUntil` (int ms), `equipmentFileConversionSkipped` (string list of media ids).
- Compaction runs only when `DatabaseService.initialize(compaction: ...)` is passed a non-null prefs object; only the startup page passes one.
- No em-dashes anywhere (code, comments, docs, commits). No mention of any AI tool in code, commits or the PR.
- New user-facing strings go into `app_en.arb` during their task; Task 13 translates them into all 10 locales and runs `flutter gen-l10n` last.
- Paths built with `p.join`; temp space through `Directory.systemTemp`.
- Tests that touch process-wide state restore it (`addTearDown`).
- Stage explicit paths only; never `git add` a directory.

## Review Focus

1. A document refiled to a record that is later deleted: the owner's delete path must still remove it (it uses the owner column, which `save` now sets). Task 4 test: refile, then `deleteForOwner` removes it.
2. A gear file whose equipment row was deleted but the media row survived (`equipment_id` SET NULL leaves it null, so it is not selected) and a media row whose equipment has a null `diver_id`: skipped, not crashed. Task 7 test.
3. Two converter runs overlapping (launch pass and a post-sync pass): must not double-insert or throw. Task 8 test: concurrent `run()` calls convert once.
4. Compaction on a database whose WAL holds uncheckpointed frames: the file must still end smaller. Task 10 test writes, deletes and compacts a real WAL file.
5. The details panel on a short phone screen in landscape: the viewer keeps at least half the height. Task 5 test at 800x400.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/features/documents/presentation/document_l10n.dart` (modify) | `documentDisplayTitle` gains `ownerLabel` |
| `lib/features/documents/data/repositories/document_owner_options_repository.dart` (create) | Records of one owner kind for the picker |
| `lib/features/documents/presentation/widgets/document_owner_picker_sheet.dart` (create) | The kind + record picker sheet |
| `lib/features/documents/presentation/widgets/document_owner_field.dart` (create) | "Filed under" form field |
| `lib/features/documents/presentation/providers/document_owner_providers.dart` (create) | Options and label providers |
| `lib/features/documents/presentation/pages/document_edit_page.dart` (modify) | Owner state, field, save |
| `lib/features/documents/presentation/widgets/document_form_fields.dart` (modify) | Hide Title for cards |
| `lib/features/documents/presentation/pages/document_detail_page.dart` (modify) | Full-height viewer layout |
| `lib/features/documents/presentation/widgets/document_details_panel.dart` (create) | Collapsible details panel |
| `lib/features/trips/presentation/widgets/story/trip_story_view.dart` (modify) | Move Documents sliver |
| `lib/features/documents/domain/document_ids.dart` (modify) | Gear file ids |
| `lib/features/documents/data/services/equipment_file_converter.dart` (create) | Conversion pass |
| `lib/features/documents/presentation/providers/equipment_file_conversion_provider.dart` (create) | Wiring, single flight |
| `lib/features/equipment/presentation/widgets/equipment_documents_section.dart` (modify) | "Linked files", hidden when empty |
| `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (modify) | No attach action |
| `lib/core/database/compaction/database_compaction_prefs.dart` (create) | Request and backoff prefs |
| `lib/core/database/compaction/database_space.dart` (create) | Pragmas, threshold |
| `lib/core/database/compaction/compact_database_file.dart` (create) | VACUUM + checkpoint in an isolate |
| `lib/core/database/compaction/database_compaction_monitor.dart` (create) | Decide and request |
| `lib/core/services/database_service.dart` (modify) | Startup compaction hook |
| `lib/core/presentation/pages/startup_page.dart` (modify) | Pass prefs, compacting state |
| `lib/features/settings/presentation/widgets/database_reclaim_row.dart` (create) | Reclaimable line, Compact, Cancel |
| `lib/features/settings/presentation/pages/storage_usage_page.dart` (modify) | Show the reclaim row under Database |
| `lib/app.dart`, `lib/features/settings/presentation/providers/sync_providers.dart` (modify) | Launch and post-sync triggers |

---

### Task 1: Certification card titles

**Files:**
- Modify: `lib/features/documents/presentation/document_l10n.dart`
- Modify: `lib/features/documents/presentation/widgets/document_tile.dart`
- Modify: `lib/features/documents/presentation/pages/document_detail_page.dart:93`
- Modify: `lib/features/documents/presentation/widgets/document_form_fields.dart`
- Test: `test/features/documents/presentation/document_l10n_test.dart`, `test/features/documents/presentation/widgets/document_widgets_test.dart`

**Interfaces:**
- Produces: `String documentDisplayTitle(AppLocalizations l10n, Document document, {String? ownerLabel})`

- [ ] **Step 1: Failing tests.** In `document_l10n_test.dart` add:

```dart
test('a card document is titled by its certification', () {
  final card = doc('').copyWith(
    type: DocumentType.certificationCard,
    owner: const DocumentOwner(DocumentOwnerKind.certification, 'c1'),
  );
  expect(
    documentDisplayTitle(l10n, card, ownerLabel: 'Advanced Nitrox'),
    'Advanced Nitrox',
  );
  expect(documentDisplayTitle(l10n, card), 'Certification card');
  expect(
    documentDisplayTitle(l10n, doc('Marine park'), ownerLabel: 'Bonaire'),
    'Marine park',
  );
});
```

In `document_widgets_test.dart` add a tile test: a card document with `ownerLabel: 'Advanced Nitrox'` shows `'Advanced Nitrox'` once (`findsOneWidget`), so the subtitle does not repeat it. And a form test: `DocumentFormFields(type: DocumentType.certificationCard, ...)` finds no `Key('document-title')`.

- [ ] **Step 2: Run, expect FAIL** (`ownerLabel` is not a parameter).

`flutter test test/features/documents/presentation/document_l10n_test.dart test/features/documents/presentation/widgets/document_widgets_test.dart`

- [ ] **Step 3: Implement.** `document_l10n.dart`:

```dart
/// The document's own title, or its type's name when it has none, so a
/// default title follows the app language. A certification card is titled
/// by its certification ([ownerLabel], the certification's name), so a
/// rename shows everywhere without a second write.
String documentDisplayTitle(
  AppLocalizations l10n,
  Document document, {
  String? ownerLabel,
}) {
  final label = ownerLabel?.trim() ?? '';
  if (document.type == DocumentType.certificationCard && label.isNotEmpty) {
    return label;
  }
  final title = document.title.trim();
  return title.isEmpty ? documentTypeLabel(l10n, document.type) : title;
}
```

`document_tile.dart`: compute `final card = document.type == DocumentType.certificationCard;`, build details with `if (!card) ?ownerLabel,`, and call `documentDisplayTitle(l10n, document, ownerLabel: ownerLabel)`.

`document_detail_page.dart:93`: `title: Text(documentDisplayTitle(l10n, doc, ownerLabel: entry.ownerLabel)),`.

`document_form_fields.dart`: wrap the Title `TextFormField` and the `gap` after it in `if (!_card) ...[ ... ]`.

- [ ] **Step 4: Run, expect PASS.** Same command.
- [ ] **Step 5: Commit.** `git add` the five files; `git commit -m "feat(documents): title certification cards by their certification"`.

---

### Task 2: Owner options repository

**Files:**
- Create: `lib/features/documents/data/repositories/document_owner_options_repository.dart`
- Test: `test/features/documents/data/repositories/document_owner_options_repository_test.dart`

**Interfaces:**
- Produces:

```dart
class DocumentOwnerOption {
  final String id;
  final String label;
  final String? subtitle;
  final DateTime? date;
  const DocumentOwnerOption(this.id, this.label, {this.subtitle, this.date});
}
class DocumentOwnerOptionsRepository {
  Future<List<DocumentOwnerOption>> optionsFor(DocumentOwnerKind kind, {required String diverId});
  Future<String?> labelFor(DocumentOwner owner);
}
```

- [ ] **Step 1: Failing test.** Using `setUpTestDatabase()` and raw inserts (divers `d1`, `d2`; one row per kind for `d1`, one trip for `d2`; one `dive_sites` row with `shared_library_id = 'lib1'`; a dive `#12` at site "Salt Pier" on 2026-09-01):

```dart
test('lists the diver\'s records of a kind, newest dives first', () async {
  final repo = DocumentOwnerOptionsRepository();
  final trips = await repo.optionsFor(DocumentOwnerKind.trip, diverId: 'd1');
  expect(trips.map((o) => o.label), ['Bonaire']);
  final dives = await repo.optionsFor(DocumentOwnerKind.dive, diverId: 'd1');
  expect(dives.single.label, '#12');
  expect(dives.single.subtitle, 'Salt Pier');
});

test('club library sites are not offered', () async {
  final sites = await DocumentOwnerOptionsRepository()
      .optionsFor(DocumentOwnerKind.site, diverId: 'd1');
  expect(sites.map((o) => o.label), ['Salt Pier']);
});

test('labelFor names a record and is null for personal', () async {
  final repo = DocumentOwnerOptionsRepository();
  expect(await repo.labelFor(const DocumentOwner(DocumentOwnerKind.trip, 't1')), 'Bonaire');
  expect(await repo.labelFor(const DocumentOwner.personal()), isNull);
});

test('personal has no options', () async {
  expect(
    await DocumentOwnerOptionsRepository()
        .optionsFor(DocumentOwnerKind.personal, diverId: 'd1'),
    isEmpty,
  );
});
```

The dive date is not in the subtitle string (dates are formatted in the UI with the diver's settings); the option carries `date`, so also assert `dives.single.date == DateTime(2026, 9, 1, 9)`.

- [ ] **Step 2: Run, expect FAIL** (file missing).
- [ ] **Step 3: Implement.**

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

/// One record a document can be filed under, as the owner picker lists it.
class DocumentOwnerOption {
  final String id;
  final String label;
  final String? subtitle;

  /// Dives only: when it was, formatted by the picker.
  final DateTime? date;

  const DocumentOwnerOption(this.id, this.label, {this.subtitle, this.date});
}

/// The records of one owner kind a diver can file a document under.
/// Club library sites are left out: their rows live in another library,
/// so a personal document filed there would sync a link peers lack.
class DocumentOwnerOptionsRepository {
  AppDatabase get _db => DatabaseService.instance.database;

  static const Map<DocumentOwnerKind, String> _tables = {
    DocumentOwnerKind.site: 'dive_sites',
    DocumentOwnerKind.trip: 'trips',
    DocumentOwnerKind.equipment: 'equipment',
    DocumentOwnerKind.course: 'courses',
    DocumentOwnerKind.certification: 'certifications',
    DocumentOwnerKind.buddy: 'buddies',
    DocumentOwnerKind.diveCenter: 'dive_centers',
  };

  Future<List<DocumentOwnerOption>> optionsFor(
    DocumentOwnerKind kind, {
    required String diverId,
  }) async {
    if (kind == DocumentOwnerKind.personal) return const [];
    if (kind == DocumentOwnerKind.dive) return _dives(diverId);
    final table = _tables[kind]!;
    final libraryFilter = kind == DocumentOwnerKind.site
        ? 'AND shared_library_id IS NULL '
        : '';
    final order = kind == DocumentOwnerKind.trip
        ? 'start_date DESC, name'
        : 'name COLLATE NOCASE';
    final rows = await _db
        .customSelect(
          'SELECT id, name FROM $table WHERE diver_id = ? $libraryFilter'
          'ORDER BY $order',
          variables: [Variable.withString(diverId)],
        )
        .get();
    return [
      for (final r in rows)
        DocumentOwnerOption(r.read<String>('id'), r.read<String>('name')),
    ];
  }

  Future<List<DocumentOwnerOption>> _dives(String diverId) async {
    final rows = await _db
        .customSelect(
          'SELECT d.id, d.dive_number, d.dive_date_time, s.name AS site '
          'FROM dives d LEFT JOIN dive_sites s ON s.id = d.site_id '
          'WHERE d.diver_id = ? ORDER BY d.dive_date_time DESC',
          variables: [Variable.withString(diverId)],
        )
        .get();
    return [
      for (final r in rows)
        DocumentOwnerOption(
          r.read<String>('id'),
          r.readNullable<int>('dive_number') == null
              ? ''
              : '#${r.read<int>('dive_number')}',
          subtitle: r.readNullable<String>('site'),
          date: switch (r.readNullable<int>('dive_date_time')) {
            final ms? => DateTime.fromMillisecondsSinceEpoch(ms),
            null => null,
          },
        ),
    ];
  }

  /// The display name of [owner]'s record; null for personal or a record
  /// that no longer exists.
  Future<String?> labelFor(DocumentOwner owner) async {
    final id = owner.id;
    if (id == null) return null;
    if (owner.kind == DocumentOwnerKind.dive) {
      final row = await _db
          .customSelect(
            'SELECT dive_number FROM dives WHERE id = ?',
            variables: [Variable.withString(id)],
          )
          .getSingleOrNull();
      final n = row?.readNullable<int>('dive_number');
      return row == null ? null : (n == null ? '' : '#$n');
    }
    final row = await _db
        .customSelect(
          'SELECT name FROM ${_tables[owner.kind]} WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    return row?.read<String>('name');
  }
}
```

Check `dive_date_time` storage against `lib/core/database/tables/dive_tables.dart:27` before running: if it is stored in seconds, convert accordingly and fix the test's expectation from the same column. The picker formats an empty dive label as the date alone (Task 3).

- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(documents): list the records a document can be filed under`.

---

### Task 3: Owner picker sheet

**Files:**
- Create: `lib/features/documents/presentation/providers/document_owner_providers.dart`
- Create: `lib/features/documents/presentation/widgets/document_owner_picker_sheet.dart`
- Modify: `lib/l10n/arb/app_en.arb` (after `documents_detail_owner`)
- Test: `test/features/documents/presentation/widgets/document_owner_picker_sheet_test.dart`

**Interfaces:**
- Consumes: Task 2.
- Produces:

```dart
final documentOwnerOptionsRepositoryProvider = Provider<DocumentOwnerOptionsRepository>(...);
final documentOwnerOptionsProvider = FutureProvider.autoDispose.family<List<DocumentOwnerOption>, DocumentOwnerKind>(...);
final documentOwnerLabelProvider = FutureProvider.autoDispose.family<String?, DocumentOwner>(...);
Future<DocumentOwner?> showDocumentOwnerPicker(BuildContext context, {required DocumentOwner current});
```

New ARB keys (en):

```json
"documents_owner_field": "Filed under",
"documents_owner_pickerTitle": "File under",
"documents_owner_search": "Search",
"documents_owner_none": "Nothing to file under yet",
"documents_owner_locked": "A card stays with its certification",
```

- [ ] **Step 1: Failing widget test.** Pump a button that calls `showDocumentOwnerPicker(context, current: const DocumentOwner.personal())` and stores the result, with `documentOwnerOptionsProvider` overridden: trip -> `[DocumentOwnerOption('t1', 'Bonaire'), DocumentOwnerOption('t2', 'Red Sea')]`, others -> `[]`, and `validatedCurrentDiverIdProvider` -> `'d1'`. Tests:

```dart
testWidgets('choosing a kind then a record returns that owner', (t) async {
  await openPicker(t);
  await t.tap(find.byKey(const ValueKey('owner-kind-trip')));
  await t.pumpAndSettle();
  await t.tap(find.text('Red Sea'));
  await t.pumpAndSettle();
  expect(result, const DocumentOwner(DocumentOwnerKind.trip, 't2'));
});

testWidgets('search narrows the records', (t) async {
  await openPicker(t);
  await t.tap(find.byKey(const ValueKey('owner-kind-trip')));
  await t.pumpAndSettle();
  await t.enterText(find.byKey(const ValueKey('owner-search')), 'bon');
  await t.pumpAndSettle();
  expect(find.text('Bonaire'), findsOneWidget);
  expect(find.text('Red Sea'), findsNothing);
});

testWidgets('Personal returns the personal owner', (t) async {
  await openPicker(t, current: const DocumentOwner(DocumentOwnerKind.trip, 't1'));
  await t.tap(find.byKey(const ValueKey('owner-kind-personal')));
  await t.pumpAndSettle();
  expect(result, const DocumentOwner.personal());
});

testWidgets('an empty kind says so', (t) async {
  await openPicker(t);
  await t.tap(find.byKey(const ValueKey('owner-kind-buddy')));
  await t.pumpAndSettle();
  expect(find.text('Nothing to file under yet'), findsOneWidget);
});
```

`openPicker` pumps `MaterialApp` with `AppLocalizations` delegates and `locale: Locale('en')`, taps the button, `pumpAndSettle`.

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement providers.**

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_owner_options_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';

final documentOwnerOptionsRepositoryProvider =
    Provider<DocumentOwnerOptionsRepository>(
      (ref) => DocumentOwnerOptionsRepository(),
    );

/// The active diver's records of one kind, for the owner picker. Read
/// while the sheet is open only, so no change stream is needed.
// no-tick: read for the lifetime of one open sheet, disposed with it.
final documentOwnerOptionsProvider = FutureProvider.autoDispose
    .family<List<DocumentOwnerOption>, DocumentOwnerKind>((ref, kind) async {
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      if (diverId == null) return const [];
      return ref
          .watch(documentOwnerOptionsRepositoryProvider)
          .optionsFor(kind, diverId: diverId);
    });

/// The name of the record a form's owner points at.
final documentOwnerLabelProvider = FutureProvider.autoDispose
    .family<String?, DocumentOwner>((ref, owner) async {
      ref.invalidateSelfWhen(ref.watch(documentRepositoryProvider).watchChanges());
      return ref.watch(documentOwnerOptionsRepositoryProvider).labelFor(owner);
    });
```

If `test/architecture/provider_tick_*` flags `documentOwnerOptionsProvider`, follow the scanner's message (its accepted marker is the `// no-tick:` comment form used by `galleryOriginBackfillProvider`).

- [ ] **Step 4: Implement the sheet.** A `ConsumerStatefulWidget` `_OwnerPickerSheet` in a `DraggableScrollableSheet` (initial 0.7, max 0.95) shown by `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)`:
  - Title `documents_owner_pickerTitle`.
  - `Wrap` of `ChoiceChip`s, one per `DocumentOwnerKind`, key `ValueKey('owner-kind-${kind.name}')`, label `documentOwnerKindLabel`, avatar `Icon(_kindIcon(kind))`. Selecting `personal` pops `const DocumentOwner.personal()` immediately.
  - For a selected non-personal kind: `TextField` key `ValueKey('owner-search')`, then the list from `ref.watch(documentOwnerOptionsProvider(kind))`, filtered by `label`/`subtitle` containing the lowercased query. Each row is a `ListTile` with title `option.label.isEmpty ? formattedDate : option.label`, subtitle joining `subtitle` and the formatted `date` (format with `UnitFormatter(ref.watch(settingsProvider)).formatDate`), `selected` when `current == DocumentOwner(kind, option.id)`, `onTap` pops `DocumentOwner(kind, option.id)`.
  - Empty list: centered `documents_owner_none`.
  - Starts with `current.kind` selected (or no kind when personal).
  - `_kindIcon`: personal `Icons.person_outline`, dive `Icons.scuba_diving`, site `Icons.place_outlined`, trip `Icons.luggage_outlined`, equipment `Icons.backpack_outlined`, course `Icons.school_outlined`, certification `Icons.card_membership_outlined`, buddy `Icons.people_outline`, diveCenter `Icons.storefront_outlined`.

- [ ] **Step 5: Add the ARB keys** by anchored insertion after `"documents_detail_owner"` in `app_en.arb` (never JSON round-trip the file), then `flutter gen-l10n`.
- [ ] **Step 6: Run, expect PASS.**
- [ ] **Step 7: Commit** `feat(documents): owner picker sheet`.

---

### Task 4: Filed under field on the form

**Files:**
- Create: `lib/features/documents/presentation/widgets/document_owner_field.dart`
- Modify: `lib/features/documents/presentation/pages/document_edit_page.dart`
- Test: `test/features/documents/presentation/pages/document_edit_page_test.dart`, `test/features/documents/data/owner_delete_documents_test.dart`

**Interfaces:**
- Consumes: Task 3 (`showDocumentOwnerPicker`, `documentOwnerLabelProvider`, `documents_owner_field`, `documents_owner_locked`).
- Produces: `DocumentOwnerField({required DocumentOwner owner, required bool locked, required VoidCallback onTap})`, key `ValueKey('document-owner-field')`; `DocumentEditPage.pickOwner` test seam.

- [ ] **Step 1: Failing tests** in `document_edit_page_test.dart` (existing harness, real test database):

```dart
testWidgets('a personal document can be filed under a trip', (t) async {
  final doc = await saveDoc('Booking', DocumentType.booking);
  await pumpEdit(t, documentId: doc.id, extra: [
    showDocumentOwnerPickerOverride(const DocumentOwner(DocumentOwnerKind.trip, 't1')),
  ]);
  await t.tap(find.byKey(const ValueKey('document-owner-field')));
  await t.pumpAndSettle();
  await t.tap(find.text('Save'));
  await t.pumpAndSettle();
  final saved = await DocumentRepository().getById(doc.id);
  expect(saved!.owner, const DocumentOwner(DocumentOwnerKind.trip, 't1'));
});

testWidgets('moving clears the old owner column', (t) async {
  final doc = await saveDoc('Booking', DocumentType.booking,
      owner: const DocumentOwner(DocumentOwnerKind.trip, 't1'));
  // pick Personal
  ...
  final row = await (db.select(db.documents)..where((d) => d.id.equals(doc.id))).getSingle();
  expect(row.tripId, isNull);
});

testWidgets('a new document starts at the owner it was opened from', (t) async {
  await pumpEdit(t, owner: const DocumentOwner(DocumentOwnerKind.trip, 't1'));
  expect(find.text('Bonaire'), findsOneWidget);
});

testWidgets('a card document cannot be moved', (t) async {
  // card doc owned by certification c1
  await t.tap(find.byKey(const ValueKey('document-owner-field')));
  await t.pumpAndSettle();
  expect(find.byType(BottomSheet), findsNothing);
  expect(find.text('A card stays with its certification'), findsOneWidget);
});
```

The picker is reached through a test seam so the page test does not drive the sheet: add `@visibleForTesting final Future<DocumentOwner?> Function(BuildContext, DocumentOwner)? pickOwner;` to `DocumentEditPage`, default `showDocumentOwnerPicker`. Replace `showDocumentOwnerPickerOverride(...)` above with passing `pickOwner: (_, _) async => owner` into the page.

In `owner_delete_documents_test.dart` add: a document saved Personal, then saved again with owner trip `t1`, is removed by `DocumentRepository().deleteForOwner(DocumentOwnerKind.trip, 't1')` (Review Focus 1).

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement the field.**

```dart
/// "Filed under": the record a document belongs to. Tapping opens the owner
/// picker; a certification card is locked to its certification.
class DocumentOwnerField extends ConsumerWidget {
  final DocumentOwner owner;
  final bool locked;
  final VoidCallback onTap;

  const DocumentOwnerField({
    super.key = const ValueKey('document-owner-field'),
    required this.owner,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final kind = documentOwnerKindLabel(l10n, owner.kind);
    final name = owner.isPersonal
        ? null
        : ref.watch(documentOwnerLabelProvider(owner)).value;
    return InkWell(
      onTap: locked ? null : onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.documents_owner_field,
          helperText: locked ? l10n.documents_owner_locked : null,
          suffixIcon: locked ? const Icon(Icons.lock_outline) : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(name == null || name.isEmpty ? kind : '$kind: $name'),
      ),
    );
  }
}
```

- [ ] **Step 4: Wire the page.** In `_DocumentEditPageState`: `late DocumentOwner _owner = widget.owner;`; in `_load` set `_owner = doc.owner;`; a method

```dart
Future<void> _pickOwner() async {
  final pick = widget.pickOwner ?? showDocumentOwnerPicker;
  final chosen = await pick(context, _owner);
  if (chosen == null || chosen == _owner) return;
  _change(() => _owner = chosen);
}
```

Render `DocumentOwnerField(owner: _owner, locked: _type == DocumentType.certificationCard, onTap: _pickOwner)` above `DocumentFormFields` with a 16 px gap. In `_save`, `owner: _owner,`. Update the `owner` doc comment: "Where a new document starts filed; the form can change it."

- [ ] **Step 5: Run, expect PASS** for both test files and the whole `test/features/documents/`.
- [ ] **Step 6: Commit** `feat(documents): file or refile a document from its form`.

---

### Task 5: Detail page layout

**Files:**
- Create: `lib/features/documents/presentation/widgets/document_details_panel.dart`
- Modify: `lib/features/documents/presentation/pages/document_detail_page.dart`
- Test: `test/features/documents/presentation/pages/document_detail_layout_test.dart`

**Interfaces:**
- Produces: `DocumentDetailsPanel({required DocumentListEntry entry, required bool initiallyExpanded})`; `_DetailsCard` moves into this file as `DocumentDetailsCard` (public, same constructor `document`, `ownerLabel`), and `_Row` with it.

- [ ] **Step 1: Failing test.** Real test database, one document with one image page (any small PNG bytes), pushed `DocumentDetailPage` under a `GoRouter` whose initial route is a page that pushes it (so `canPop` is true):

```dart
testWidgets('the viewer takes the height the details do not need', (t) async {
  await pumpDetail(t, size: const Size(420, 900));
  final viewer = t.getSize(find.byType(DocumentPageViewer));
  expect(viewer.height, greaterThan(600));
});

testWidgets('details start collapsed and expand', (t) async {
  await pumpDetail(t, size: const Size(420, 900));
  expect(find.text('Issuer'), findsNothing);
  await t.tap(find.byKey(const ValueKey('document-details-toggle')));
  await t.pumpAndSettle();
  expect(find.text('Issuer'), findsOneWidget);
});

testWidgets('a short landscape screen keeps half for the viewer', (t) async {
  await pumpDetail(t, size: const Size(800, 400));
  await t.tap(find.byKey(const ValueKey('document-details-toggle')));
  await t.pumpAndSettle();
  final h = t.getSize(find.byType(DocumentPageViewer)).height;
  expect(h, greaterThanOrEqualTo(400 / 2 - kToolbarHeight));
});

testWidgets('wide screens put the details beside the viewer', (t) async {
  await pumpDetail(t, size: const Size(1200, 800));
  final viewer = t.getRect(find.byType(DocumentPageViewer));
  final card = t.getRect(find.byType(DocumentDetailsCard));
  expect(card.left, greaterThanOrEqualTo(viewer.right));
});
```

The document saved in the harness has `issuer: 'DAN'` so the Issuer row exists.

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement the panel.**

```dart
/// The details under a document's pages. Collapsed it is one line (type,
/// expiry badge, where it is filed) so the pages get the screen; expanded
/// it shows every detail and scrolls within half the height.
class DocumentDetailsPanel extends StatefulWidget {
  final DocumentListEntry entry;
  const DocumentDetailsPanel({super.key, required this.entry});
  @override
  State<DocumentDetailsPanel> createState() => _DocumentDetailsPanelState();
}

class _DocumentDetailsPanelState extends State<DocumentDetailsPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final doc = widget.entry.document;
    final status = documentExpiryStatus(doc, DateTime.now());
    final summary = [
      documentTypeLabel(l10n, doc.type),
      widget.entry.ownerLabel ?? documentOwnerKindLabel(l10n, doc.owner.kind),
    ].join(' · ');
    return LayoutBuilder(
      builder: (context, _) {
        final maxHeight = MediaQuery.sizeOf(context).height / 2;
        return Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const ValueKey('document-details-toggle'),
                leading: Icon(documentTypeIcon(doc.type)),
                title: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: status.needsAttention ? DocumentExpiryBadge(status: status) : null,
                trailing: Icon(_expanded ? Icons.expand_more : Icons.expand_less),
                onTap: () => setState(() => _expanded = !_expanded),
              ),
              if (_expanded)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: SingleChildScrollView(
                    child: DocumentDetailsCard(
                      document: doc,
                      ownerLabel: widget.entry.ownerLabel,
                      flat: true,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
```

`DocumentDetailsCard` gains `final bool flat;` (default false): when true it returns its `Column` without the outer `Card`.

- [ ] **Step 4: Rewrite the page body.** Replace the `ListView` with:

```dart
body: LayoutBuilder(
  builder: (context, constraints) {
    final viewer = pages.when(
      data: (list) => list.isEmpty
          ? Center(child: Icon(documentTypeIcon(doc.type), size: 64,
              color: Theme.of(context).colorScheme.outline))
          : DocumentPageViewer(pages: list),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
    if (constraints.maxWidth >= _sideBySideWidth) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: viewer),
          SizedBox(
            width: 360,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: DocumentDetailsCard(document: doc, ownerLabel: entry.ownerLabel),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(child: viewer),
        DocumentDetailsPanel(entry: entry),
      ],
    );
  },
),
```

with `static const double _sideBySideWidth = 840;` on the state class, commented: "Wide enough for a readable page beside a 360 px details column."

- [ ] **Step 5: Run** the new test and `test/features/documents/`, expect PASS.
- [ ] **Step 6: Commit** `fix(documents): let a document's pages fill the detail page`.

---

### Task 6: Trip documents under the stat strip

**Files:**
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_view.dart:138-205`
- Test: `test/features/trips/presentation/widgets/story/trip_story_view_test.dart`

- [ ] **Step 1: Failing tests.**

```dart
testWidgets('the Documents card comes before the first day', (tester) async {
  final trip = _trip(start: DateTime(2026, 3, 27), end: DateTime(2026, 3, 29));
  final story = _story(trip, dives: [_dive('d1', DateTime(2026, 3, 27, 9))],
      today: DateTime(2026, 6, 1));
  await pumpView(tester, story);
  final docs = tester.getTopLeft(find.byKey(const ValueKey('documents-section-trip')));
  final firstDay = tester.getTopLeft(find.byType(TripStoryDayHeader).first);
  expect(docs.dy, lessThan(firstDay.dy));
});
```

and the same assertion inside the `in progress` group using `longTrip(todayOffset: 0)` (Day 1 is today, so the hero and the Documents card sit above the center).

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Cut the Documents `SliverPadding` out of `trailing` and append it to `header` after the `TripStatStrip` adapter, with padding `EdgeInsets.fromLTRB(16, 12, 16, 4)`. Add a comment: "Right under the stats, so a long trip's papers are not below every day."
- [ ] **Step 4: Run the whole story view test file, expect PASS.**
- [ ] **Step 5: Commit** `fix(trips): show a trip's documents under its stats`.

---

### Task 7: Equipment file converter

**Files:**
- Modify: `lib/features/documents/domain/document_ids.dart`
- Create: `lib/features/documents/data/services/equipment_file_converter.dart`
- Test: `test/features/documents/domain/document_ids_test.dart`, `test/features/documents/data/services/equipment_file_converter_test.dart`

**Interfaces:**
- Produces:

```dart
String documentEquipmentFileId(String mediaId);
String documentEquipmentFilePageId(String documentId);

typedef MediaBytesReader = Future<Uint8List?> Function(MediaItem item);

class EquipmentFileConversionResult {
  final int converted;
  final int remaining;
  const EquipmentFileConversionResult(this.converted, this.remaining);
}

class EquipmentFileConverter {
  EquipmentFileConverter({
    required MediaBytesReader readBytes,
    required SharedPreferences prefs,
    DocumentRepository? documents,
    MediaRepository? media,
  });
  static const skippedKey = 'equipmentFileConversionSkipped';
  Future<EquipmentFileConversionResult> run();
}
```

- [ ] **Step 1: Failing id test.**

```dart
test('gear file ids are stable and distinct', () {
  expect(documentEquipmentFileId('m1'), documentEquipmentFileId('m1'));
  expect(documentEquipmentFileId('m1'), isNot(documentEquipmentFileId('m2')));
  expect(documentEquipmentFilePageId(documentEquipmentFileId('m1')),
      isNot(documentEquipmentFileId('m1')));
});
```

- [ ] **Step 2: Implement ids** in `document_ids.dart`:

```dart
/// A library document converted from a file linked to a piece of gear by
/// the older attachment card (#1517). Derived from the media row, so two
/// devices converting the same file produce the same document.
String documentEquipmentFileId(String mediaId) => _v5('equipmentFile:$mediaId');

/// The single page of a converted gear file.
String documentEquipmentFilePageId(String documentId) =>
    _v5('equipmentFilePage:$documentId');
```

- [ ] **Step 3: Failing converter tests.** `setUpTestDatabase()`; `SharedPreferences.setMockInitialValues({})`; diver `d1`; equipment `e1` (diver `d1`) and `e2` (diver NULL); media rows inserted with `INSERT INTO media (id, equipment_id, file_path, original_filename, file_type, caption, created_at, updated_at)`:

| id | equipment | file | reader returns |
| --- | --- | --- | --- |
| m1 | e1 | Invoice.pdf | 1 KB of bytes, caption 'Bought in Kona' |
| m2 | e1 | Track.gpx | (never asked) |
| m3 | e1 | Manual.pdf | null (unavailable) |
| m4 | e1 | Huge.pdf | 11 MB |
| m5 | e2 | Orphan.pdf | 1 KB |

```dart
test('converts a readable file into a receipt filed under the gear', () async {
  final result = await converter().run();
  final doc = await DocumentRepository().getById(documentEquipmentFileId('m1'));
  expect(doc!.owner, const DocumentOwner(DocumentOwnerKind.equipment, 'e1'));
  expect(doc.type, DocumentType.receipt);
  expect(doc.title, 'Invoice');
  expect(doc.notes, 'Bought in Kona');
  expect((await DocumentRepository().getPages(doc.id)).single.mimeType, 'application/pdf');
  expect(await mediaIds(), isNot(contains('m1')));
  expect(await tombstones('media'), contains('m1'));
  expect(result.converted, 1);
});

test('leaves what it cannot convert, and does not re-read an oversize file', () async {
  await converter().run();
  expect(await mediaIds(), containsAll(['m2', 'm3', 'm4']));
  expect(prefs.getStringList(EquipmentFileConverter.skippedKey), ['m4']);
  reads.clear();
  await converter().run();
  expect(reads, isNot(contains('m4')));
  expect(reads, isNot(contains('m2')));
  expect(reads, contains('m3'));
});

test('gear with no diver is skipped, not crashed', () async {
  await converter().run();
  expect(await mediaIds(), contains('m5'));
});

test('a file a peer already converted only drops the link', () async {
  await saveConvertedDocumentFor('m1'); // DocumentRepository().save with id documentEquipmentFileId('m1'), title 'Peer'
  await converter().run();
  expect((await DocumentRepository().getById(documentEquipmentFileId('m1')))!.title, 'Peer');
  expect(await mediaIds(), isNot(contains('m1')));
});

test('a second run is a no-op', () async {
  await converter().run();
  final second = await converter().run();
  expect(second.converted, 0);
});
```

`converter()` builds `EquipmentFileConverter(readBytes: fakeReader, prefs: prefs)` where `fakeReader` records `item.id` into `reads` and returns the table's bytes. `mediaIds()` selects `id FROM media`; `tombstones(entity)` reads the sync deletion log through the same table `SyncRepository.logDeletion` writes (check its name in `lib/core/data/repositories/sync_repository.dart`).

- [ ] **Step 4: Run, expect FAIL.**
- [ ] **Step 5: Implement.**

```dart
/// Moves files linked to gear by the older attachment card (#1517) into the
/// Documents library, so they show in Documents and can be refiled.
///
/// Runs at launch and after each sync, and is safe to repeat: a converted
/// file's media row is gone, a document a peer already converted is kept as
/// it is, a file this device cannot read now is tried again next run, and
/// one the library can never hold (a kind it does not accept, or over the
/// page cap) is left on the gear's "Linked files" card. An oversize file
/// is only discovered by reading it, so its id is remembered on this device
/// to spare a re-read of a large file every launch.
class EquipmentFileConverter {
  EquipmentFileConverter({
    required MediaBytesReader readBytes,
    required SharedPreferences prefs,
    DocumentRepository? documents,
    MediaRepository? media,
  }) : _readBytes = readBytes,
       _prefs = prefs,
       _documents = documents ?? DocumentRepository(),
       _media = media ?? MediaRepository();

  static const skippedKey = 'equipmentFileConversionSkipped';

  final MediaBytesReader _readBytes;
  final SharedPreferences _prefs;
  final DocumentRepository _documents;
  final MediaRepository _media;
  final _log = LoggerService.forClass(EquipmentFileConverter);

  AppDatabase get _db => DatabaseService.instance.database;

  Future<EquipmentFileConversionResult> run() async {
    final skipped = {...?_prefs.getStringList(skippedKey)};
    final rows = await _db
        .customSelect(
          'SELECT m.id, e.diver_id FROM media m '
          'JOIN equipment e ON e.id = m.equipment_id '
          'WHERE m.equipment_id IS NOT NULL',
          readsFrom: {_db.media, _db.equipment},
        )
        .get();
    var converted = 0;
    var remaining = 0;
    for (final r in rows) {
      final mediaId = r.read<String>('id');
      final diverId = r.readNullable<String>('diver_id');
      final item = await _media.getMediaById(mediaId);
      if (item == null) continue;
      if (diverId == null || skipped.contains(mediaId) || !_acceptedKind(item)) {
        remaining++;
        continue;
      }
      try {
        if (await _convert(item, diverId, skipped)) {
          converted++;
        } else {
          remaining++;
        }
      } catch (e, stackTrace) {
        remaining++;
        _log.warning('Could not convert gear file $mediaId', error: e, stackTrace: stackTrace);
      }
    }
    await _prefs.setStringList(skippedKey, skipped.toList()..sort());
    if (converted > 0) SyncEventBus.notifyLocalChange();
    return EquipmentFileConversionResult(converted, remaining);
  }

  bool _acceptedKind(MediaItem item) =>
      checkDocumentFile(fileName: item.originalFilename ?? '', sizeBytes: 0)
          is DocumentFileAccepted;

  Future<bool> _convert(MediaItem item, String diverId, Set<String> skipped) async {
    final docId = documentEquipmentFileId(item.id);
    if (await _documents.getById(docId) != null) {
      await _media.deleteMedia(item.id);
      return true;
    }
    final bytes = await _readBytes(item);
    if (bytes == null) return false;
    final name = item.originalFilename ?? p.basename(item.filePath ?? 'file');
    final verdict = checkDocumentFile(fileName: name, sizeBytes: bytes.length);
    if (verdict is DocumentFileTooLarge) {
      skipped.add(item.id);
      return false;
    }
    if (verdict is! DocumentFileAccepted) return false;
    final now = DateTime.now();
    await _db.transaction(() async {
      await _documents.save(
        Document(
          id: docId,
          diverId: diverId,
          owner: DocumentOwner(DocumentOwnerKind.equipment, item.equipmentId!),
          type: DocumentType.receipt,
          title: p.basenameWithoutExtension(name),
          notes: item.caption?.trim() ?? '',
          createdAt: item.createdAt,
          updatedAt: now,
        ),
        [
          DocumentPage(
            id: documentEquipmentFilePageId(docId),
            documentId: docId,
            pageIndex: 0,
            fileName: name,
            mimeType: verdict.mimeType,
            sizeBytes: bytes.length,
            bytes: bytes,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        notify: false,
      );
      await _media.deleteMedia(item.id);
    });
    return true;
  }
}
```

Before writing, confirm `MediaRepository.getMediaById` exists (grep `Future<domain.MediaItem?> getMediaById`); if it is named differently, use that name. `DocumentPage` constructor fields: check `lib/features/documents/domain/entities/document_page.dart` and match them. An image is never offered by the old picker, so `needsImageReencode` is not handled; if `verdict.needsImageReencode` is true, return false (leave the file linked) rather than store an un-encoded image.

- [ ] **Step 6: Run, expect PASS.**
- [ ] **Step 7: Commit** `feat(documents): convert gear attachments into library documents`.

---

### Task 8: Converter wiring and the gear page

**Files:**
- Create: `lib/features/documents/presentation/providers/equipment_file_conversion_provider.dart`
- Modify: `lib/app.dart:155-160` (post-frame launch tasks)
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart:1630` (after `galleryCloudIdBackfillProvider`)
- Modify: `lib/features/equipment/presentation/widgets/equipment_documents_section.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart:276-285`
- Modify: `lib/l10n/arb/app_en.arb` (equipment_documents keys)
- Test: `test/features/documents/presentation/providers/equipment_file_conversion_provider_test.dart`, `test/features/equipment/presentation/widgets/equipment_documents_section_test.dart` (create if missing)

**Interfaces:**
- Consumes: Task 7.
- Produces: `final equipmentFileConversionProvider = Provider<Future<EquipmentFileConversionResult?> Function()>`. Task 11 calls the compaction monitor after it.

- [ ] **Step 1: Failing tests.**

```dart
test('overlapping runs convert once', () async {
  final container = ProviderContainer(overrides: [
    equipmentFileConverterFactoryProvider.overrideWithValue(() async => fake),
  ]);
  addTearDown(container.dispose);
  final run = container.read(equipmentFileConversionProvider);
  await Future.wait([run(), run()]);
  expect(fake.runs, 1);
});
```

`fake` is a subclass of `EquipmentFileConverter` overriding `run()` to count calls and await a 50 ms delay. Gear card tests: with `mediaForEquipmentProvider('e1')` overridden to `[]`, `EquipmentDocumentsSection` renders `SizedBox.shrink` (`find.byType(Card)` finds nothing); with one item it shows `'Linked files'` and no `ValueKey('equipment-documents-attach')`.

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement the provider.**

```dart
/// Builds the converter; a seam for tests.
final equipmentFileConverterFactoryProvider =
    Provider<Future<EquipmentFileConverter> Function()>((ref) {
      return () async => EquipmentFileConverter(
        readBytes: (item) async {
          final resolved = await ref.read(mediaBytesProvider(item).future);
          ref.invalidate(mediaBytesProvider(item));
          return resolved.isUnavailable ? null : resolved.bytes;
        },
        prefs: await SharedPreferences.getInstance(),
      );
    });

/// Runs [EquipmentFileConverter] at launch and after each sync, one run at
/// a time: a call while one runs waits for it instead of starting another.
/// Contains its own failures; returns null when the run failed.
// no-tick: the value is a CLOSURE, not a query result.
final equipmentFileConversionProvider =
    Provider<Future<EquipmentFileConversionResult?> Function()>((ref) {
      Future<EquipmentFileConversionResult?>? inFlight;
      return () {
        return inFlight ??= () async {
          try {
            final converter = await ref.read(equipmentFileConverterFactoryProvider)();
            return await converter.run();
          } on Object catch (e, stackTrace) {
            LoggerService.forClass(EquipmentFileConverter).warning(
              'Gear file conversion failed', error: e, stackTrace: stackTrace);
            return null;
          } finally {
            inFlight = null;
          }
        }();
      };
    });
```

- [ ] **Step 4: Call sites.** `app.dart`, in the post-frame callback beside `_republishOwnedMedia();`: `_convertGearFiles();` with

```dart
/// Moves gear attachments into Documents (spec 3). Same database timing
/// argument as [_resumeMediaTransfers]; contains its own failures.
void _convertGearFiles() {
  unawaited(ref.read(equipmentFileConversionProvider)());
}
```

`sync_providers.dart`, after the `galleryCloudIdBackfillProvider` await and its `mounted` check:

```dart
// Gear files a peer linked, or that only became readable here once this
// sync fetched their store copy, move into Documents.
await _ref.read(equipmentFileConversionProvider)();
if (!mounted) return false;
```

- [ ] **Step 5: Gear card.** In `EquipmentDocumentsSection`: remove `onAttachPressed` and the attach button; in `data:` return `const SizedBox.shrink()` for an empty list; title `equipment_documents_linkedTitle` ("Linked files"); subtitle `equipment_documents_linkedSubtitle` ("Too large, or a format Documents cannot hold"). Update the class doc comment to say the card now only holds files the converter left behind. In `equipment_detail_page.dart` drop the `onAttachPressed:` argument and the `const SizedBox(height: 24)` before the section becomes conditional: wrap both in a `Consumer` that renders nothing when `mediaForEquipmentProvider(equipmentId)` has an empty value. Remove the now-unused `equipment_documents_attachButton`, `equipment_documents_title`, `equipment_documents_subtitle` keys from all 11 ARBs only if no other file references them (grep first). Remove `equipmentId` from `DocumentOpenHelper.pickAndAttach` only if nothing else passes it.
- [ ] **Step 6: Run** the new tests and `test/features/equipment/`, expect PASS.
- [ ] **Step 7: Commit** `feat(equipment): one Documents card; gear attachments move into the library`.

---

### Task 9: Compaction building blocks

**Files:**
- Create: `lib/core/database/compaction/database_compaction_prefs.dart`
- Create: `lib/core/database/compaction/database_space.dart`
- Create: `lib/core/database/compaction/compact_database_file.dart`
- Test: `test/core/database/compaction/database_compaction_test.dart`

**Interfaces:**
- Produces:

```dart
class DatabaseCompactionPrefs {
  DatabaseCompactionPrefs(SharedPreferences prefs, {DateTime Function()? now});
  static const requestedKey = 'compactDatabaseAtNextLaunch';
  static const backoffKey = 'compactDatabaseBackoffUntil';
  static const backoff = Duration(days: 7);
  bool get isRequested;
  bool get inBackoff;
  Future<void> request();
  Future<void> cancel();
  Future<void> recordFailure();
}
class DatabaseSpace {
  const DatabaseSpace({required int pageSize, required int pageCount, required int freePages});
  int get fileBytes; int get reclaimableBytes;
  bool get worthCompacting; // >= 50 MB and >= 25% of the file
}
Future<DatabaseSpace> readDatabaseSpace(AppDatabase db);
Future<void> compactDatabaseFile(String path, {String? keyHex});
```

- [ ] **Step 1: Failing tests.**

```dart
group('worthCompacting', () {
  const mb = 1024 * 1024;
  DatabaseSpace space(int fileMb, int freeMb) => DatabaseSpace(
      pageSize: 4096, pageCount: fileMb * mb ~/ 4096, freePages: freeMb * mb ~/ 4096);
  test('needs 50 MB', () => expect(space(100, 49).worthCompacting, isFalse));
  test('needs a quarter of the file', () => expect(space(400, 60).worthCompacting, isFalse));
  test('both met', () => expect(space(200, 60).worthCompacting, isTrue));
});

test('prefs: request, cancel, backoff', () async {
  SharedPreferences.setMockInitialValues({});
  var now = DateTime(2026, 10, 13);
  final prefs = DatabaseCompactionPrefs(await SharedPreferences.getInstance(), now: () => now);
  await prefs.request();
  expect(prefs.isRequested, isTrue);
  await prefs.cancel();
  expect(prefs.isRequested, isFalse);
  await prefs.recordFailure();
  expect(prefs.inBackoff, isTrue);
  now = now.add(const Duration(days: 8));
  expect(prefs.inBackoff, isFalse);
});

test('compactDatabaseFile shrinks a WAL file with free pages', () async {
  final dir = await Directory.systemTemp.createTemp('compact_');
  addTearDown(() => dir.delete(recursive: true));
  final path = p.join(dir.path, 'db.sqlite');
  final raw = sqlite3.sqlite3.open(path);
  raw.execute('PRAGMA journal_mode = WAL');
  raw.execute('CREATE TABLE t (b BLOB)');
  final blob = Uint8List(1024 * 1024);
  for (var i = 0; i < 20; i++) {
    raw.execute('INSERT INTO t VALUES (?)', [blob]);
  }
  raw.execute('DELETE FROM t');
  raw.close();
  final before = File(path).lengthSync();
  await compactDatabaseFile(path);
  expect(File(path).lengthSync(), lessThan(before ~/ 4));
});
```

`readDatabaseSpace` is covered with the in-memory test database: insert and delete a large `document_pages` blob, then expect `freePages > 0`.

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Prefs as in the interface (`request` sets `requestedKey` true; `cancel` removes it; `recordFailure` writes `now + backoff` in ms; `inBackoff` compares). `DatabaseSpace`:

```dart
/// Space held by the database file and how much of it is free pages,
/// which only a VACUUM returns to the disk.
class DatabaseSpace {
  static const int _minimumBytes = 50 * 1024 * 1024;
  final int pageSize;
  final int pageCount;
  final int freePages;
  const DatabaseSpace({required this.pageSize, required this.pageCount, required this.freePages});
  int get fileBytes => pageSize * pageCount;
  int get reclaimableBytes => pageSize * freePages;

  /// A rewrite costs a slower launch, so only a saving that is large both
  /// on its own and against the file earns one.
  bool get worthCompacting =>
      reclaimableBytes >= _minimumBytes && reclaimableBytes * 4 >= fileBytes;
}

Future<DatabaseSpace> readDatabaseSpace(AppDatabase db) async {
  Future<int> pragma(String name) async =>
      (await db.customSelect('PRAGMA $name').getSingle()).data.values.first as int;
  return DatabaseSpace(
    pageSize: await pragma('page_size'),
    pageCount: await pragma('page_count'),
    freePages: await pragma('freelist_count'),
  );
}
```

`compact_database_file.dart`:

```dart
/// Rewrites the database at [path] without its free pages, then truncates
/// the write-ahead log so the file itself shrinks.
///
/// On its own isolate with its own connection: a VACUUM rewrites the whole
/// file, and on the UI isolate the startup screen would freeze until it
/// finished. Called before any other connection is open.
Future<void> compactDatabaseFile(String path, {String? keyHex}) =>
    Isolate.run(() {
      final db = DatabaseService.openRaw(path, keyHex: keyHex);
      try {
        db.execute('VACUUM');
        db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      } finally {
        db.close();
      }
    });
```

If `Isolate.run` cannot open SQLCipher in the spawned isolate on a device build, the fallback is to run the same body directly (accepting a frozen frame); the unit test above runs on the host and proves the isolate path there.

- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(database): compaction building blocks`.

---

### Task 10: Compaction at launch

**Files:**
- Modify: `lib/core/services/database_service.dart` (`initialize`, `_openDatabase`)
- Modify: `lib/core/presentation/pages/startup_page.dart` (`_initializeServices`, state enum, splash)
- Modify: `lib/l10n/arb/app_en.arb` (after `startup_migrating_progress`)
- Test: `test/core/services/database_service_compaction_test.dart`

**Interfaces:**
- Consumes: Task 9.
- Produces: `initialize({..., DatabaseCompactionPrefs? compaction, VoidCallback? onCompacting})`.

New ARB key: `"startup_compacting": "Optimizing storage..."`.

- [ ] **Step 1: Failing tests** against a real file, following the existing real-file tests in `test/core/services/` (find one with `grep -l "initialize(" test/core/services/*database_service*`; reuse its location-service fake so `_resolveDatabasePath` lands in a temp dir):

```dart
test('a requested compaction shrinks the file and clears the request', () async {
  await createFileWithFreePages(path); // open via DatabaseService, write and delete 20 MB of document pages, close
  final before = File(path).lengthSync();
  final prefs = await compactionPrefs(requested: true);
  var compacting = false;
  await DatabaseService.instance.initialize(
    locationService: fakeLocation(path),
    compaction: prefs,
    onCompacting: () => compacting = true,
  );
  await DatabaseService.instance.close();
  expect(compacting, isTrue);
  expect(prefs.isRequested, isFalse);
  expect(File(path).lengthSync(), lessThan(before));
});

test('without compaction prefs nothing is compacted', () async {
  ...initialize(locationService: fakeLocation(path));
  expect(File(path).lengthSync(), before);
});

test('a failure records the backoff and still opens', () async {
  // seam: DatabaseService.compactFileOverride = (_, {keyHex}) async => throw StateError('busy');
  ...
  expect(prefs.inBackoff, isTrue);
  expect(DatabaseService.instance.isInitialized, isTrue);
});
```

Add `@visibleForTesting Future<void> Function(String path, {String? keyHex})? compactFileOverride;` to `DatabaseService`, reset in `resetForTesting()`. Every test restores it with `addTearDown`.

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement in `DatabaseService`.** Thread `compaction` and `onCompacting` from `initialize` into `_openDatabase`. Hoist `var vacuumTicket = true;` above `if (migrationPending)`. Before the final `return retryWhileDatabaseBusy(() => _openOnBackgroundExecutor(...))`:

```dart
if (compaction != null && compaction.isRequested) {
  // Cleared before the attempt: a rewrite the OS kills must not bring
  // the next launch straight back into it. A ladder VACUUM at this open
  // has already done the work.
  await compaction.cancel();
  if (vacuumTicket) {
    onCompacting?.call();
    try {
      await (compactFileOverride ?? compactDatabaseFile)(dbPath, keyHex: keyHex);
    } catch (e, stackTrace) {
      await compaction.recordFailure();
      _log.warning(
        'Requested compaction skipped; the database is correct but keeps '
        'its free pages',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
```

`vacuumTicket` is false exactly when the ladder took the VACUUM ticket.

- [ ] **Step 4: Startup page.** Add `_StartupState.compacting`. In `_initializeServices`, before the `timeStartupStep('database', ...)`: `final compactionPrefs = DatabaseCompactionPrefs(await SharedPreferences.getInstance());` and pass `compaction: compactionPrefs, onCompacting: () { if (mounted) setState(() => _state = _StartupState.compacting); }`. In the splash, add a branch for `_StartupState.compacting` rendering an indeterminate `LinearProgressIndicator` (same colours as the migrating one) and `Text(context.l10n.startup_compacting)`. Check what `_state` the page moves to after `_initializeServices` returns and confirm `compacting` is replaced the same way `migrating` is (search `_state = _StartupState.` after the `Future.wait`).
- [ ] **Step 5: Run** the new test plus `test/core/services/` and `test/core/presentation/`, expect PASS.
- [ ] **Step 6: Commit** `feat(database): compact the database at launch when asked`.

---

### Task 11: Compaction monitor

**Files:**
- Create: `lib/core/database/compaction/database_compaction_monitor.dart`
- Modify: `lib/features/documents/presentation/providers/document_providers.dart` (`DocumentMutations.delete`)
- Modify: `lib/features/documents/presentation/providers/equipment_file_conversion_provider.dart` (after a run that converted)
- Modify: `lib/app.dart` (after `_convertGearFiles`)
- Test: `test/core/database/compaction/database_compaction_monitor_test.dart`

**Interfaces:**
- Produces: `class DatabaseCompactionMonitor { Future<bool> check(); }` and `final databaseCompactionMonitorProvider = Provider<Future<void> Function()>`.

- [ ] **Step 1: Failing tests.**

```dart
test('requests compaction when it is worth it', () async {
  final monitor = DatabaseCompactionMonitor(
    readSpace: () async => space(200, 60), prefs: prefs);
  expect(await monitor.check(), isTrue);
  expect(prefs.isRequested, isTrue);
});
test('not below the threshold', () async { ... space(400, 60) ... isFalse });
test('not during a backoff', () async {
  await prefs.recordFailure();
  expect(await DatabaseCompactionMonitor(readSpace: () async => space(200, 60), prefs: prefs).check(), isFalse);
});
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**

```dart
/// Decides, while the app runs, whether the next launch should compact the
/// database (spec 6). Measuring here instead of at launch spares every
/// start an extra exclusive connection just to read three pragmas.
class DatabaseCompactionMonitor {
  DatabaseCompactionMonitor({
    required Future<DatabaseSpace> Function() readSpace,
    required DatabaseCompactionPrefs prefs,
  }) : _readSpace = readSpace, _prefs = prefs;

  final Future<DatabaseSpace> Function() _readSpace;
  final DatabaseCompactionPrefs _prefs;

  /// True when it asked for a compaction.
  Future<bool> check() async {
    if (_prefs.isRequested || _prefs.inBackoff) return false;
    if (!(await _readSpace()).worthCompacting) return false;
    await _prefs.request();
    return true;
  }
}

// no-tick: the value is a CLOSURE, not a query result.
final databaseCompactionMonitorProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    try {
      await DatabaseCompactionMonitor(
        readSpace: () => readDatabaseSpace(DatabaseService.instance.database),
        prefs: DatabaseCompactionPrefs(await SharedPreferences.getInstance()),
      ).check();
    } on Object catch (e, stackTrace) {
      LoggerService.forClass(DatabaseCompactionMonitor)
          .warning('Compaction check failed', error: e, stackTrace: stackTrace);
    }
  };
});
```

- [ ] **Step 4: Triggers.** `DocumentMutations.delete`: `await _repo.delete(id); unawaited(_ref.read(databaseCompactionMonitorProvider)());`. Conversion provider: after `converter.run()` returns with `converted > 0`, `await ref.read(databaseCompactionMonitorProvider)();`. `app.dart`: in `_convertGearFiles`, chain `.then((_) => ref.read(databaseCompactionMonitorProvider)())` so the session check runs once after the launch conversion.
- [ ] **Step 5: Run** monitor tests and `test/features/documents/`, expect PASS.
- [ ] **Step 6: Commit** `feat(database): schedule compaction when deletes leave enough free space`.

---

### Task 12: Storage page reclaim row

**Files:**
- Create: `lib/features/settings/presentation/widgets/database_reclaim_row.dart`
- Create: `lib/features/settings/presentation/providers/database_reclaim_providers.dart`
- Modify: `lib/features/settings/presentation/pages/storage_usage_page.dart` (render under the database row)
- Modify: `lib/l10n/arb/app_en.arb` (after `settings_storageUsage_category_database`)
- Test: `test/features/settings/presentation/widgets/database_reclaim_row_test.dart`

**Interfaces:**
- Consumes: Tasks 9 and 10.
- Produces: `databaseSpaceProvider` (`FutureProvider.autoDispose<DatabaseSpace>`), `databaseCompactionPrefsProvider` (`FutureProvider<DatabaseCompactionPrefs>`).

ARB keys:

```json
"settings_storageUsage_reclaimable": "{size} reclaimable",
"@settings_storageUsage_reclaimable": {"placeholders": {"size": {"type": "String"}}},
"settings_storageUsage_compact": "Compact",
"settings_storageUsage_compactTitle": "Compact the database?",
"settings_storageUsage_compactBody": "Runs the next time Submersion starts. A large log may take a minute and needs free space about the size of the database.",
"settings_storageUsage_compactScheduled": "Scheduled for next launch",
"settings_storageUsage_compactCancel": "Cancel",
"settings_storageUsage_quitNow": "Quit now",
```

- [ ] **Step 1: Failing tests.**

```dart
testWidgets('shows reclaimable space and schedules a compaction', (t) async {
  await pumpRow(t, space: space(400, 30));
  expect(find.text('30.0 MB reclaimable'), findsOneWidget);
  await t.tap(find.text('Compact'));
  await t.pumpAndSettle();
  await t.tap(find.widgetWithText(FilledButton, 'Compact'));
  await t.pumpAndSettle();
  expect(prefs.isRequested, isTrue);
  expect(find.text('Scheduled for next launch'), findsOneWidget);
});
testWidgets('cancel withdraws the request', (t) async { ... });
testWidgets('nothing under 1 MB', (t) async {
  await pumpRow(t, space: space(400, 0));
  expect(find.byType(DatabaseReclaimRow), findsOneWidget);
  expect(find.text('Compact'), findsNothing);
});
```

Match the expected size text to whatever `formatBytes` from `lib/core/utils/byte_format.dart` prints for 30 MB (run it once in the test to read the exact output).

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** `DatabaseReclaimRow` (ConsumerStatefulWidget): reads both providers; under 1 MB renders `SizedBox.shrink()`; otherwise a `Padding(EdgeInsets.fromLTRB(16, 0, 16, 12))` `Row` with the muted reclaimable `Text` (Flexible) and either a `TextButton` Compact (confirm `AlertDialog` with Cancel and `FilledButton` Compact, then `prefs.request()` and `setState`) or, when `prefs.isRequested`, the scheduled text, a `TextButton` Cancel (`prefs.cancel()`), and on desktop (`Platform.isMacOS || Platform.isWindows || Platform.isLinux`) a `TextButton` Quit now that closes the database (`DatabaseService.instance.close()`) and calls `exit(0)`, behind a `@visibleForTesting` `quitOverride`. In `StorageUsagePage.build`, after the `StorageUsageRow` whose `category.id == StorageCategoryId.database`, add `const DatabaseReclaimRow()`.
- [ ] **Step 4: Run** the new test and `test/features/settings/presentation/pages/storage_usage_page_test.dart`, expect PASS (add a `databaseSpaceProvider` override to that file's harness if the page now reads it).
- [ ] **Step 5: Commit** `feat(settings): show reclaimable database space and a Compact action`.

---

### Task 13: Translations

**Files:** all 10 locale ARBs and generated `app_localizations_*.dart`.

- [ ] **Step 1:** List this branch's new keys: `git diff origin/main...HEAD -- lib/l10n/arb/app_en.arb | grep '^+  "' | grep -v '"@'`.
- [ ] **Step 2:** For each locale (ar, de, es, fr, he, hu, it, nl, pt, zh), write human-quality translations matching each locale's neighbouring keys in the same feature block (accents as the block uses them). Insert each line by anchor (the key it follows in `app_en.arb`) with a `python3.14` script that builds `'  "%s": %s,' % (key, json.dumps(value, ensure_ascii=False))`, writes, then `json.loads` the file to prove it parses. Never JSON round-trip a file. Delete removed keys (Task 8) from every locale the same way.
- [ ] **Step 3:** `flutter gen-l10n` (last), then `grep -A1 "get documents_owner_field" lib/l10n/arb/app_localizations_de.dart` shows German.
- [ ] **Step 4:** `git diff --numstat lib/l10n/arb/`: every locale's row matches its siblings; explain any that differs.
- [ ] **Step 5: Commit** `i18n(documents): translate document filing and storage strings`.

---

### Task 14: Verification

- [ ] `dart format .`
- [ ] `flutter analyze` (no issues)
- [ ] `flutter test test/architecture/ test/shared/`
- [ ] `flutter test test/features/documents/ test/features/equipment/ test/features/trips/presentation/widgets/story/ test/features/settings/ test/core/database/compaction/ test/core/services/ test/core/presentation/`
- [ ] Commit any formatting change as `style: format`.
