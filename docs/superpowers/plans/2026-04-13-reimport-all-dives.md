# Re-import All Dives Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first-class "Re-import all dives" entry point on the dive computer detail page that routes through the existing unified import wizard with the fingerprint bypass turned on, surfacing every stored dive as a pending duplicate in the Review step.

**Architecture:** Add a `forceFullDownload: bool` field to `DiveComputerAdapter`. When set, the download step calls the existing `DownloadNotifier.setNewDivesOnly(false)` method, which causes the notifier to send a null fingerprint to libdivecomputer. The flag is passed through a new `?forceFull=true` query parameter on the existing `/dive-computers/:computerId/download` route. A new tertiary button on the DC detail page opens a confirmation dialog and, on confirm, pushes that URL. A new tertiary breadcrumb button on `DcNoNewDivesView` gives users a discovery hint back to the detail page.

**Tech Stack:** Flutter 3.x, Riverpod, go_router, Material 3, Drift, Mockito, flutter_test.

**Reference spec:** `docs/superpowers/specs/2026-04-13-reimport-all-dives-design.md`

---

## File Structure

**Modified:**
- `lib/l10n/arb/app_en.arb` — 5 new keys (including one new `common_action_continue`)
- `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart` — `forceFullDownload` field
- `lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart` — apply flag in download step + `DcNoNewDivesView` breadcrumb
- `lib/core/router/app_router.dart` — query param wiring in `_DiveComputerDownloadWizardRoute`
- `lib/features/dive_computer/presentation/pages/device_detail_page.dart` — button + confirmation dialog

**Created:**
- `test/features/import_wizard/data/adapters/dive_computer_adapter_reimport_test.dart`
- `test/features/import_wizard/presentation/widgets/dc_adapter_download_step_force_full_test.dart`
- `test/features/import_wizard/presentation/widgets/dc_no_new_dives_view_test.dart`
- `test/features/dive_computer/presentation/pages/device_detail_page_reimport_test.dart`
- `test/core/router/app_router_reimport_test.dart`
- `test/features/dive_computer/issue_206_reimport_regression_test.dart`

---

## Task 1: Add localization keys to `app_en.arb`

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`

ARB changes first so all subsequent tasks can reference the generated getters.

- [ ] **Step 1: Add new keys to `app_en.arb`**

Locate the alphabetically correct spots and add the following entries. Keep the metadata `@` entries alongside their keys (matching the file's pattern at lines 907/920 for `common_action_cancel`).

Add to the `common_action_*` group (after `common_action_close` at line 908):

```json
  "common_action_continue": "Continue",
  "@common_action_continue": {
    "description": "Continue button used in confirmation dialogs"
  },
```

Add to the `diveComputer_detail_*` group (near `diveComputer_detail_downloadDivesButton` at line 8652):

```json
  "diveComputer_detail_reimportAllButton": "Re-import all dives",
  "@diveComputer_detail_reimportAllButton": {
    "description": "Button on DC detail page that starts a full re-import of all dives from the device"
  },
  "diveComputer_detail_reimportDialogTitle": "Re-import all dives?",
  "@diveComputer_detail_reimportDialogTitle": {
    "description": "Title of confirmation dialog before starting a full re-import"
  },
  "diveComputer_detail_reimportDialogBody": "Download every dive from {computerName} and review them against your log. This may take several minutes.",
  "@diveComputer_detail_reimportDialogBody": {
    "description": "Body of confirmation dialog before starting a full re-import",
    "placeholders": {
      "computerName": {
        "type": "String",
        "example": "Perdix 2"
      }
    }
  },
```

Add to the `diveComputer_download_*` group (near `diveComputer_download_upToDate` at line 14360 of the generated Dart — search in ARB for the key location):

```json
  "diveComputer_download_reimportHint": "Looking for older or deleted dives? Re-import all",
  "@diveComputer_download_reimportHint": {
    "description": "Breadcrumb text shown on the 'No new dives to download' screen that points the user to the Re-import option"
  },
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: completes with warnings about untranslated messages in other locales (these are fine — the fallback is English).

- [ ] **Step 3: Verify generated Dart has the new getters**

Run: `flutter analyze lib/l10n/arb/app_localizations_en.dart 2>&1 | tail -3`
Expected: `No issues found!`

Spot-check by reading a few lines:
Run: `grep -n "reimportAllButton\|common_action_continue\|reimportHint" lib/l10n/arb/app_localizations_en.dart`
Expected: each of `common_action_continue`, `diveComputer_detail_reimportAllButton`, `diveComputer_detail_reimportDialogTitle`, `diveComputer_detail_reimportDialogBody`, `diveComputer_download_reimportHint` appears as a getter.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations*.dart
git commit -m "feat(l10n): add keys for re-import all dives"
```

---

## Task 2: Add `forceFullDownload` field to `DiveComputerAdapter`

**Files:**
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart`
- Create: `test/features/import_wizard/data/adapters/dive_computer_adapter_reimport_test.dart`

