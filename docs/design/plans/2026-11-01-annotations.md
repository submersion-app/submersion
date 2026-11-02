# Annotations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the diver pin a passage of a dive's Notes to a time in the dive, see it as a marker on the profile, create one from the chart or from the Notes editor, move or remove it, and keep it through resync, reparse, sync and a UDDF round trip.

**Architecture:** An annotation is a `dive_profile_events` row (`event_type = annotation`, `source = user`) whose words are a Markdown link `[words](annotation:<id>)` in `dives.notes`. A pure `annotation_links.dart` module reads and rewrites those links; an `AnnotationRepository` writes event row and Notes together in one transaction and reconciles the two on every save. The chart gets an `AnnotationMarkerLayer` overlay (dots, taps, placement), the Notes view gets an annotation branch in its link rendering, and the edit page's Markdown toolbar gets a pin button that records pending annotations until save.

**Tech Stack:** Flutter, Riverpod (codegen and StateNotifier), Drift, fl_chart, `markdown` package, flutter_test, ARB localisation.

**Spec:** `docs/design/specs/2026-11-01-annotations-design.md`

## Global Constraints

- No em-dashes anywhere; no emojis; no mention of any AI tool in code, commits or the PR.
- Immutable state: copy, never mutate, lists and entities.
- Units through `UnitFormatter` (`formatDepth`, `convertDepth`, `depthSymbol`); storage is metres.
- Times are seconds from the start of the dive; display is `formatMinutesSeconds` (`m:ss`); input is `parseMinutesSeconds` from `lib/core/utils/minutes_seconds.dart`.
- No schema change and no migration rung.
- Files stay under 800 lines. `dive_profile_chart.dart` (7,548 lines), `dive_edit_page.dart`, `dive_repository_impl.dart` and `dive_computer_repository_impl.dart` get only the smallest hooks; every new behaviour lives in a new file.
- New ARB keys go in every locale (`app_en, app_ar, app_de, app_es, app_fr, app_he, app_hu, app_it, app_nl, app_pt, app_zh`) anchored on a neighbouring key of the same group, then `flutter gen-l10n` runs LAST (Task 16). Until then new strings compile against the English key only in `app_en.arb`, and the generated Dart is not committed.
- A test that replaces process-wide state restores it in `addTearDown`. Repository tests use `setUpTestDatabase()` / `tearDownTestDatabase()` from `test/helpers/test_database.dart`.
- Run `dart format .`, `flutter analyze`, the touched tests, and `test/architecture/` plus `test/shared/` before every commit that adds a file under `lib/`.
- TDD: each task writes its failing test first. Commit after each task.

## Review Focus

1. A passage linked twice to the same id, or a link pasted into another dive's Notes, must never crash reconciliation, draw a marker it cannot resolve, or rewrite text the diver typed (Task 2 and Task 9 tests).
2. A time typed as `75:00` on a 60-minute dive, or `-1`, is refused, and exactly the runtime is accepted (Task 13 test).
3. A dive with no profile samples still takes an annotation by typed time (Task 9 and Task 13 tests). The chart never draws a plot without samples, so there is no marker to draw; the detail page hides the profile card and the edit page's notes pin is the route.
4. Two annotations three seconds apart both keep their lines, and an annotation at the same second as a computer warning is not dropped by the severity rule (Task 10 test).
5. A peer's dive-wide event tombstone must not delete an annotation that was created on another device before the resync (Task 5 test).

---

### Task 1: `ProfileEventType.annotation` and the entity factory

**Files:**
- Modify: `lib/core/constants/enums.dart:386-460` (enum values and `iconName`)
- Modify: `lib/features/dive_log/domain/entities/profile_event.dart` (after `ProfileEvent.bookmark`, :212)
- Modify: `lib/features/dive_log/presentation/formatters/profile_event_label.dart:16-42`
- Modify: `lib/l10n/arb/app_en.arb` (after `"enum_profileEvent_note"`, :8109): `"enum_profileEvent_annotation": "Annotation"`
- Modify: `lib/features/dive_3d/domain/entities/dive_3d_scene_data.dart:74-77`
- Test: `test/features/dive_log/domain/entities/profile_event_annotation_test.dart`

**Interfaces:**
- Produces: `ProfileEventType.annotation` (`'Annotation'`, default severity `'info'`, icon `'push_pin'`); `factory ProfileEvent.annotation({required String id, required String diveId, required int timestamp, double? depth, required String words, required DateTime createdAt})` with `eventType: annotation`, `source: EventSource.user`, `description: words`; `bool get isAnnotation => eventType == ProfileEventType.annotation`.

- [ ] **Step 1: Write the failing test**

```dart
test('annotation factory is user-authored with the words as description', () {
  final e = ProfileEvent.annotation(id: 'a1', diveId: 'd1', timestamp: 1290, depth: 19.6, words: 'started feeling nauseous', createdAt: DateTime(2026));
  expect(e.eventType, ProfileEventType.annotation);
  expect(e.source, EventSource.user);
  expect(e.description, 'started feeling nauseous');
  expect(e.isAnnotation, isTrue);
  expect(ProfileEventType.annotation.iconName, 'push_pin');
});
test('the string mapper reads annotation back by name', () {
  // mapDiveProfileEventToProfileEvent on a DiveProfileEvent row with eventType 'annotation'
  // expect .eventType == ProfileEventType.annotation (today it falls back to bookmark)
});
test('the 3D scene counts annotations among bookmark events', ...); // Dive3dSceneData with one annotation event: bookmarkEvents has length 1
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/domain/entities/profile_event_annotation_test.dart`
Expected: compile error, `annotation` is not a member of `ProfileEventType`.

- [ ] **Step 3: Implement.** Add the enum value last (`annotation('Annotation', 'info')`), the `iconName` case, the factory and getter, the `localizedName` arm using `l10n.enum_profileEvent_annotation`, the ARB line in `app_en.arb` only, and widen the 3D filter to `e.eventType == ProfileEventType.bookmark || e.isAnnotation`. Run `flutter gen-l10n` locally so the getter exists but do NOT commit the generated `app_localizations*.dart` (Task 16 does).

- [ ] **Step 4: Run the test and `flutter analyze`**

Expected: PASS, no issues.

- [ ] **Step 5: Commit** `feat(dive-log): add the annotation profile event type` (ARB en line and the four Dart files; exclude generated l10n).

---

### Task 2: `annotation_links.dart`, the pure Notes link module

**Files:**
- Create: `lib/features/dive_log/domain/services/annotation_links.dart`
- Test: `test/features/dive_log/domain/services/annotation_links_test.dart`

