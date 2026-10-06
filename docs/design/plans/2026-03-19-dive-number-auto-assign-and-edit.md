# Dive Number Auto-Assignment and Manual Editing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auto-assign chronological dive numbers during dive computer import and allow manual editing of dive numbers on the dive edit form.

**Architecture:** Inject `DiveRepository` into `DiveImportService` so it can call `getDiveNumberForDate()`. Add a `diveNumber` parameter to `importProfile()`. Sort downloaded dives oldest-first before import. Add a `TextFormField` to the dive edit form for manual dive number entry.

**Tech Stack:** Flutter, Drift ORM, Riverpod, Mockito for tests

**Spec:** `docs/superpowers/specs/2026-03-19-dive-number-auto-assign-and-edit-design.md`

---

### Task 1: Add `diveNumber` parameter to `importProfile()`

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:716-791`

- [ ] **Step 1: Add `diveNumber` parameter to `importProfile()` signature**

In `importProfile()`, add an optional `int? diveNumber` parameter and include it in the `DivesCompanion`:

```dart
// In the method signature (line 716), add:
Future<String> importProfile({
    required String computerId,
    required DateTime profileStartTime,
    required List<ProfilePointData> points,
    required int durationSeconds,
    double? maxDepth,
    double? avgDepth,
    bool isPrimary = false,
    String? diverId,
    List<TankData>? tanks,
    String? decoAlgorithm,
    int? gfLow,
    int? gfHigh,
    int? decoConservatism,
    List<EventData>? events,
    int? diveNumber, // <-- NEW
  }) async {
```

In the `DivesCompanion` construction (around line 771), add:

```dart
diveNumber: Value(diveNumber),
```

right after `diverId: Value(diverId),`.

- [ ] **Step 2: Verify the `_updateExistingDive` call site in `dive_import_service.dart` still compiles**

The `_updateExistingDive` method calls `importProfile()` without `diveNumber` — since the parameter is optional and nullable, this is fine. No change needed there.

- [ ] **Step 3: Run tests to verify nothing is broken**

Run: `flutter test test/features/dive_computer/`

Expected: All existing tests pass (no signature-breaking change since parameter is optional).

- [ ] **Step 4: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart
git commit -m "feat: add diveNumber parameter to importProfile()"
```

---

### Task 2: Inject `DiveRepository` into `DiveImportService` and assign dive numbers

**Files:**
- Modify: `lib/features/dive_computer/data/services/dive_import_service.dart:180-360`
- Modify: `lib/features/dive_computer/presentation/providers/download_providers.dart:22-24`

- [ ] **Step 1: Write the failing test for chronological dive number assignment**

Create: `test/features/dive_computer/data/services/dive_import_service_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

@GenerateMocks([DiveComputerRepository, DiveRepository])
import 'dive_import_service_test.mocks.dart';

void main() {
  late MockDiveComputerRepository mockComputerRepo;
  late MockDiveRepository mockDiveRepo;
  late DiveImportService service;

  final testComputer = DiveComputer(
    id: 'comp-1',
    name: 'Test Computer',
    vendor: 'Test',
    product: 'Test',
    model: 0,
    transport: TransportType.ble,
  );

  DownloadedDive createDownloadedDive({
    required DateTime startTime,
    int durationSeconds = 2700,
    double maxDepth = 20.0,
  }) {
    return DownloadedDive(
      fingerprint: 'fp-${startTime.millisecondsSinceEpoch}',
      startTime: startTime,
      durationSeconds: durationSeconds,
      maxDepth: maxDepth,
      avgDepth: maxDepth * 0.6,
      samples: const [],
      tanks: const [],
      gasMixes: const [],
      events: const [],
    );
  }

  setUp(() {
    mockComputerRepo = MockDiveComputerRepository();
    mockDiveRepo = MockDiveRepository();
    service = DiveImportService(
      repository: mockComputerRepo,
      diveRepository: mockDiveRepo,
    );

    // Default: no duplicates found
    when(mockComputerRepo.findMatchingDiveWithScore(
      profileStartTime: anyNamed('profileStartTime'),
      toleranceMinutes: anyNamed('toleranceMinutes'),
      durationSeconds: anyNamed('durationSeconds'),
      maxDepth: anyNamed('maxDepth'),
      fingerprint: anyNamed('fingerprint'),
    )).thenAnswer((_) async => null);

    // Default: importProfile returns a dive ID
    when(mockComputerRepo.importProfile(
      computerId: anyNamed('computerId'),
      profileStartTime: anyNamed('profileStartTime'),
      points: anyNamed('points'),
      durationSeconds: anyNamed('durationSeconds'),
      maxDepth: anyNamed('maxDepth'),
      avgDepth: anyNamed('avgDepth'),
      isPrimary: anyNamed('isPrimary'),
      diverId: anyNamed('diverId'),
      tanks: anyNamed('tanks'),
      decoAlgorithm: anyNamed('decoAlgorithm'),
      gfLow: anyNamed('gfLow'),
      gfHigh: anyNamed('gfHigh'),
      decoConservatism: anyNamed('decoConservatism'),
      events: anyNamed('events'),
      diveNumber: anyNamed('diveNumber'),
    )).thenAnswer((_) async => 'dive-id');
  });

  group('dive number assignment', () {
    test('assigns sequential dive numbers in chronological order', () async {
      final dive1 = createDownloadedDive(
        startTime: DateTime.utc(2024, 6, 15, 10, 0),
      );
      final dive2 = createDownloadedDive(
        startTime: DateTime.utc(2024, 6, 16, 10, 0),
      );
      final dive3 = createDownloadedDive(
        startTime: DateTime.utc(2024, 6, 17, 10, 0),
      );

      // Simulate: 0 dives before dive1, 1 before dive2, 2 before dive3
      when(mockDiveRepo.getDiveNumberForDate(
        DateTime.utc(2024, 6, 15, 10, 0),
        diverId: 'diver-1',
      )).thenAnswer((_) async => 1);
      when(mockDiveRepo.getDiveNumberForDate(
        DateTime.utc(2024, 6, 16, 10, 0),
        diverId: 'diver-1',
      )).thenAnswer((_) async => 2);
      when(mockDiveRepo.getDiveNumberForDate(
        DateTime.utc(2024, 6, 17, 10, 0),
        diverId: 'diver-1',
      )).thenAnswer((_) async => 3);

      await service.importDives(
        dives: [dive1, dive2, dive3],
        computer: testComputer,
        diverId: 'diver-1',
      );

      // Verify importProfile was called with correct dive numbers
      verify(mockComputerRepo.importProfile(
        computerId: 'comp-1',
        profileStartTime: DateTime.utc(2024, 6, 15, 10, 0),
        points: anyNamed('points'),
        durationSeconds: anyNamed('durationSeconds'),
        maxDepth: anyNamed('maxDepth'),
        avgDepth: anyNamed('avgDepth'),
        isPrimary: true,
        diverId: 'diver-1',
        tanks: anyNamed('tanks'),
        decoAlgorithm: anyNamed('decoAlgorithm'),
        gfLow: anyNamed('gfLow'),
        gfHigh: anyNamed('gfHigh'),
        decoConservatism: anyNamed('decoConservatism'),
        events: anyNamed('events'),
        diveNumber: 1,
      )).called(1);

      verify(mockComputerRepo.importProfile(
        computerId: 'comp-1',
        profileStartTime: DateTime.utc(2024, 6, 17, 10, 0),
        points: anyNamed('points'),
        durationSeconds: anyNamed('durationSeconds'),
        maxDepth: anyNamed('maxDepth'),
        avgDepth: anyNamed('avgDepth'),
        isPrimary: true,
        diverId: 'diver-1',
        tanks: anyNamed('tanks'),
        decoAlgorithm: anyNamed('decoAlgorithm'),
        gfLow: anyNamed('gfLow'),
        gfHigh: anyNamed('gfHigh'),
        decoConservatism: anyNamed('decoConservatism'),
        events: anyNamed('events'),
        diveNumber: 3,
      )).called(1);
    });

    test('sorts newest-first device data to oldest-first before import',
        () async {
      final olderDive = createDownloadedDive(
        startTime: DateTime.utc(2024, 6, 15, 10, 0),
      );
      final newerDive = createDownloadedDive(
        startTime: DateTime.utc(2024, 6, 16, 10, 0),
      );

      when(mockDiveRepo.getDiveNumberForDate(
        any,
        diverId: anyNamed('diverId'),
      )).thenAnswer((_) async => 1);

      // Pass newest-first (as device would send)
      await service.importDives(
        dives: [newerDive, olderDive],
        computer: testComputer,
        diverId: 'diver-1',
      );

      // Verify the older dive was imported first (called before newer)
      final captured = verify(mockComputerRepo.importProfile(
        computerId: anyNamed('computerId'),
        profileStartTime: captureAnyNamed('profileStartTime'),
        points: anyNamed('points'),
        durationSeconds: anyNamed('durationSeconds'),
        maxDepth: anyNamed('maxDepth'),
        avgDepth: anyNamed('avgDepth'),
        isPrimary: anyNamed('isPrimary'),
        diverId: anyNamed('diverId'),
        tanks: anyNamed('tanks'),
        decoAlgorithm: anyNamed('decoAlgorithm'),
        gfLow: anyNamed('gfLow'),
        gfHigh: anyNamed('gfHigh'),
        decoConservatism: anyNamed('decoConservatism'),
        events: anyNamed('events'),
        diveNumber: anyNamed('diveNumber'),
      )).captured;

      final importedTimes =
          captured.map((t) => (t as DateTime)).toList();
      expect(importedTimes[0].isBefore(importedTimes[1]), isTrue,
          reason: 'Older dive should be imported first');
    });

    test('assigns correct number when importing between existing dives',
        () async {
      final dive = createDownloadedDive(
        startTime: DateTime.utc(2024, 6, 15, 10, 0),
      );

      // Simulate: 5 dives already exist before this date
      when(mockDiveRepo.getDiveNumberForDate(
        DateTime.utc(2024, 6, 15, 10, 0),
        diverId: 'diver-1',
      )).thenAnswer((_) async => 6);

      final result = await service.importDives(
        dives: [dive],
        computer: testComputer,
        diverId: 'diver-1',
      );

      expect(result.imported, 1);
      verify(mockComputerRepo.importProfile(
        computerId: anyNamed('computerId'),
        profileStartTime: anyNamed('profileStartTime'),
        points: anyNamed('points'),
        durationSeconds: anyNamed('durationSeconds'),
        maxDepth: anyNamed('maxDepth'),
        avgDepth: anyNamed('avgDepth'),
        isPrimary: anyNamed('isPrimary'),
        diverId: anyNamed('diverId'),
        tanks: anyNamed('tanks'),
        decoAlgorithm: anyNamed('decoAlgorithm'),
        gfLow: anyNamed('gfLow'),
        gfHigh: anyNamed('gfHigh'),
        decoConservatism: anyNamed('decoConservatism'),
        events: anyNamed('events'),
        diveNumber: 6,
      )).called(1);
    });

    test('resolveConflict with importAsNew assigns dive number', () async {
      final dive = createDownloadedDive(
        startTime: DateTime.utc(2024, 6, 15, 10, 0),
      );

      when(mockDiveRepo.getDiveNumberForDate(
        DateTime.utc(2024, 6, 15, 10, 0),
        diverId: 'diver-1',
      )).thenAnswer((_) async => 3);

      final conflict = ImportConflict(
        downloaded: dive,
        existingDiveId: 'existing-1',
        duplicateResult: DuplicateResult(
          matchingDiveId: 'existing-1',
          confidence: DuplicateConfidence.likely,
          score: 0.8,
        ),
      );

      await service.resolveConflict(
        conflict,
        ConflictResolution.importAsNew,
        'comp-1',
        diverId: 'diver-1',
      );

      verify(mockComputerRepo.importProfile(
        computerId: anyNamed('computerId'),
        profileStartTime: anyNamed('profileStartTime'),
        points: anyNamed('points'),
        durationSeconds: anyNamed('durationSeconds'),
        maxDepth: anyNamed('maxDepth'),
        avgDepth: anyNamed('avgDepth'),
        isPrimary: anyNamed('isPrimary'),
        diverId: anyNamed('diverId'),
        tanks: anyNamed('tanks'),
        decoAlgorithm: anyNamed('decoAlgorithm'),
        gfLow: anyNamed('gfLow'),
        gfHigh: anyNamed('gfHigh'),
        decoConservatism: anyNamed('decoConservatism'),
        events: anyNamed('events'),
        diveNumber: 3,
      )).called(1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/features/dive_computer/data/services/dive_import_service_test.dart`

Expected: Compilation error — `DiveImportService` does not accept `diveRepository` parameter yet.

- [ ] **Step 3: Add `DiveRepository` dependency to `DiveImportService`**

In `lib/features/dive_computer/data/services/dive_import_service.dart`, modify the class:

```dart
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

class DiveImportService {
  final DiveComputerRepository _repository;
  final DiveRepository? _diveRepository;
  final DiveParser _parser;

  DiveImportService({
    required DiveComputerRepository repository,
    DiveRepository? diveRepository,
    DiveParser? parser,
  }) : _repository = repository,
       _diveRepository = diveRepository,
       _parser = parser ?? const DiveParser();
```

- [ ] **Step 4: Sort dives chronologically and assign numbers in `importDives()`**

In `importDives()`, before the for-loop (line 211), add a sort:

```dart
    // Sort dives chronologically (oldest first) so that sequential
    // getDiveNumberForDate() calls produce correct numbering.
    final sortedDives = List<DownloadedDive>.of(dives)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    for (final dive in sortedDives) {
```

Replace the existing `for (final dive in dives)` with `for (final dive in sortedDives)`.

- [ ] **Step 5: Pass dive number through `_importNewDive()` to `importProfile()`**

Modify `_importNewDive()` to calculate and pass the dive number:

```dart
  Future<String> _importNewDive(
    DownloadedDive dive,
    String computerId,
    String? diverId,
  ) async {
    // Calculate chronological dive number
    int? diveNumber;
    if (_diveRepository != null) {
      diveNumber = await _diveRepository.getDiveNumberForDate(
        dive.startTime,
        diverId: diverId,
      );
    }

    // Parse profile data
    final profilePoints = _parser.parseProfile(dive);

    // Convert tanks to TankData
    final tanks = _parser.parseTanks(dive);

    // Convert events to EventData
    final events = _convertEvents(dive.events);

    // Import using repository
    final diveId = await _repository.importProfile(
      computerId: computerId,
      profileStartTime: dive.startTime,
      points: profilePoints,
      durationSeconds: dive.durationSeconds,
      maxDepth: dive.maxDepth,
      avgDepth: dive.avgDepth,
      isPrimary: true,
      diverId: diverId,
      tanks: tanks,
      decoAlgorithm: dive.decoAlgorithm,
      gfLow: dive.gfLow,
      gfHigh: dive.gfHigh,
      decoConservatism: dive.decoConservatism,
      events: events,
      diveNumber: diveNumber,
    );

    return diveId;
  }
```

- [ ] **Step 6: Update the provider to inject `DiveRepository`**

In `lib/features/dive_computer/presentation/providers/download_providers.dart`, update `diveImportServiceProvider`:

```dart
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

final diveImportServiceProvider = Provider<DiveImportService>((ref) {
  final repository = ref.watch(diveComputerRepositoryProvider);
  final diveRepository = ref.watch(diveRepositoryProvider);
  return DiveImportService(
    repository: repository,
    diveRepository: diveRepository,
  );
});
```

Note: `diveRepositoryProvider` is defined in `lib/features/dive_log/presentation/providers/dive_providers.dart` — import it.

- [ ] **Step 7: Generate mocks and run tests**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/features/dive_computer/data/services/dive_import_service_test.dart`

Expected: All 4 tests pass.

- [ ] **Step 8: Run full dive_computer test suite to check for regressions**

Run: `flutter test test/features/dive_computer/`

Expected: All existing tests pass. The `download_notifier_fingerprint_test.dart` mocks `DiveImportService` — since the new `diveRepository` parameter is optional, existing mock generation should still work. If mock regeneration is needed, run `dart run build_runner build --delete-conflicting-outputs` first.

- [ ] **Step 9: Commit**

```bash
git add lib/features/dive_computer/data/services/dive_import_service.dart \
        lib/features/dive_computer/presentation/providers/download_providers.dart \
        test/features/dive_computer/data/services/dive_import_service_test.dart \
        test/features/dive_computer/data/services/dive_import_service_test.mocks.dart
git commit -m "feat: auto-assign dive numbers during dive computer import"
```

---

### Task 3: Add localization strings for dive number field

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`
- Modify: All other `lib/l10n/arb/app_*.arb` locale files

- [ ] **Step 1: Add English strings**

Add to `lib/l10n/arb/app_en.arb`:

```json
"diveLog_edit_label_diveNumber": "Dive #",
"diveLog_edit_hint_diveNumber": "Auto-assigned if left blank"
```

Place these near the other `diveLog_edit_label_*` entries.

- [ ] **Step 2: Add translations to all other locale files**

Add appropriate translations for each locale file (`app_de.arb`, `app_fr.arb`, `app_es.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_hu.arb`, `app_he.arb`, `app_ar.arb`). Use the same key names with translated values.

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n` (or `flutter pub get` if auto-generation is configured)

Expected: No errors. New getters available on `AppLocalizations`.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/
git commit -m "feat(l10n): add dive number field translations"
```

---

### Task 4: Add dive number field to the dive edit form

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`

- [ ] **Step 1: Add the `TextEditingController` and dispose it**

In the state class (around line 93, near other controllers), add:

```dart
final _diveNumberController = TextEditingController();
```

In `dispose()` (line 479), add before `super.dispose()`:

```dart
_diveNumberController.dispose();
```

- [ ] **Step 2: Populate the controller when loading an existing dive**

In `_loadExistingDive()`, inside the `setState(() {` block (around line 280), add:

```dart
          _diveNumberController.text =
              dive.diveNumber?.toString() ?? '';
```

- [ ] **Step 3: Build the dive number field widget**

Add a new method to the state class:

```dart
  Widget _buildDiveNumberField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        width: 160,
        child: TextFormField(
          controller: _diveNumberController,
          decoration: InputDecoration(
            labelText: context.l10n.diveLog_edit_label_diveNumber,
            hintText: context.l10n.diveLog_edit_hint_diveNumber,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
      ),
    );
  }
```

Add the necessary import at the top of the file (if not already present):

```dart
import 'package:flutter/services.dart';
```

- [ ] **Step 4: Insert the field at the top of the form**

In the form body (around line 521), add the dive number field before `_buildDateTimeSection()`:

```dart
        children: [
          _buildDiveNumberField(),
          _buildDateTimeSection(),
```

- [ ] **Step 5: Wire the controller into `_saveDive()`**

In `_saveDive()` (around line 3420), replace:

```dart
        diveNumber: _existingDive?.diveNumber,
```

with:

```dart
        diveNumber: _diveNumberController.text.isNotEmpty
            ? int.parse(_diveNumberController.text)
            : null,
```

Note: When `diveNumber` is null, the existing `addDive()` notifier (in `dive_providers.dart:243-261`) already calls `assignMissingDiveNumbers()` to auto-assign chronologically, so no additional async call to `getDiveNumberForDate()` is needed in `_saveDive()`. The spec mentions calling `getDiveNumberForDate()` at save time, but the existing notifier logic achieves the same result via batch assignment — this is simpler and consistent with the current architecture.

- [ ] **Step 6: Run the app and manually verify**

Run: `flutter run -d macos`

Verify:
1. New dive form shows "Dive #" field at the top
2. Field accepts only digits
3. Editing an existing dive with a number pre-populates the field
4. Saving with a number stores it
5. Saving without a number auto-assigns via the notifier's `assignMissingDiveNumbers()`

- [ ] **Step 7: Run format and analyze**

Run: `dart format lib/features/dive_log/presentation/pages/dive_edit_page.dart && flutter analyze`

Expected: No formatting changes, no analysis errors.

- [ ] **Step 8: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart
git commit -m "feat: add dive number field to dive edit form"
```

---

### Task 5: Run full test suite and final verification

**Files:** None (verification only)

- [ ] **Step 1: Run all tests**

Run: `flutter test`

Expected: All tests pass.

- [ ] **Step 2: Run format check**

Run: `dart format --set-exit-if-changed lib/ test/`

Expected: No formatting issues.

- [ ] **Step 3: Run analysis**

Run: `flutter analyze`

Expected: No issues.

- [ ] **Step 4: Final commit (if any formatting fixes needed)**

Only if steps 2 or 3 required changes:

```bash
git add -A
git commit -m "chore: format and lint fixes"
```