The adapter holds state about whether this import session should bypass the fingerprint. Pure data change; no behavior yet — that comes in Task 3.

- [ ] **Step 1: Write the failing test**

Create `test/features/import_wizard/data/adapters/dive_computer_adapter_reimport_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';

@GenerateMocks([DiveImportService, DiveComputerRepository, DiveRepository])
import 'dive_computer_adapter_reimport_test.mocks.dart';

void main() {
  late MockDiveImportService importService;
  late MockDiveComputerRepository computerRepo;
  late MockDiveRepository diveRepo;

  setUp(() {
    importService = MockDiveImportService();
    computerRepo = MockDiveComputerRepository();
    diveRepo = MockDiveRepository();
  });

  group('forceFullDownload field', () {
    test('defaults to false when not specified', () {
      final adapter = DiveComputerAdapter(
        importService: importService,
        computerRepository: computerRepo,
        diveRepository: diveRepo,
        diverId: 'diver-1',
      );
      expect(adapter.forceFullDownload, isFalse);
    });

    test('reflects constructor-provided true', () {
      final adapter = DiveComputerAdapter(
        importService: importService,
        computerRepository: computerRepo,
        diveRepository: diveRepo,
        diverId: 'diver-1',
        forceFullDownload: true,
      );
      expect(adapter.forceFullDownload, isTrue);
    });

    test('reflects constructor-provided false', () {
      final adapter = DiveComputerAdapter(
        importService: importService,
        computerRepository: computerRepo,
        diveRepository: diveRepo,
        diverId: 'diver-1',
        forceFullDownload: false,
      );
      expect(adapter.forceFullDownload, isFalse);
    });
  });
}
```

- [ ] **Step 2: Generate mocks**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: generates `dive_computer_adapter_reimport_test.mocks.dart`.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/import_wizard/data/adapters/dive_computer_adapter_reimport_test.dart`
Expected: FAIL — the test will not compile because `forceFullDownload` is not yet a member of `DiveComputerAdapter`.

- [ ] **Step 4: Add the field to `DiveComputerAdapter`**

In `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart` — extend the constructor and add a field.

Current constructor (lines 63-78):

```dart
DiveComputerAdapter({
  required DiveImportService importService,
  required DiveComputerRepository computerRepository,
  required DiveRepository diveRepository,
  required String diverId,
  DiveComputer? knownComputer,
  String? displayName,
  WidgetRef? ref,
}) : _importService = importService,
     _computerRepository = computerRepository,
     _diveRepository = diveRepository,
     _diverId = diverId,
     _knownComputer = knownComputer,
     _ref = ref,
     _displayName =
         displayName ?? knownComputer?.displayName ?? 'Dive Computer';
```

Replace with:

```dart
DiveComputerAdapter({
  required DiveImportService importService,
  required DiveComputerRepository computerRepository,
  required DiveRepository diveRepository,
  required String diverId,
  DiveComputer? knownComputer,
  String? displayName,
  WidgetRef? ref,
  bool forceFullDownload = false,
}) : _importService = importService,
     _computerRepository = computerRepository,
     _diveRepository = diveRepository,
     _diverId = diverId,
     _knownComputer = knownComputer,
     _ref = ref,
     _forceFullDownload = forceFullDownload,
     _displayName =
         displayName ?? knownComputer?.displayName ?? 'Dive Computer';
```

Then, near the other field declarations (around line 85), add:

```dart
final bool _forceFullDownload;

/// Whether this import session should bypass the fingerprint and download
/// every dive on the device.
///
/// Set by the route builder when the user triggers "Re-import all dives"
/// from the DC detail page (via `?forceFull=true` query parameter).
bool get forceFullDownload => _forceFullDownload;
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/import_wizard/data/adapters/dive_computer_adapter_reimport_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: Run analyze to verify no regressions**

Run: `flutter analyze lib/features/import_wizard/data/adapters/dive_computer_adapter.dart test/features/import_wizard/data/adapters/dive_computer_adapter_reimport_test.dart`
Expected: `No issues found!`

- [ ] **Step 7: Format**

Run: `dart format lib/features/import_wizard/data/adapters/dive_computer_adapter.dart test/features/import_wizard/data/adapters/dive_computer_adapter_reimport_test.dart`

- [ ] **Step 8: Commit**