**Interfaces:**
- Produces:
  - `const String annotationLinkScheme = 'annotation';`
  - `String? annotationIdFromHref(String? href)`: `'annotation:4f1c'` gives `'4f1c'`; null, empty id, or any other scheme gives null; scheme match is case-insensitive.
  - `String annotationLinkMarkdown(String words, String id)` gives `'[words](annotation:id)'`; `]` in words is escaped as `\]`.
  - `Map<String, String> annotationWordsInNotes(String notes)`: id to the plain inner text of the FIRST link with that id, parsed with `parseNotesMarkdown` (inline `a` elements only; images and reference links count too when their href has the scheme).
  - `Set<String> annotationIdsInNotes(String notes)` is `annotationWordsInNotes(notes).keys.toSet()`.
  - `String unlinkAnnotation(String notes, String id)`: every `[words](annotation:id)` becomes `words`; other text untouched; returns the input unchanged when the id is absent.
  - `String appendAnnotationParagraph(String notes, String words, String id)`: `appendMarkdownParagraph(notes, annotationLinkMarkdown(words, id))` from `lib/core/text/markdown/notes_markdown.dart:117`.
  - `Map<String, String> annotationTimesOf(List<ProfileEvent> annotations)`: id to `formatMinutesSeconds(timestamp)`.
  - `List<ProfileEvent> dropOrphanAnnotations(List<ProfileEvent> events, String notes)`: removes annotation events whose id is not in `annotationIdsInNotes(notes)`; non-annotation events pass through unchanged, order kept.

- [ ] **Step 1: Write the failing tests**

```dart
test('reads the id from an annotation href', () {
  expect(annotationIdFromHref('annotation:4f1c'), '4f1c');
  expect(annotationIdFromHref('Annotation:4f1c'), '4f1c');
  expect(annotationIdFromHref('https://x.test'), isNull);
  expect(annotationIdFromHref('annotation:'), isNull);
  expect(annotationIdFromHref(null), isNull);
});
test('collects ids and words, first occurrence wins', () {
  const notes = 'I [felt sick](annotation:a) then [calm](annotation:b) and [again sick](annotation:a).';
  expect(annotationWordsInNotes(notes), {'a': 'felt sick', 'b': 'calm'});
});
test('words of a link with inline emphasis are the plain text', () {
  expect(annotationWordsInNotes('[**free** flow](annotation:a)'), {'a': 'free flow'});
});
test('unlink keeps the words and leaves other links alone', () {
  expect(unlinkAnnotation('x [a b](annotation:1) y [c](annotation:2) [w](https://s.test)', '1'),
      'x a b y [c](annotation:2) [w](https://s.test)');
  expect(unlinkAnnotation('plain', 'zzz'), 'plain');
});
test('append puts the link in its own paragraph', () {
  expect(appendAnnotationParagraph('First.', 'Octo free-flowed', 'id9'), 'First.\n\n[Octo free-flowed](annotation:id9)');
  expect(appendAnnotationParagraph('', 'Octo', 'id9'), '[Octo](annotation:id9)');
});
test('link markdown escapes a closing bracket in the words', () {
  expect(annotationLinkMarkdown('a]b', 'i'), r'[a\]b](annotation:i)');
});
test('dropOrphanAnnotations keeps computer events and linked annotations only', ...);
test('annotationTimesOf formats m:ss per id', () { expect(annotationTimesOf([_ann('a', 1290)]), {'a': '21:30'}); });
```

- [ ] **Step 2: Run to verify failure** (file not found).
- [ ] **Step 3: Implement** the module. `unlinkAnnotation` uses a `RegExp(r'\[((?:\\.|[^\]])*)\]\(annotation:' + RegExp.escape(id) + r'\)')` replacing with group 1 (unescaping `\]`).
- [ ] **Step 4: Run the test**: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): parse and rewrite annotation links in notes`.

---

### Task 3: `AnnotationRepository`: add, move, remove, reconcile

**Files:**
- Create: `lib/features/dive_log/data/repositories/annotation_repository.dart`
- Create: `lib/features/dive_log/presentation/providers/annotation_providers.dart` (provider for the repository, modelled on how `diveComputerRepositoryProvider` is declared in `dive_computer_providers.dart`)
- Test: `test/features/dive_log/data/repositories/annotation_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `SyncRepository.markRecordPending({entityType, recordId, localUpdatedAt})` (`lib/core/data/repositories/sync_repository.dart:647`), `SyncRepository.logDeletion({entityType: 'diveProfileEvents', recordId})` (:1674), `SyncEventBus.notifyLocalChange()`, Task 2 functions.
- Produces:
  ```dart
  class PendingAnnotation { final String id; final int timestamp; final double? depth; }
  class AnnotationRepository {
    AnnotationRepository({AppDatabase? db, SyncRepository? syncRepository});
    Future<String> addAnnotation({required String diveId, required int timestamp, double? depth, required String words}); // returns the new id
    Future<void> moveAnnotation({required String id, required int timestamp, double? depth});
    Future<void> removeAnnotation({required String diveId, required String id});
    Future<void> reconcile({required String diveId, required String notes, List<PendingAnnotation> create = const []});
    Future<List<ProfileEvent>> annotationsForDive(String diveId); // annotation rows mapped with mapDiveProfileEventToProfileEvent, timestamp order
  }
  ```
  Rules, all inside one `_db.transaction` per method:
  - `addAnnotation`: `notes = appendAnnotationParagraph(current, words, id)`; write `dives.notes` and `updated_at = now`; insert the event row (`event_type 'annotation'`, `source 'user'`, `description words`, `created_at now`); `markRecordPending` for `dives` and `diveProfileEvents`; `notifyLocalChange` after the transaction.
  - `moveAnnotation`: update `timestamp` and `depth` of the one row; `markRecordPending('diveProfileEvents')` only; no dive write; notify.
  - `removeAnnotation`: `notes = unlinkAnnotation(current, id)`; write notes + `updated_at` + pending dive ONLY when the text changed; delete the row; `logDeletion(entityType: 'diveProfileEvents', recordId: id)`; notify.
  - `reconcile`: `words = annotationWordsInNotes(notes)`; for each `create` whose id is in `words`, insert the row with `description = words[id]` and mark pending (ids not in `words` are ignored); for each existing annotation row of the dive (`event_type = 'annotation'`) whose id is absent from `words`, delete it and `logDeletion`; for each present whose `description != words[id]`, update the description and mark pending. Never writes `dives.notes`. Notify once if anything changed.

- [ ] **Step 1: Write the failing tests** with `setUpTestDatabase()` and a dive created via `DiveRepository().createDive(...)` (pattern: `test/features/dive_log/data/repositories/event_scope_tombstone_emitters_test.dart:17`):