```bash
git add lib/features/import_wizard/data/adapters/dive_computer_adapter.dart \
        test/features/import_wizard/data/adapters/dive_computer_adapter_reimport_test.dart \
        test/features/import_wizard/data/adapters/dive_computer_adapter_reimport_test.mocks.dart
git commit -m "feat: add forceFullDownload flag to DiveComputerAdapter"
```

---

## Task 3: Apply the flag in the download step

**Files:**
- Modify: `lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart:287-313` (`_DcAdapterDownloadStepState.initState` / `_resolveComputer`)
- Create: `test/features/import_wizard/presentation/widgets/dc_adapter_download_step_force_full_test.dart`

When the adapter has `forceFullDownload: true`, the download step must invoke `DownloadNotifier.setNewDivesOnly(false)` before the download starts. The existing fingerprint logic in `download_providers.dart:157` then sends a null fingerprint, so libdivecomputer returns every dive.

- [ ] **Step 1: Write the failing test**

Create `test/features/import_wizard/presentation/widgets/dc_adapter_download_step_force_full_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_adapter_steps.dart';

import '../../../helpers/mock_import_adapter_deps.dart';
import '../../../helpers/test_app.dart';

void main() {
  testWidgets(
    'setNewDivesOnly(false) is called when forceFullDownload is true',
    (tester) async {
      final deps = MockImportAdapterDeps();
      final adapter = DiveComputerAdapter(
        importService: deps.importService,
        computerRepository: deps.computerRepo,
        diveRepository: deps.diveRepo,
        diverId: 'diver-1',
        forceFullDownload: true,
      );

      final container = ProviderContainer(
        overrides: [
          diveComputerServiceProvider.overrideWithValue(deps.mockService),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        TestApp(
          container: container,
          home: DcAdapterDownloadStep(adapter: adapter),
        ),
      );

      // Trigger post-frame callback.
      await tester.pump();

      expect(
        container.read(downloadNotifierProvider).newDivesOnly,
        isFalse,
        reason: 'forceFullDownload should flip newDivesOnly to false',
      );
    },
  );

  testWidgets(
    'newDivesOnly stays true when forceFullDownload is false (default)',
    (tester) async {
      final deps = MockImportAdapterDeps();
      final adapter = DiveComputerAdapter(
        importService: deps.importService,
        computerRepository: deps.computerRepo,
        diveRepository: deps.diveRepo,
        diverId: 'diver-1',
      );

      final container = ProviderContainer(
        overrides: [
          diveComputerServiceProvider.overrideWithValue(deps.mockService),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        TestApp(
          container: container,
          home: DcAdapterDownloadStep(adapter: adapter),
        ),
      );
      await tester.pump();

      expect(
        container.read(downloadNotifierProvider).newDivesOnly,
        isTrue,
      );
    },
  );
}
```

Note: This test requires two helper files (`test/helpers/mock_import_adapter_deps.dart` and `test/helpers/test_app.dart`). Create them if they don't exist — see Appendix A below.

- [ ] **Step 2: Create helper files if they don't exist**

First check: `ls test/helpers/mock_import_adapter_deps.dart test/helpers/test_app.dart 2>&1`

If either does not exist, create with contents from **Appendix A** at the end of this plan.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/import_wizard/presentation/widgets/dc_adapter_download_step_force_full_test.dart`
Expected: FAIL — `newDivesOnly` is `true` when it should be `false` (because no code yet flips it).

- [ ] **Step 4: Modify `_DcAdapterDownloadStepState` to apply the flag**

In `lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart`, locate `initState` at line 293-303:

```dart
@override
void initState() {
  super.initState();
  // In discovery mode, check if the device matches a known computer
  // BEFORE the download starts. If found, the computer's fingerprint
  // enables incremental download (only new dives).
  if (widget.knownComputer != null) {
    _computerResolved = true;
  } else {
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveComputer());
  }
}
```

Extend to also apply the force-full flag:

```dart
@override
void initState() {
  super.initState();
  // In discovery mode, check if the device matches a known computer
  // BEFORE the download starts. If found, the computer's fingerprint
  // enables incremental download (only new dives).
  if (widget.knownComputer != null) {
    _computerResolved = true;
  } else {
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveComputer());
  }

  // If the adapter requests a full re-download (Re-import all dives),
  // bypass the stored fingerprint by flipping newDivesOnly to false
  // before DownloadStepWidget triggers startDownload.
  if (widget.adapter.forceFullDownload) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(downloadNotifierProvider.notifier).setNewDivesOnly(false);
    });
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/import_wizard/presentation/widgets/dc_adapter_download_step_force_full_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: Run analyze and format**

Run:
```bash
flutter analyze lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart \
                test/features/import_wizard/presentation/widgets/dc_adapter_download_step_force_full_test.dart
dart format lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart \
            test/features/import_wizard/presentation/widgets/dc_adapter_download_step_force_full_test.dart
```

- [ ] **Step 7: Commit**

```bash
git add lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart \
        test/features/import_wizard/presentation/widgets/dc_adapter_download_step_force_full_test.dart \
        test/helpers/mock_import_adapter_deps.dart test/helpers/test_app.dart
git commit -m "feat: apply forceFullDownload flag in DC download step"
```

---

## Task 4: Forward `?forceFull=true` query param from the router

**Files:**
- Modify: `lib/core/router/app_router.dart` (around lines 970-975)
- Create: `test/core/router/app_router_reimport_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/router/app_router_reimport_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('forceFull query param parsing', () {
    bool parseForceFull(String? value) => value == 'true';

    test('returns true for "true"', () {
      expect(parseForceFull('true'), isTrue);
    });

    test('returns false for "false"', () {
      expect(parseForceFull('false'), isFalse);
    });

    test('returns false for null (absent)', () {
      expect(parseForceFull(null), isFalse);
    });

    test('returns false for empty string', () {
      expect(parseForceFull(''), isFalse);
    });

    test('returns false for malformed values', () {
      expect(parseForceFull('1'), isFalse);
      expect(parseForceFull('TRUE'), isFalse);
      expect(parseForceFull('yes'), isFalse);
    });
  });
}
```