```dart
test('addAnnotation appends the link paragraph and inserts a user row', () async {
  final id = await repo.addAnnotation(diveId: diveId, timestamp: 1290, depth: 19.6, words: 'felt sick');
  final dive = await db.select(db.dives).getSingle();
  expect(dive.notes, endsWith('[felt sick](annotation:$id)'));
  final row = await db.select(db.diveProfileEvents).getSingle();
  expect((row.eventType, row.source, row.description, row.timestamp, row.depth), ('annotation', 'user', 'felt sick', 1290, 19.6));
  // sync_pending (or the repo's pending table) has entries for both records
});
test('moveAnnotation changes the row and does not touch the dive', ...); // dive.updatedAt unchanged, event pending
test('removeAnnotation unlinks the words and tombstones the row', ...); // notes == 'x felt sick', deletion_log has entityType diveProfileEvents recordId id
test('reconcile creates pending annotations that are linked and ignores the rest', ...);
test('reconcile deletes an annotation whose link is gone and leaves computer events', ...); // seed one 'gasSwitch' imported row too; it survives
test('reconcile refreshes the cached words', ...);
test('annotationsForDive returns only annotation rows in time order', ...);
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement** the repository and `annotationRepositoryProvider`.
- [ ] **Step 4: Run the tests, `flutter analyze`, `test/architecture/`.**
- [ ] **Step 5: Commit** `feat(dive-log): annotation repository with notes reconciliation`.

---

### Task 4: Resync, reparse and re-download keep user events

**Files:**
- Modify: `lib/features/dive_import/data/services/dive_reimport_service.dart:720-770` (`_replaceProfileEvents`)
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart:290-296`, `:432-470` (`_idsOf`, `_deleteAndTombstone`)
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:1399-1416` (`clearSourceAndProfiles`)
- Create: `lib/features/dive_log/data/services/user_event_preservation.dart`
- Test: `test/features/dive_log/data/services/user_event_preservation_test.dart`, plus one test each added to `test/features/dive_import/data/services/dive_reimport_service_test.dart` (group at :1472, `seedEvent` helper), `test/features/dive_computer/data/services/reparse_service_sync_test.dart`, and `test/features/dive_log/data/repositories/event_scope_tombstone_emitters_test.dart`.

**Interfaces:**
- Produces, in `user_event_preservation.dart`:
  - `Expression<bool> nonUserEvent($DiveProfileEventsTable t) => t.source.equals(EventSource.user.name).not();`
  - `Future<List<String>> nonUserEventIds(AppDatabase db, String diveId, {String? computerId})`
  - `Future<void> restampUserEvents({required AppDatabase db, required SyncRepository sync, required String diveId, required int now})`: `markRecordPending('diveProfileEvents', id, now)` for every `source = 'user'` row of the dive. Called by each of the three paths right AFTER its `logScopedDeletion`, so surviving rows carry a clock newer than the tombstone.
- The three delete sites add `nonUserEvent` to their where (reparse passes `nonUserEventIds` to `_deleteAndTombstone` instead of `_idsOf`); each then calls `restampUserEvents`.
- Resync additionally skips an incoming parsed event whose id already exists on the dive (prepares Task 6's UDDF ids).

- [ ] **Step 1: Write the failing tests.** Each seeds one `'annotation'/'user'` row and one `'gasSwitch'/'imported'` row on the dive, runs the path, and asserts:

```dart
// the user row is still there, the imported one is gone and replaced
// the scope tombstone was logged (as today)
// the surviving user row's hlc parses and compares > the tombstone's hlc (Hlc.parse both; deletion_log row for 'diveProfileEventsScope')
```

- [ ] **Step 2: Run to verify failure** (user row deleted).
- [ ] **Step 3: Implement** the helper file and the three edits.
- [ ] **Step 4: Run the four test files** and the whole `test/features/dive_import/data/services/dive_reimport_service_test.dart`, `test/features/dive_computer/data/services/`.
- [ ] **Step 5: Commit** `fix(dive-log): keep user-authored profile events through resync and reparse`.

---

### Task 5: Sync peers keep user events too

**Files:**
- Modify: `lib/core/services/sync/event_scope_tombstone_applier.dart:51-58`
- Modify: `lib/core/services/sync/event_scope_tombstone.dart` (`EventScopeCoverage.covers`, about :98)
- Test: `test/core/services/sync/event_scope_tombstone_apply_test.dart` (add two tests), `test/core/services/sync/event_scope_tombstone_test.dart` or wherever `EventScopeCoverage` is tested (add one).

**Interfaces:**
- The applier's select adds `& t.source.equals('user').not()`; `covers` returns false when `event['source'] == 'user'`.

- [ ] **Step 1: Write the failing tests**

```dart
test('a dive-wide scope leaves a user annotation older than the tombstone alone', ...); // row hlc < delete hlc, source user: still present, return count excludes it
test('coverage never covers an incoming user event', () {
  expect(coverage.covers({'id': 'a', 'dive_id': 'd', 'source': 'user', 'hlc': older}), isFalse);
});
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement** both exemptions.
- [ ] **Step 4: Run `test/core/services/sync/`.**
- [ ] **Step 5: Commit** `fix(sync): dive-scoped event tombstones never remove user events`.

---

### Task 6: UDDF round trip keeps annotations and ids

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart:676-715`
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart:1707-1754`
- Modify: `lib/features/dive_import/data/services/parsed_profile_event_mapper.dart:19-160`
- Test: `test/core/services/export/uddf/uddf_profile_event_round_trip_test.dart` (new), one test in the existing `parsed_profile_event_mapper` test file (find it with `grep -rl profileEventsFromParsed test/`).

**Interfaces:**
- Export writes two more children on every `<event>`, after `<eventtype>`: `<id>` (the row id) and `<source>` (`imported`, `computed` or `user`), following the file's own child-element convention (`eventtype`, `severity`, `tankref` are already non-standard children).
- Import reads them into the event map as `id` and `source`.
- `profileEventsFromParsed` gains a case `'annotation'` producing `ProfileEvent.annotation(id: map['id'] when non-empty else a fresh uuid, words: description ?? '', depth: depth, ...)`; for every other type an `id` in the map is now kept too when present (one line in the shared construction), source unchanged.
- Resync (Task 4) already skips ids that exist.

- [ ] **Step 1: Write the failing tests**