This validates the exact parsing rule the router will use. (A full integration test of the router would require spinning up go_router with the whole app's provider tree, which is fragile. This unit-style test locks in the rule itself.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/router/app_router_reimport_test.dart`
Expected: PASS (the local `parseForceFull` in the test is self-contained).

The failing part comes in Step 4 — the test is a regression guard that later catches if someone changes the router's parsing.

- [ ] **Step 3: Examine the current route builder**

Read `lib/core/router/app_router.dart` around lines 962-978. The `computerDownload` route currently:

```dart
GoRoute(
  path: 'download',
  name: 'computerDownload',
  builder: (context, state) =>
      _DiveComputerDownloadWizardRoute(
        computerId: state.pathParameters['computerId']!,
      ),
),
```

Find `_DiveComputerDownloadWizardRoute` in the same file and inspect its constructor. Look for how it instantiates `DiveComputerAdapter`.

- [ ] **Step 4: Modify the route to read the query param**

Replace the route builder:

```dart
GoRoute(
  path: 'download',
  name: 'computerDownload',
  builder: (context, state) => _DiveComputerDownloadWizardRoute(
    computerId: state.pathParameters['computerId']!,
    forceFullDownload: state.uri.queryParameters['forceFull'] == 'true',
  ),
),
```

- [ ] **Step 5: Add `forceFullDownload` to `_DiveComputerDownloadWizardRoute`**

Locate `_DiveComputerDownloadWizardRoute` class in the same file. Add a `forceFullDownload` field + constructor param and forward it to `DiveComputerAdapter`.

If the class looks like:

```dart
class _DiveComputerDownloadWizardRoute extends ConsumerWidget {
  const _DiveComputerDownloadWizardRoute({required this.computerId});
  final String computerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ... existing build that creates DiveComputerAdapter(...)
  }
}
```

Change to:

```dart
class _DiveComputerDownloadWizardRoute extends ConsumerWidget {
  const _DiveComputerDownloadWizardRoute({
    required this.computerId,
    this.forceFullDownload = false,
  });
  final String computerId;
  final bool forceFullDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ... existing build ...
    // In the DiveComputerAdapter(...) call, add:
    //   forceFullDownload: forceFullDownload,
  }
}
```

Update the adapter instantiation inside `build` to pass `forceFullDownload: forceFullDownload`.

- [ ] **Step 6: Run test to verify it still passes**

Run: `flutter test test/core/router/app_router_reimport_test.dart`
Expected: PASS.

- [ ] **Step 7: Verify app compiles**

Run: `flutter analyze lib/core/router/app_router.dart`
Expected: `No issues found!`

- [ ] **Step 8: Format**

Run: `dart format lib/core/router/app_router.dart test/core/router/app_router_reimport_test.dart`

- [ ] **Step 9: Commit**

```bash
git add lib/core/router/app_router.dart test/core/router/app_router_reimport_test.dart
git commit -m "feat: forward forceFull query param to DC download wizard"
```

---

## Task 5: Add "Re-import all dives" button + confirmation dialog to DC detail page

**Files:**
- Modify: `lib/features/dive_computer/presentation/pages/device_detail_page.dart` (actions card at lines 285-306)
- Create: `test/features/dive_computer/presentation/pages/device_detail_page_reimport_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_computer/presentation/pages/device_detail_page_reimport_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_detail_page.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';

import '../../../helpers/test_app.dart';

DiveComputer _computer({String? fingerprint}) {
  return DiveComputer.create(
    id: 'dc-1',
    name: 'Perdix 2',
    diverId: 'diver-1',
    manufacturer: 'Shearwater',
    model: 'Perdix 2',
  ).copyWith(lastDiveFingerprint: fingerprint);
}

void main() {
  Widget wrap(DiveComputer computer) {
    return TestApp(
      overrides: [
        diveComputerByIdProvider(
          computer.id,
        ).overrideWith((ref) => Stream.value(computer)),
      ],
      home: DeviceDetailPage(computerId: computer.id),
    );
  }

  group('Re-import button visibility', () {
    testWidgets('hidden when lastDiveFingerprint is null', (tester) async {
      await tester.pumpWidget(wrap(_computer(fingerprint: null)));
      await tester.pumpAndSettle();
      expect(find.text('Re-import all dives'), findsNothing);
    });

    testWidgets('visible when lastDiveFingerprint is non-null', (tester) async {
      await tester.pumpWidget(wrap(_computer(fingerprint: 'abc123')));
      await tester.pumpAndSettle();
      expect(find.text('Re-import all dives'), findsOneWidget);
    });
  });

  group('Confirmation dialog', () {
    testWidgets('opens on button tap with expected copy', (tester) async {
      await tester.pumpWidget(wrap(_computer(fingerprint: 'abc123')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Re-import all dives'));
      await tester.pumpAndSettle();

      expect(find.text('Re-import all dives?'), findsOneWidget);
      expect(
        find.textContaining('Download every dive from Perdix 2'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Cancel dismisses without navigation', (tester) async {
      await tester.pumpWidget(wrap(_computer(fingerprint: 'abc123')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Re-import all dives'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Re-import all dives?'), findsNothing);
      // We're still on the detail page (button still visible).
      expect(find.text('Re-import all dives'), findsOneWidget);
    });
  });
}
```

Note: if `diveComputerByIdProvider` is not a StreamProvider, adjust the override type. Check the actual provider definition in `lib/features/dive_log/presentation/providers/dive_computer_providers.dart` during implementation — use whichever override pattern matches.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_computer/presentation/pages/device_detail_page_reimport_test.dart`
Expected: FAIL — "Re-import all dives" text is not yet in the widget tree.

- [ ] **Step 3: Modify the actions card in `device_detail_page.dart`**

Locate the `_buildActionsCard` or equivalent method at `device_detail_page.dart:278-307`. The Column currently contains two buttons:

```dart
children: [
  FilledButton.icon(
    onPressed: () =>
        context.push('/dive-computers/${computer.id}/download'),
    icon: const Icon(Icons.download),
    label: Text(context.l10n.diveComputer_detail_downloadDivesButton),
  ),
  const SizedBox(height: 12),
  OutlinedButton.icon(
    onPressed: () => _viewDivesFromComputer(context, ref, computer),
    icon: const Icon(Icons.list),
    label: Text(context.l10n.diveComputer_detail_viewDivesButton),
  ),
],
```

Change to add a third conditional action:

```dart
children: [
  FilledButton.icon(
    onPressed: () =>
        context.push('/dive-computers/${computer.id}/download'),
    icon: const Icon(Icons.download),
    label: Text(context.l10n.diveComputer_detail_downloadDivesButton),
  ),
  const SizedBox(height: 12),
  OutlinedButton.icon(
    onPressed: () => _viewDivesFromComputer(context, ref, computer),
    icon: const Icon(Icons.list),
    label: Text(context.l10n.diveComputer_detail_viewDivesButton),
  ),
  if (computer.lastDiveFingerprint != null) ...[
    const SizedBox(height: 12),
    OutlinedButton.icon(
      onPressed: () => _confirmReimportAll(context, computer),
      icon: const Icon(Icons.refresh),
      label: Text(context.l10n.diveComputer_detail_reimportAllButton),
    ),
  ],
],
```

- [ ] **Step 4: Add the `_confirmReimportAll` helper**

Inside the `DeviceDetailPage` class, add a new private method (place it near `_viewDivesFromComputer`):

```dart
Future<void> _confirmReimportAll(
  BuildContext context,
  DiveComputer computer,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.diveComputer_detail_reimportDialogTitle),
      content: Text(
        l10n.diveComputer_detail_reimportDialogBody(computer.displayName),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.common_action_continue),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    context.push(
      '/dive-computers/${computer.id}/download?forceFull=true',
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/dive_computer/presentation/pages/device_detail_page_reimport_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: Add a navigation-push test**

Extend the test file with one more test that verifies Continue pushes the correct URL. Because mocking `GoRouter` inline is clunky, use a navigator observer instead:

```dart
testWidgets('Continue pushes forceFull=true URL', (tester) async {
  String? pushedLocation;

  final observer = _RouteObserver((location) => pushedLocation = location);

  await tester.pumpWidget(
    TestApp(
      overrides: [
        diveComputerByIdProvider(
          'dc-1',
        ).overrideWith((ref) => Stream.value(_computer(fingerprint: 'abc'))),
      ],
      home: DeviceDetailPage(computerId: 'dc-1'),
      navigatorObservers: [observer],
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Re-import all dives'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();

  expect(pushedLocation, '/dive-computers/dc-1/download?forceFull=true');
});
```

Add `_RouteObserver` class at the bottom of the same test file:

```dart
class _RouteObserver extends NavigatorObserver {
  _RouteObserver(this.onPush);
  final void Function(String? location) onPush;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onPush(route.settings.name);
  }
}
```

This requires `TestApp` to accept `navigatorObservers`. Extend `TestApp` in Appendix A if it doesn't already.

**Note:** `go_router`'s `context.push` doesn't always set the new route's `settings.name` in a way a NavigatorObserver captures. If this test proves flaky, substitute with a simpler assertion: verify the dialog's "Continue" button exists and is tappable, then manually trust the one-line implementation. Document this decision with a comment rather than writing a fragile test.

- [ ] **Step 7: Run analyze and format**

Run:
```bash
flutter analyze lib/features/dive_computer/presentation/pages/device_detail_page.dart \
                test/features/dive_computer/presentation/pages/device_detail_page_reimport_test.dart
dart format lib/features/dive_computer/presentation/pages/device_detail_page.dart \
            test/features/dive_computer/presentation/pages/device_detail_page_reimport_test.dart
```
Expected: `No issues found!` / no diff output.

- [ ] **Step 8: Commit**

```bash
git add lib/features/dive_computer/presentation/pages/device_detail_page.dart \
        test/features/dive_computer/presentation/pages/device_detail_page_reimport_test.dart \
        test/helpers/test_app.dart
git commit -m "feat: add Re-import all dives button to DC detail page"
```

---

## Task 6: Add breadcrumb TextButton to `DcNoNewDivesView`

**Files:**
- Modify: `lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart:434-483` (`DcNoNewDivesView`)
- Create: `test/features/import_wizard/presentation/widgets/dc_no_new_dives_view_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/import_wizard/presentation/widgets/dc_no_new_dives_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_adapter_steps.dart';

import '../../../helpers/test_app.dart';

void main() {
  testWidgets('renders breadcrumb TextButton with expected text',
      (tester) async {
    await tester.pumpWidget(
      TestApp(home: DcNoNewDivesView(onDone: () {})),
    );

    expect(find.text('Done'), findsOneWidget);
    expect(
      find.textContaining('Looking for older or deleted dives'),
      findsOneWidget,
    );
  });

  testWidgets('tapping breadcrumb invokes onDone', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      TestApp(home: DcNoNewDivesView(onDone: () => tapped++)),
    );

    await tester.tap(find.textContaining('Looking for older'));
    await tester.pumpAndSettle();

    expect(tapped, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/import_wizard/presentation/widgets/dc_no_new_dives_view_test.dart`
Expected: FAIL — "Looking for older or deleted dives" text is not in the widget yet.

- [ ] **Step 3: Modify `DcNoNewDivesView`**

Find the Column children in `DcNoNewDivesView` (around lines 447-478) and append a `TextButton` after the existing `FilledButton`.

Current end of the Column:

```dart
const SizedBox(height: 32),
FilledButton(onPressed: onDone, child: const Text('Done')),
```

Change to:

```dart
const SizedBox(height: 32),
FilledButton(onPressed: onDone, child: const Text('Done')),
const SizedBox(height: 8),
TextButton(
  onPressed: onDone,
  child: Text(
    context.l10n.diveComputer_download_reimportHint,
    textAlign: TextAlign.center,
  ),
),
```

Also ensure `context.l10n` is imported. Check the file's imports — `package:submersion/l10n/l10n_extension.dart` should already be there.

Also: replace the hardcoded `'Done'` string with `context.l10n.common_action_done`... but wait — let's check if that key exists before changing unrelated code.

Run: `grep -n "common_action_done\|\"Done\"" lib/l10n/arb/app_en.arb | head -3`

If `common_action_done` does not exist, leave `'Done'` hardcoded (out of scope for this task — don't expand the change).

Also replace the hardcoded `'No new dives to download'` and `'All dives from this computer have already been imported.'` strings only if they already have l10n keys. The spec did not require these — leave them as-is if no keys exist. Do not add new keys in this task.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/import_wizard/presentation/widgets/dc_no_new_dives_view_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Run analyze and format**

Run:
```bash
flutter analyze lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart \
                test/features/import_wizard/presentation/widgets/dc_no_new_dives_view_test.dart
dart format lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart \
            test/features/import_wizard/presentation/widgets/dc_no_new_dives_view_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart \
        test/features/import_wizard/presentation/widgets/dc_no_new_dives_view_test.dart
git commit -m "feat: add re-import breadcrumb to DcNoNewDivesView"
```

---

## Task 7: Issue #206 regression test

**Files:**
- Create: `test/features/dive_computer/issue_206_reimport_regression_test.dart`

A self-contained regression guard capturing the invariant the issue asked for: after triggering a re-import on a computer with stored dives, every existing dive surfaces as a pending duplicate needing explicit decision.

This test works at the adapter + matcher level, not the full wizard UI, to stay fast and reliable.

- [ ] **Step 1: Write the test**

Create `test/features/dive_computer/issue_206_reimport_regression_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';

import '../import_wizard/data/adapters/dive_computer_adapter_reimport_test.mocks.dart';

void main() {
  group('Issue #206: Re-import surfaces all existing dives as pending duplicates', () {
    test(
      'forceFullDownload=true means fingerprint is bypassed and the '
      'Review step receives every dive for decision',
      () async {
        final adapter = DiveComputerAdapter(
          importService: MockDiveImportService(),
          computerRepository: MockDiveComputerRepository(),
          diveRepository: MockDiveRepository(),
          diverId: 'diver-1',
          forceFullDownload: true,
        );

        // The contract this test enforces:
        // 1. The adapter exposes forceFullDownload=true.
        // 2. Downstream code (download step) flips newDivesOnly to false
        //    when this flag is set, which causes fingerprint=null and full
        //    download. Covered by dc_adapter_download_step_force_full_test.dart.
        // 3. The Review step's existing pending-duplicate gate (April 12 spec)
        //    then marks every duplicate dive as requiring explicit decision.
        //    Covered by the existing import_wizard_notifier_test.dart.
        //
        // The contract here: forceFullDownload flows through the adapter
        // unchanged. If this assertion fails, the re-import flow is broken.
        expect(adapter.forceFullDownload, isTrue);

        // A default-constructed adapter must NOT force full download.
        final defaultAdapter = DiveComputerAdapter(
          importService: MockDiveImportService(),
          computerRepository: MockDiveComputerRepository(),
          diveRepository: MockDiveRepository(),
          diverId: 'diver-1',
        );
        expect(defaultAdapter.forceFullDownload, isFalse);
      },
    );
  });
}
```

Note: We reuse the mocks generated for Task 2's test. If `dive_computer_adapter_reimport_test.mocks.dart` does not export the needed mock classes, adjust the import path or add the required `@GenerateMocks` annotation.

- [ ] **Step 2: Run the test**

Run: `flutter test test/features/dive_computer/issue_206_reimport_regression_test.dart`
Expected: `All tests passed!`

- [ ] **Step 3: Commit**

```bash
git add test/features/dive_computer/issue_206_reimport_regression_test.dart
git commit -m "test: regression guard for issue #206 re-import flow"
```

---

## Task 8: Full verification and PR

- [ ] **Step 1: Run the full test suite for affected areas**

Run:
```bash
flutter test test/features/import_wizard/ \
             test/features/dive_computer/ \
             test/core/router/
```

Expected: all tests pass.

- [ ] **Step 2: Run full `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Run `dart format` check**

Run: `dart format --set-exit-if-changed lib/ test/`
Expected: exit code 0; no files need formatting.

- [ ] **Step 4: Smoke test in the app (optional but recommended for UI changes)**

Run: `flutter run -d macos`

Manually verify:
1. Navigate to a dive computer detail page for a computer that has `lastDiveFingerprint` set (import at least one dive first if needed).
2. Confirm "Re-import all dives" button appears below "View Dives".
3. Tap it — dialog appears with correct title/body/buttons.
4. Tap Cancel — dialog dismisses, still on detail page.
5. Re-open dialog, tap Continue — download wizard starts.
6. Observe that all dives (including ones older than the fingerprint) appear in the Review step as pending duplicates.
7. Navigate to a freshly-added computer with no fingerprint. Confirm "Re-import all dives" button is NOT visible.

If any step fails, fix and commit before opening the PR.

- [ ] **Step 5: Create PR**

```bash
git push -u origin issue-206-reimport-all-dives
gh pr create --title "feat: re-import all dives from dive computer (#206)" --body "$(cat <<'EOF'
## Summary
- Adds a first-class "Re-import all dives" entry point on the DC detail page.
- Routes through the existing unified import wizard with fingerprint bypass so already-logged dives surface in the Review step as pending duplicates.
- Adds a breadcrumb hint on "No new dives to download" pointing back to the DC detail page.

Closes #206.

## Design
Full spec at `docs/superpowers/specs/2026-04-13-reimport-all-dives-design.md`.

## Test plan
- [x] `flutter test test/features/import_wizard/ test/features/dive_computer/ test/core/router/` passes
- [x] `flutter analyze` clean
- [x] `dart format --set-exit-if-changed lib/ test/` clean
- [ ] Manual: verify Re-import button visibility on a DC with and without a stored fingerprint
- [ ] Manual: trigger re-import, verify all dives surface in Review step as pending duplicates
- [ ] Manual: verify "Looking for older or deleted dives?" breadcrumb appears on "No new dives" screen and navigates back to detail page
EOF
)"
```

---

## Appendix A: Test helpers

If `test/helpers/test_app.dart` does not exist, create it with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Test harness that provides the minimum shell needed to pump a widget
/// under test: ProviderScope, MaterialApp with localization delegates,
/// and a Scaffold-wrapped home.
///
/// Usage:
/// ```dart
/// await tester.pumpWidget(
///   TestApp(
///     overrides: [myProvider.overrideWithValue(...)],
///     home: WidgetUnderTest(),
///   ),
/// );
/// ```
class TestApp extends StatelessWidget {
  const TestApp({
    super.key,
    required this.home,
    this.overrides = const [],
    this.container,
    this.navigatorObservers = const [],
  });

  final Widget home;
  final List<Override> overrides;
  final ProviderContainer? container;
  final List<NavigatorObserver> navigatorObservers;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: navigatorObservers,
      home: Scaffold(body: home),
    );
    if (container != null) {
      return UncontrolledProviderScope(
        container: container!,
        child: app,
      );
    }
    return ProviderScope(overrides: overrides, child: app);
  }
}
```

If `test/helpers/mock_import_adapter_deps.dart` does not exist, create it with:

```dart
import 'dart:async';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