```dart
test('an annotation event survives export and import with its id and source', () async {
  // build a dive with one ProfileEvent.annotation(id: 'ann-1', words: 'felt sick')
  // export with UddfFullExportService (or the builder directly), parse the XML, find profileevents/event
  // expect children id == 'ann-1', source == 'user', eventtype == 'annotation'
  // run UddfFullImportService parse on that XML; profileEventsFromParsed(diveData['profileEvents'])
  // expect one event: id 'ann-1', eventType annotation, source user, description 'felt sick'
});
test('a file without id or source still imports as before', ...); // existing fixture, ids are fresh uuids, source imported
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run `test/core/services/export/uddf/` and `test/features/dive_import/`.**
- [ ] **Step 5: Commit** `feat(uddf): round-trip profile event ids, sources and annotations`.

---

### Task 7: Notes view renders annotation links

**Files:**
- Modify: `lib/shared/widgets/markdown_notes/markdown_notes_view.dart:16-30` (constructor), `:58-76` (cache key), `:98-109` (`_NotesBuilder`), `:341`, `:356` (`_link`)
- Modify: `lib/core/text/markdown/notes_plain_text.dart:125` (`_linkText`)
- Test: `test/shared/widgets/markdown_notes/markdown_notes_view_test.dart` (add a group), `test/core/text/markdown/notes_plain_text_test.dart` (add one test)

**Interfaces:**
- `MarkdownNotesView` gains `Map<String, String>? annotationTimes` (id to `m:ss`), `ValueChanged<String>? onAnnotationTap`, `String? highlightedAnnotationId`. All three join the `_build` cache key (`mapEquals` for the map).
- In `_link`: when `annotationIdFromHref(href)` is non-null:
  - id present in `annotationTimes`: emit `WidgetSpan(Icon(Icons.push_pin, size: 12, color: primary))`, the children spans in the existing link style with a `TapGestureRecognizer` calling `onAnnotationTap(id)`, then `TextSpan(' ${time}', style: bodySmall, onSurfaceVariant)`. When `id == highlightedAnnotationId`, the children spans get `backgroundColor: colorScheme.primaryContainer`.
  - id absent (dangling) or `annotationTimes == null`: plain `_inline(children, style)`.
- `_linkText(text, href)`: when `annotationIdFromHref(href) != null` return `text`.

- [ ] **Step 1: Write the failing tests** (pattern: `pump(tester, source)` at :36, `_span(tester, text)` at :20)

```dart
testWidgets('a resolved annotation link shows a pin, is tappable and shows its time', (tester) async {
  final taps = <String>[];
  await tester.pumpWidget(testApp(child: MarkdownNotesView('I [felt sick](annotation:a1).', annotationTimes: {'a1': '21:30'}, onAnnotationTap: taps.add)));
  await tester.pumpAndSettle();
  expect(find.byIcon(Icons.push_pin), findsOneWidget);
  expect(_span(tester, '21:30'), isNotNull); // leading space allowed: use find.textRange.ofSubstring('21:30')
  await tester.tapOnText(find.textRange.ofSubstring('felt sick'));
  expect(taps, ['a1']);
});
testWidgets('a dangling annotation link is plain words', ...); // annotationTimes: {} -> no pin, recognizer null
testWidgets('without the annotation hooks an annotation link is plain words', ...); // today's behaviour for other Notes consumers
testWidgets('the highlighted annotation gets a background', ...);
test('plain text drops the annotation address', () {
  expect(markdownToPlainText('I [felt sick](annotation:a1) today'), 'I felt sick today');
});
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run both test files.**
- [ ] **Step 5: Commit** `feat(notes): render annotation links with a pin and their time`.

---

### Task 8: Markdown toolbar pin and the annotate edit

**Files:**
- Modify: `lib/shared/widgets/markdown_notes/markdown_editing.dart` (new function after `toggleInlineMark`)
- Modify: `lib/shared/widgets/markdown_notes/markdown_notes_toolbar.dart:13-90`
- Modify: `lib/shared/widgets/markdown_notes/markdown_notes_field.dart:18-60`, `:155-166`
- Modify: `lib/l10n/arb/app_en.arb` (after `"notesEditor_action_numberedList"`): `"notesEditor_action_annotate": "Annotate"`
- Test: `test/shared/widgets/markdown_notes/markdown_editing_test.dart`, `test/shared/widgets/markdown_notes/markdown_notes_field_test.dart` (update "shows the five formatting buttons" at :58 to say the pin appears only when wired, and add the flow test)

**Interfaces:**
- `TextEditingValue wrapSelectionAsAnnotation(TextEditingValue value, {required String id, String? words})`: with a non-collapsed selection, replaces the selection (word-hugged like `toggleInlineMark`) with `annotationLinkMarkdown(selectedText, id)`; with a collapsed selection, inserts `annotationLinkMarkdown(words ?? '', id)` at the caret, on its own line when the caret is not at a line start. The caret lands after the inserted link.
- `MarkdownNotesToolbar` gains `VoidCallback? onAnnotate`; the button (`Icons.push_pin_outlined`, tooltip `l10n.notesEditor_action_annotate`) renders only when non-null, after the numbered list button.
- `MarkdownNotesField` gains `Future<AnnotationRequestResult?> Function(String selectedWords)? onAnnotate` where `typedef AnnotationRequestResult = ({String id, String? words})` (declared in `markdown_editing.dart`). The field passes the current selected text (empty when collapsed), awaits the result, and on non-null applies `wrapSelectionAsAnnotation` through `_apply`.

- [ ] **Step 1: Write the failing tests**

```dart
test('wraps a selection as an annotation link and hugs the words', () {
  final v = TextEditingValue(text: 'I felt sick today', selection: TextSelection(baseOffset: 2, extentOffset: 12)); // 'felt sick '
  final out = wrapSelectionAsAnnotation(v, id: 'a1');
  expect(out.text, 'I [felt sick](annotation:a1) today');
  expect(out.selection.isCollapsed, isTrue);
});
test('inserts a new linked line at a collapsed caret', () {
  final v = TextEditingValue(text: 'First.', selection: TextSelection.collapsed(offset: 6));
  expect(wrapSelectionAsAnnotation(v, id: 'a1', words: 'Octo').text, 'First.\n[Octo](annotation:a1)');
});
testWidgets('the pin button asks the page and applies the link', (tester) async {
  // MarkdownNotesField(controller, onAnnotate: (sel) async { seen = sel; return (id: 'a1', words: null); })
  // select 'sick' via controller.selection, tap find.byIcon(Icons.push_pin_outlined)
  // expect seen == 'sick', controller.text contains '[sick](annotation:a1)'
});
testWidgets('no pin button without onAnnotate', ...);
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the three markdown_notes test files.**
- [ ] **Step 5: Commit** `feat(notes): annotate button on the markdown toolbar`.

---

### Task 9: Edit page: pending annotations and the time sheet

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/annotation_sheet.dart` (`AnnotationForm` and `typedef AnnotationSheetResult`; Task 13 adds `showAnnotationSheet` here)
- Create: `lib/features/dive_log/presentation/widgets/edit_sections/annotation_time_sheet.dart` (composes `AnnotationForm` with the mini profile)
- Create: `lib/features/dive_log/presentation/widgets/mini_profile_picker.dart`
- Create: `lib/features/dive_log/presentation/pages/dive_edit_page_annotations.dart` (a `part of` file with `extension _AnnotationEditing on _DiveEditPageState`, modelled on `dive_edit_page_gas_switches.dart`)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`part` directive; a `List<PendingAnnotation> _pendingAnnotations = const []` field; `onAnnotate: _isBulk ? null : _requestAnnotation` on both `MarkdownNotesField`s at :1616 and :5013; one call after the save's `createDive`/`updateDive` returns: `await ref.read(annotationRepositoryProvider).reconcile(diveId: saved.id, notes: savedNotes, create: _pendingAnnotations)`)
- Modify: `lib/l10n/arb/app_en.arb` (new `diveLog_annotation_*` keys, anchored after `diveLog_edit_section_notes`): `sheetTitle_new` "New annotation", `sheetTitle_words` "Annotate \"{words}\"", `field_words` "What happened", `field_time` "Time from the start", `time_invalid` "Enter minutes:seconds", `time_outsideDive` "Must be within the dive", `pickOnProfile` "Or tap the profile to place it", `noProfile` "This dive has no profile to point at. Type the time instead.", `action_annotate` "Annotate", `action_add` "Add"
- Test: `test/features/dive_log/presentation/widgets/mini_profile_picker_test.dart`, `test/features/dive_log/presentation/widgets/edit_sections/annotation_time_sheet_test.dart`, `test/features/dive_log/presentation/pages/dive_edit_annotations_test.dart` (pattern: `test/features/dive_log/presentation/pages/dive_edit_gas_switches_test.dart`)

**Interfaces:**
- `MiniProfilePicker({required List<DiveProfilePoint> profile, required int? selectedSeconds, required ValueChanged<int> onPick, double height = 90})`: a `CustomPaint` of the depth curve (time on x over the profile's span, depth down) with a `GestureDetector.onTapUp` and `onPanUpdate` mapping local x to seconds (rounded) and drawing the selection as a vertical line and dot at `profileDepthAt(profile, seconds)`.
- `AnnotationForm({required int? seconds, required int maxSeconds, required ValueChanged<int?> onSecondsChanged, String? words, ValueChanged<String>? onWordsChanged, double? depthMeters, required UnitFormatter units})`: the time field (`MinutesSecondsField`, validator refusing `seconds > maxSeconds` with `time_outsideDive`, accepting `== maxSeconds`), the depth line when `depthMeters` is non-null, and a required words `TextFormField` only when `onWordsChanged` is non-null.
- `Future<AnnotationSheetResult?> showAnnotationTimeSheet(BuildContext context, {required String? words, required List<DiveProfilePoint> profile, required int maxSeconds, int? initialSeconds, double? initialDepthMeters, required UnitFormatter units})` where `typedef AnnotationSheetResult = ({int seconds, double? depthMeters, String words})`. A `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)` on every width (the app's dive_log convention, e.g. `what_if_sheet.dart:24`). Contents: title (`sheetTitle_words(words)` or `sheetTitle_new`); a words `TextFormField` only when `words` is null or empty; a `MinutesSecondsField` (`lib/shared/widgets/forms/minutes_seconds_field.dart:14`) with `validator` refusing `seconds > maxSeconds` (`time_outsideDive`) and accepting `== maxSeconds`; the `MiniProfilePicker` when `profile.isNotEmpty` (tapping it sets the time field) else the `noProfile` text; a depth line `units.formatDepth(profileDepthAt(profile, seconds))` when the profile has one; Cancel and the primary action (`action_annotate` when words were given, `action_add` otherwise). Returns null on cancel.
- `_requestAnnotation(String selectedWords) async -> AnnotationRequestResult?` in the extension: `maxSeconds` = the page's runtime in seconds (the same source `_gasSwitchMaxTimestamp` uses, :130 of the gas switch part); profile = `_existingDive?.profile ?? const []`; on a result, appends `PendingAnnotation(id: const Uuid().v4(), timestamp: seconds, depth: depthMeters)` to `_pendingAnnotations` (copy), marks dirty, returns `(id, words)`.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('tapping the mini profile reports the seconds under the finger', ...); // 400px wide, 1200 s profile, tap at x=100 -> onPick(300) within 5 s
testWidgets('the sheet refuses a time past the runtime and accepts the runtime', ...); // maxSeconds 3600: '75:00' shows time_outsideDive; '60:00' returns seconds 3600
testWidgets('the sheet asks for words only when none were selected', ...);
testWidgets('annotating a selection on the edit page records a pending annotation and the save reconciles it', (tester) async {
  // open the edit page for an existing dive with a 1200 s profile (gas switch test harness)
  // type notes 'I felt sick', select 'sick', tap push_pin_outlined, enter 21:30? (dive runtime 20 min: use 10:30), tap Annotate
  // expect notes field text contains '](annotation:'
  // save; expect one dive_profile_events row with eventType 'annotation', timestamp 630, description 'sick'
});
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the three tests, `flutter analyze`, `test/architecture/`, `test/shared/`.**
- [ ] **Step 5: Commit** `feat(dive-log): annotate a notes passage from the dive edit page`.

---

### Task 10: Chart: annotation markers, dots and taps

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/annotation_marker_layer.dart`
- Create: `lib/features/dive_log/presentation/widgets/annotation_marker_label.dart`
- Modify: `lib/features/dive_log/presentation/widgets/profile_metric_colors.dart` (add `static const Color annotation = Color(0xFFF9A825); // Amber 800`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`: constructor (+ `bool showAnnotations = true`, `void Function(ProfileEvent annotation, Offset globalCenter)? onAnnotationTap`), `_buildEventVerticalLines` (:7092-7218), `_eventVerticalLine` (:7220), the Stack next to the range overlay (:4970)
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_annotations_test.dart` (pattern: `dive_profile_chart_event_labels_test.dart`, with `_eventLines` widened to include solid lines whose color is `ProfileMetricColors.annotation`), `test/features/dive_log/presentation/widgets/annotation_marker_label_test.dart`

**Interfaces:**
- `String annotationMarkerLabel(ProfileEvent e, {int maxChars = 24})`: `description` trimmed, cut at the last word boundary before `maxChars` with a single `…` appended; empty description gives `''`.
- In `_buildEventVerticalLines`: annotations are split out of `events` BEFORE the severity and pixel dedupe, kept whole, and only joined back for `placeEventLabels`; each gets `_eventVerticalLine` with: colour `ProfileMetricColors.annotation`, `strokeWidth: 1.5`, `dashArray: null`, label text `annotationMarkerLabel(e)`. Drawn when `_showAnnotations`, independent of `_showEvents`; computer events still obey `_showEvents`.
- `AnnotationMarkerLayer({required List<ProfileEvent> annotations, required ({double left, double top, double right, double bottom}) insets, required double visibleMinSeconds, required double visibleMaxSeconds, required double visibleMinDepth, required double visibleMaxDepth, required double? Function(int seconds) depthAt, required void Function(ProfileEvent, Offset globalCenter) onTap, bool interactive = true, String? focusedId})`: a `Positioned.fill` layer that paints a 5 px radius dot at `(x(timestamp), y(depthAt(timestamp)))` for every annotation with a depth (none when `depthAt` returns null), a 9 px halo on `focusedId`, and on `onTapUp` within 20 px of a dot calls `onTap(annotation, globalCenter)`. `IgnorePointer(ignoring: !interactive)` around it. Pure helper `int? nearestAnnotationIndex(List<Offset> centers, Offset local, {double radius = 20})` exported for tests.
- The chart inserts the layer right after the range overlay, mapping its own `plotInsets`, visible window and `_depthAtTimestamp` (:7076) into it, with `interactive: !_annotationPlacement` (Task 11 adds that flag; use `true` here).

- [ ] **Step 1: Write the failing tests**

```dart
test('the marker label cuts at a word and adds an ellipsis', () {
  expect(annotationMarkerLabel(_ann('started feeling nauseous, probably the breakfast')), 'started feeling nauseous…');
  expect(annotationMarkerLabel(_ann('Octo free-flow')), 'Octo free-flow');
});
testWidgets('two annotations three seconds apart both draw, solid and amber', ...); // 2 solid lines at x 1000 and 1003, color annotation
testWidgets('an annotation at a warning\'s second survives the severity rule', ...); // one warning + one annotation at 900: 2 lines
testWidgets('annotations draw while events are hidden', ...); // showEvents false, showAnnotations true: annotation line present, warning absent
testWidgets('tapping the dot reports the annotation', ...); // find.byType(AnnotationMarkerLayer), tap at the dot's computed centre, expect callback once
test('nearestAnnotationIndex picks the closest dot inside the radius', ...);
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the new tests and the two existing event tests** (`dive_profile_chart_event_labels_test.dart`, `dive_profile_chart_computed_events_test.dart`) to check nothing regressed.
- [ ] **Step 5: Commit** `feat(dive-log): draw annotations on the dive profile`.

---

### Task 11: Chart: placement mode and right-click

**Files:**
- Create: `lib/features/dive_log/presentation/providers/annotation_placement_provider.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`: constructor (+ `bool annotationPlacement = false`, `void Function(int seconds, double? depthMeters)? onAnnotationPlaced`, `void Function(int seconds, double? depthMeters, Offset globalPosition)? onSecondaryTapAt`), `onPointerDown` (:3157), `onPointerUp` (:3234-3260), a new private `int _secondsAtLocalX(double x, Size box, insets)` extracted from `_hoverSelection` (:2779)
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_placement_test.dart`

**Interfaces:**
- `class AnnotationPlacement { final String? movingId; }` and `annotationPlacementProvider = StateNotifierProvider.autoDispose.family<AnnotationPlacementNotifier, AnnotationPlacement?, String>` with `startNew()`, `startMove(String id)`, `cancel()`. Null means off.
- Chart, in placement mode: a single-pointer release (touch or primary mouse) that saw no second pointer places at the release position: `seconds = _secondsAtLocalX(...).clamp(0, maxSeconds)`, `depth = _depthAtTimestamp(seconds)` (null when the profile is empty), then `onAnnotationPlaced(seconds, depth)`. `_tapMoved` does not matter in placement mode (hold-and-release places where the finger lifted), double-tap zoom and the range drag are suspended while placing.
- Right-click: `onPointerDown` with `event.kind == PointerDeviceKind.mouse && (event.buttons & kSecondaryMouseButton) != 0` sets `_secondaryDown = true`; the matching `onPointerUp` without movement calls `onSecondaryTapAt(seconds, depth, event.position)` and never counts as a tap or double-tap seed.
- `_secondsAtLocalX` returns the time at a plot x through the current viewport, the same arithmetic `_hoverSelection` uses before it snaps to a sample.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('in placement mode a tap reports the seconds and depth under the finger', ...); // chart 400x300, 1200 s profile; tap at plot centre: seconds within 30 of 600, depth == profile depth there
testWidgets('a hold then release places where the finger lifted', ...); // gesture down, move 40 px, up: reported seconds match the up position
testWidgets('outside placement mode a tap reports nothing', ...);
testWidgets('a right-click reports seconds, depth and the global position', ...); // tester.startGesture(kind: mouse, buttons: kSecondaryMouseButton)
testWidgets('a tap on the dot in placement mode places instead of opening', ...); // onAnnotationTap not called
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement** the provider and the chart edits (the Listener branches only; no new widgets in the chart file).
- [ ] **Step 4: Run the new test and `dive_profile_chart_annotations_test.dart`.**
- [ ] **Step 5: Commit** `feat(dive-log): place an annotation by tapping the profile`.

---

### Task 12: Legend toggle for annotations

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/profile_legend_provider.dart` (`showAnnotations` beside `showEvents` :38, defaults :131, `copyWith` :229/:275, equality :326, `toggleAnnotations()` beside `toggleEvents()` :580)
- Modify: `lib/features/dive_log/presentation/widgets/profile_legend_config.dart` (+ `hasAnnotations`)
- Modify: `lib/features/dive_log/presentation/widgets/chart_options_dialog.dart:161-177` (row after Events: label `l10n.diveLog_legend_label_annotations`, colour `ProfileMetricColors.annotation`, `legendState.showAnnotations`, `toggleAnnotations`)
- Modify: `lib/features/dive_log/presentation/widgets/active_legend_entries.dart:121-132` (entry)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart:262` (`|| config.hasAnnotations`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart:2874` (read `_showAnnotations = legendState.showAnnotations`) and `:2959-2963` (set `hasAnnotations`)
- Modify: `lib/l10n/arb/app_en.arb` (after `"diveLog_legend_label_events"`): `"diveLog_legend_label_annotations": "Annotations"`
- Test: `test/features/dive_log/presentation/providers/profile_legend_annotations_test.dart`, one test added to `dive_profile_chart_annotations_test.dart` (toggle through the container like `dive_profile_chart_computed_events_test.dart:106`)

- [ ] **Step 1: Write the failing tests**

```dart
test('showAnnotations defaults on and toggles independently of events', () {
  // read profileLegendProvider in a ProviderContainer with settings override
  // expect showAnnotations true; toggleEvents(): showAnnotations still true; toggleAnnotations(): false
});
testWidgets('the annotations toggle hides the markers and the dots', ...);
```

- [ ] **Step 2: Run to verify failure.** Run `dart run build_runner build --delete-conflicting-outputs` after editing the riverpod-annotated provider.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests and `test/features/dive_log/presentation/widgets/` legend tests** (`grep -rl profileLegendProvider test/features/dive_log/presentation/widgets | head`).
- [ ] **Step 5: Commit** `feat(dive-log): legend toggle for annotations`.

---

### Task 13: Detail page: pin button, banner, sheet, popup, Move, Remove, right-click

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/annotation_marker_popup.dart`
- Create: `lib/features/dive_log/presentation/widgets/annotation_placement_banner.dart`
- Modify: `lib/features/dive_log/presentation/widgets/annotation_sheet.dart` (add `showAnnotationSheet`)
- Create: `lib/features/dive_log/presentation/providers/annotation_focus_provider.dart`
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_annotation_actions.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_profile_section.dart:98-136` (pin `IconButton` modelled on `_RangeToggle` :178, before the 3D button; the banner between the header and the chart when placement is on; new constructor params `onOpenInNotes(String id)` and `GlobalKey profileKey` is not needed since the page already caches the section, pass `onOpenInNotes` only)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart_host.dart:359-480` (pass `events: dropOrphanAnnotations(analysis.events, dive.notes)`, `showAnnotations`, `annotationPlacement`, `onAnnotationPlaced`, `onAnnotationTap`, `onSecondaryTapAt`, `focusedId`; new params `AnnotationChartCallbacks? annotations`)
- Modify: `lib/l10n/arb/app_en.arb` (`diveLog_annotation_*` group, after Task 9's keys): `add` "Add annotation", `banner_place` "Tap the profile where it happened. Press and hold to fine-tune.", `banner_move` "Tap the new spot for this annotation.", `banner_cancel` "Cancel", `popup_meta` "{time} at {depth}", `popup_openInNotes` "Open in Notes", `popup_move` "Move", `popup_remove` "Remove", `contextMenu_annotateAt` "Annotate at {time}", `removed` "Annotation removed"
- Test: `test/features/dive_log/presentation/widgets/annotation_marker_popup_test.dart`, `test/features/dive_log/presentation/widgets/dive_detail/dive_detail_annotation_flow_test.dart` (pattern: an existing detail page test under `test/features/dive_log/presentation/pages/` that pumps `DiveDetailPage` with an in-memory database; find one with `grep -rl "DiveDetailPage(" test/features/dive_log/presentation/pages | head -3`)

**Interfaces:**
- `annotationFocusProvider = StateProvider.autoDispose.family<String?, String>` (annotation id to light up / open; cleared by whoever consumed it).
- `typedef AnnotationChartCallbacks = ({bool placement, void Function(int seconds, double? depth) onPlaced, void Function(ProfileEvent, Offset) onTap, void Function(int seconds, double? depth, Offset) onSecondaryTap, String? focusedId})`.
- `Future<void> showAnnotationMarkerPopup(BuildContext context, {required ProfileEvent annotation, required Offset globalPosition, required UnitFormatter units, required VoidCallback onOpenInNotes, required VoidCallback onMove, required VoidCallback onEditTime, required VoidCallback onRemove})`: `showMenu` positioned at `globalPosition` with a single disabled `PopupMenuItem` whose child is a 280 px wide column: the words (`bodyMedium`), a tappable meta line `popup_meta(formatMinutesSeconds(timestamp), units.formatDepth(depth))` (depth omitted when null) that calls `onEditTime`, and a row of three `TextButton`s. Each action pops the menu first.
- `Future<AnnotationSheetResult?> showAnnotationSheet(context, {required int seconds, double? depthMeters, required int maxSeconds, required UnitFormatter units})`: the chart-flow sheet: title `sheetTitle_new`, the time (a `MinutesSecondsField` prefilled, same validation as Task 9), the depth line, the words field (required, non-blank), Cancel / `action_add`. Composes Task 9's `AnnotationForm` with `onWordsChanged` set (words required) and no mini profile.
- `AnnotationPlacementBanner({required String text, required VoidCallback onCancel})`: a `MaterialBanner`-styled row in `tertiaryContainer`.
- `DiveDetailAnnotationActions` (a plain class holding `ref`, `context`, `diveId`, `units`):
  - `Future<void> place(int seconds, double? depth)`: reads `annotationPlacementProvider(diveId)`; `movingId != null`: `moveAnnotation` and cancel placement; else `showAnnotationSheet`, and on a result `addAnnotation(...)`; cancel placement either way.
  - `Future<void> onMarkerTap(ProfileEvent a, Offset at)`: `showAnnotationMarkerPopup` with `onOpenInNotes: () => onOpenInNotes(a.id)`, `onMove: () => startMove(a.id)`, `onEditTime: showAnnotationSheet(seconds: a.timestamp, ...)` then `moveAnnotation` (words field hidden: pass `words: a.description` so the form shows no words field), `onRemove: removeAnnotation` then a SnackBar `removed`.
  - `Future<void> onSecondaryTap(int seconds, double? depth, Offset at)`: `showMenu` with one item `contextMenu_annotateAt(formatMinutesSeconds(seconds))`, then `place(seconds, depth)`.
- The host reads `annotationPlacementProvider(dive.id)` and `annotationFocusProvider(dive.id)`, builds the actions object, and passes the callbacks; when `focusedId` changes to non-null the marker layer (Task 10) reports its centre once through `onTap` after the next frame, the host then clears the focus provider. Implement that in the layer as: `didUpdateWidget` sees a new non-null `focusedId`, `WidgetsBinding.instance.addPostFrameCallback` computes the dot's global centre and calls `onTap`.
- The fullscreen page (Task 14) consumes the same actions class.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('the popup shows the words, the time and depth in the diver units, and three actions', ...); // feet diver: '21:30 at 64 ft'
testWidgets('pin, tap the chart, type words, Add: a marker appears and Notes gains the paragraph', (tester) async {
  // pump DiveDetailPage for a dive with a 1200 s profile and notes 'First.'
  // tap find.byTooltip('Add annotation'); expect the banner text
  // tap the chart at its centre; enter 'Octo free-flowed'; tap 'Add'
  // expect one annotation row; dive.notes == 'First.\n\n[Octo free-flowed](annotation:<id>)'; Notes card shows push_pin
});
testWidgets('Remove from the popup deletes the row and keeps the words', ...);
testWidgets('Move re-enters placement and the next tap updates the time', ...);
testWidgets('a dive with no profile accepts an annotation by typed time', ...); // manual dive, pin button, chart tap gives seconds, depth null, row depth null
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests, `flutter analyze`, `test/architecture/`, `test/shared/`.**
- [ ] **Step 5: Commit** `feat(dive-log): add, move and remove annotations from the dive profile`.

---

### Task 14: Notes card wiring, Open in Notes, and the fullscreen profile

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_text_sections.dart:60-95` (`DiveNotesSection` becomes a `ConsumerWidget`; watches `diveAnnotationsProvider(dive.id)`; passes `annotationTimes`, `onAnnotationTap`, `highlightedAnnotationId` to `MarkdownNotesView`)
- Create: `lib/features/dive_log/presentation/providers/dive_annotations_provider.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:120-130` (a `_notesSectionKey` beside `_safetyReviewSectionKey`; `_scrollToNotes(String id)` and `_scrollToProfileAndFocus(String id)` using the `Scrollable.ensureVisible` pattern at :124; when `layout.foldsSections` and the Notes fold is collapsed, call `ref.read(settingsProvider.notifier).setDiveDetailSectionExpanded(DiveDetailSectionId.notes, true)` and wait one frame before scrolling)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart:66`, `:285-286` (`notesKey` param, applied like `safetyReviewKey` at :212)
- Modify: `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart:407-600` (pass the same annotation callbacks the host passes, through a `DiveDetailAnnotationActions` built there with `onOpenInNotes` popping the page then focusing), `:434` legend leading (pin toggle beside `_RangeModeToggle` :753), and the banner as a top `Positioned` in the page's Stack
- Test: `test/features/dive_log/presentation/widgets/dive_detail/dive_notes_section_annotations_test.dart`, one test added to the detail flow test of Task 13, `test/features/dive_log/presentation/pages/fullscreen_profile_annotations_test.dart`

**Interfaces:**
- `diveAnnotationsProvider = FutureProvider.autoDispose.family<List<ProfileEvent>, String>`: `annotationRepository.annotationsForDive(diveId)` filtered with `dropOrphanAnnotations(…, dive.notes)` (reads `diveProvider(diveId)` for the notes), invalidated on `watchAnalysisInputChanges()` like `diveComputerEventsProvider` (`profile_analysis_provider.dart:46`).
- `highlightedAnnotationId` comes from a `StateProvider.autoDispose.family<String?, String>` `annotationNotesHighlightProvider`, set by `_scrollToNotes` and cleared by a 1,500 ms `Future.delayed` guarded by `mounted`.
- `onAnnotationTap(id)` on the Notes card calls the page's `_scrollToProfileAndFocus(id)`: `ensureVisible` on the profile section's context (the page holds the cached section widget; give it a `GlobalKey` when caching in `_profileSectionFor`), then `ref.read(annotationFocusProvider(diveId).notifier).state = id`.
- The popup's "Open in Notes" calls `_scrollToNotes(id)`.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('the Notes card shows each annotation with its time and jumps to the profile on tap', ...); // after tap: annotationFocusProvider == id
testWidgets('Open in Notes scrolls to the Notes card and highlights the passage', ...); // pump 1600 ms afterwards: highlight gone
testWidgets('the fullscreen profile draws annotations and can place one', ...);
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests, `flutter analyze`.**
- [ ] **Step 5: Commit** `feat(dive-log): link the notes card and the fullscreen profile to annotations`.

---

### Task 15: PDF notes carry the annotation time

**Files:**
- Modify: `lib/core/services/pdf_templates/pdf_notes_markdown.dart:17`, `:37`, `:327` (+ `Map<String, String> annotationTimes = const {}` on both public functions; `_link` renders an annotation link as `words (m:ss)` plain text when the id is in the map, bare words otherwise)
- Modify: `lib/core/services/export/pdf/pdf_export_service.dart` (load `DiveComputerRepository().getEventsForDives(ids)` once for the dives being exported, map each dive's annotation rows with `annotationTimesOf`, and hand the map to the template call) and the three templates' notes calls (`pdf_template_detailed.dart:850`, `pdf_template_naui.dart:502`, `pdf_template_padi.dart:411`) to forward it from the template's dive context (add a `Map<String, Map<String, String>> annotationTimesByDive` to whatever context object the templates already receive; if they receive only the `Dive`, add an optional parameter to the template entry points).
- Test: `test/core/services/pdf_templates/pdf_notes_markdown_test.dart` (add two tests)

- [ ] **Step 1: Write the failing tests**

```dart
test('an annotation link in the PDF reads words then time', () {
  // notesMarkdownPdfBlocks('I [felt sick](annotation:a1).', style: s, annotationTimes: {'a1': '21:30'})
  // flatten the spans' text: contains 'felt sick (21:30)'
});
test('a dangling annotation link in the PDF is bare words', ...);
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run `test/core/services/pdf_templates/` and `test/core/services/export/pdf/`.**
- [ ] **Step 5: Commit** `feat(pdf): show annotation times after their words in notes`.

---

### Task 16: Localisation fan-out and generated code

**Files:**
- Modify: all ten locale ARBs (`app_ar, app_de, app_es, app_fr, app_he, app_hu, app_it, app_nl, app_pt, app_zh`) for every key added in Tasks 1, 8, 9, 12 and 13, inserted textually by anchor line (python: build `'  "%s": %s,' % (key, json.dumps(value, ensure_ascii=False))`, then `json.loads` the file to prove it parses; never json round-trip a locale file).
- Generated: `lib/l10n/arb/app_localizations*.dart` via `flutter gen-l10n`, run LAST.
- Test: `flutter gen-l10n` output reports zero new untranslated messages for these keys; `grep -A1 "get diveLog_annotation_add" lib/l10n/arb/app_localizations_de.dart` shows German.

- [ ] **Step 1: List the keys**: `git diff origin/main...HEAD -- lib/l10n/arb/app_en.arb | grep '^+  "' | grep -v '"@'`.
- [ ] **Step 2: Translate** each into the ten locales, matching each file's neighbouring terms (ar "ملف الغوصة" for profile, zh "轮廓" for dive profile, keep ICU `{words}`, `{time}`, `{depth}` verbatim).
- [ ] **Step 3: Run `flutter gen-l10n`**, then `git diff --numstat lib/l10n/arb/` and explain any locale row smaller than its siblings.
- [ ] **Step 4: Run `flutter analyze` and `test/l10n/`** (or whichever l10n guard test exists: `ls test | grep -i l10n`).
- [ ] **Step 5: Commit** `i18n: translate the annotation strings`.

---

### Task 17: Whole-feature verification and screenshots

- [ ] **Step 1:** `dart format .`, `flutter analyze`, then `flutter test test/features/dive_log test/shared test/core/text test/core/services/sync test/core/services/export test/features/dive_import test/features/dive_computer test/architecture` (background, log to the scratchpad).
- [ ] **Step 2:** Fix anything red, commit as `fix: ...`.
- [ ] **Step 3:** Capture the after screenshots (the build-feature skill's Screenshots section): detail page with markers and the popup open, placement banner, the chart-flow sheet, the Notes card with a linked passage, the edit page toolbar with the pin and its sheet, light and dark for the marker colour.