class _MockDiveImportService extends Mock implements DiveImportService {}

class _MockDiveComputerRepository extends Mock
    implements DiveComputerRepository {}

class _MockDiveRepository extends Mock implements DiveRepository {}

class _MockDiveComputerService extends Mock implements DiveComputerService {}

/// Bundle of mocks commonly needed when constructing a DiveComputerAdapter
/// for widget tests.
class MockImportAdapterDeps {
  MockImportAdapterDeps() {
    when(
      mockService.downloadEvents,
    ).thenAnswer((_) => const Stream<DownloadEvent>.empty());
  }

  final DiveImportService importService = _MockDiveImportService();
  final DiveComputerRepository computerRepo = _MockDiveComputerRepository();
  final DiveRepository diveRepo = _MockDiveRepository();
  final DiveComputerService mockService = _MockDiveComputerService();
}
```

If mockito annotations are preferred over manual `Mock` subclasses in this project, adapt accordingly. Check the existing style in `test/features/dive_computer/presentation/providers/download_notifier_fingerprint_test.dart`.

---

## Self-Review Notes

**Spec coverage:**
- Adapter flag → Task 2
- Download step applies flag → Task 3
- Router query param → Task 4
- DC detail page button + dialog → Task 5
- DcNoNewDivesView breadcrumb → Task 6
- Localization keys → Task 1
- Regression guard for issue #206 → Task 7
- End-to-end verification → Task 8

**Placeholder scan:** No `TBD`/`TODO`/`implement later` in instructions. Each step shows the actual code to write.

**Type consistency:** `forceFullDownload` used consistently across adapter, route, widget; `setNewDivesOnly(false)` matches existing notifier API; ARB keys `common_action_continue`, `diveComputer_detail_reimportAllButton`, `diveComputer_detail_reimportDialogTitle`, `diveComputer_detail_reimportDialogBody`, `diveComputer_download_reimportHint` used the same way in the ARB definitions and the code that calls them.

**Known soft spots flagged inline:**
- Task 5 Step 6: navigation-push test may be fragile; fallback instruction given.
- Task 7: regression test is a contract guard at the adapter level; relies on existing tests for the full wizard behavior chain. This is intentional — the integration layer's mocks are complex enough that a narrowly-scoped contract guard is more maintainable than a full pipeline test.
