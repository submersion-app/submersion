# Maintenance History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the equipment service history say which maintenance task was completed, let it be filtered, let a default price be carried on the task and interval, and let the whole log be exported to Excel.

**Architecture:** Four phases against the existing service ledger. Phase 1 fixes the display by resolving `ServiceRecord.serviceKindId` to a `ServiceKind` name and localizing the `ServiceType` enum, while extracting the history region out of a 1596 line page. Phase 2 adds a presentation-layer filter. Phase 3 adds two nullable columns to `service_kinds` and `service_schedules` behind migration v157, with a pure resolver deciding the prefill. Phase 4 adds an Excel sheet builder used by three surfaces.

**Tech Stack:** Flutter, Drift ORM (SQLite), Riverpod, `excel_community`, `intl`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-18-maintenance-history-design.md`

## Global Constraints

- **No em-dashes (U+2014) in any output**: code, comments, docstrings, commit messages, markdown, ARB strings. Absolute, no exceptions. En-dashes used as sentence punctuation and spaced hyphens as prose punctuation are equally forbidden. Hyphens inside compound words and CLI flags are fine.
- **No emojis** in code, comments, or documentation.
- **`dart format .` must leave no changes.** Run it after every task before committing.
- **Every new user-visible string needs all 11 ARB files** in `lib/l10n/arb/`: `app_ar`, `app_de`, `app_en`, `app_es`, `app_fr`, `app_he`, `app_hu`, `app_it`, `app_nl`, `app_pt`, `app_zh`. Translate, do not copy English into the other ten.
- **After editing any ARB file, run `flutter gen-l10n`** to regenerate `lib/l10n/arb/app_localizations*.dart`, which are checked in.
- **File size:** 200-400 lines typical, 800 maximum.
- **TDD:** write the failing test first, watch it fail, then implement.
- **Locale-aware numerics:** any numeric text field must pair `formatDecimalForInput` (seed) with `parseUserDecimal` (read back). `toString()` seeds `"12.5"` in a locale where `.` is a thousands separator.
- **Schema version:** this plan assumes **v157**. It was written against v154; main then took 156 (#1104) and 155 (#828), so the migration renumbered to 156 at merge time. Always re-check `currentSchemaVersion` on current `origin/main` plus open PR claims before writing a migration.
- **Test commands:** `flutter test <path>` for one file, `flutter analyze` for lints. Do not overlap local test runs; a second concurrent run produces phantom failures.

## Phase to commit mapping

| Phase | Tasks | Commit |
| --- | --- | --- |
| 1. History legibility | 1, 2, 3 | `feat(equipment): name the maintenance task in service history (#829)` |
| 2. Filter | 4, 5 | `feat(equipment): filter maintenance history by task, type and year (#829)` |
| 3. Default price | 6, 7, 8, 9 | `feat(equipment): default service price on kind and schedule (#829)` |
| 4. Excel log | 10, 11 | `feat(export): Excel maintenance log (#829)` |

Tasks inside a phase each commit individually so every step has a green test gate. Squash within a phase at merge if a tighter history is wanted.

## File Structure

**Created:**

| File | Responsibility |
| --- | --- |
| `lib/features/equipment/presentation/utils/service_type_label.dart` | `ServiceType` to localized string |
| `lib/features/equipment/presentation/widgets/service_history_section.dart` | History card: header, totals, filter bar, record rows |
| `lib/features/equipment/presentation/widgets/service_record_dialog.dart` | Add/edit record dialog (moved) |
| `lib/features/equipment/domain/entities/maintenance_history_filter.dart` | Filter value object with `matches` |
| `lib/features/equipment/domain/services/default_service_cost_resolver.dart` | Pure schedule-then-kind cost resolution |
| `lib/core/services/export/excel/maintenance_excel_export_service.dart` | Maintenance Log sheet, share and save |

**Modified:** `lib/core/constants/enums.dart` (unchanged, referenced only), `lib/core/database/database.dart`, both service entities, both service repositories, `service_kind_list_page.dart`, `service_schedule_dialogs.dart`, `equipment_detail_page.dart`, `excel_export_service.dart`, `export_service.dart`, `export_providers.dart`, `transfer_page.dart`, 11 ARB files.

---

## Task 1: Localize ServiceType

`ServiceType.displayName` (`lib/core/constants/enums.dart:240-254`) is hardcoded English and reaches users in 11 locales. It is used in exactly three UI places. `displayName` and `.name` stay untouched, because export headers and persisted values must remain English and stable.

**Files:**
- Create: `lib/features/equipment/presentation/utils/service_type_label.dart`
- Create: `test/features/equipment/presentation/utils/service_type_label_test.dart`
- Modify: `lib/l10n/arb/app_en.arb` and the other 10 ARB files

**Interfaces:**
- Consumes: nothing.
- Produces: `extension ServiceTypeL10n on ServiceType { String label(AppLocalizations l10n); }`, used by Tasks 3, 5 and 10.

- [ ] **Step 1: Add the 10 English keys to `lib/l10n/arb/app_en.arb`**

Insert next to the existing `equipment_serviceDialog_*` block (around line 6075). ARB files are JSON, so mind the commas.

```json
  "equipment_serviceType_annual": "Annual Service",
  "equipment_serviceType_repair": "Repair",
  "equipment_serviceType_inspection": "Inspection",
  "equipment_serviceType_overhaul": "Overhaul",
  "equipment_serviceType_replacement": "Part Replacement",
  "equipment_serviceType_cleaning": "Cleaning",
  "equipment_serviceType_calibration": "Calibration",
  "equipment_serviceType_warranty": "Warranty Service",
  "equipment_serviceType_recall": "Recall/Safety",
  "equipment_serviceType_other": "Other",
```

- [ ] **Step 2: Add the same 10 keys, translated, to the other 10 ARB files**

German values for `app_de.arb`, as the worked example (the reporter runs a German build):

```json
  "equipment_serviceType_annual": "Jahresservice",
  "equipment_serviceType_repair": "Reparatur",
  "equipment_serviceType_inspection": "Inspektion",
  "equipment_serviceType_overhaul": "Überholung",
  "equipment_serviceType_replacement": "Teiletausch",
  "equipment_serviceType_cleaning": "Reinigung",
  "equipment_serviceType_calibration": "Kalibrierung",
  "equipment_serviceType_warranty": "Garantieservice",
  "equipment_serviceType_recall": "Rückruf/Sicherheit",
  "equipment_serviceType_other": "Sonstiges",
```

Translate for `app_ar`, `app_es`, `app_fr`, `app_he`, `app_hu`, `app_it`, `app_nl`, `app_pt`, `app_zh` in the same way.

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: `lib/l10n/arb/app_localizations*.dart` updated, no errors.

- [ ] **Step 4: Write the failing test**

Create `test/features/equipment/presentation/utils/service_type_label_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/presentation/utils/service_type_label.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('every ServiceType has a non-empty English label', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    for (final type in ServiceType.values) {
      expect(type.label(l10n), isNotEmpty, reason: 'missing label for $type');
    }
  });

  test('German labels differ from the hardcoded English displayName', () async {
    final de = await AppLocalizations.delegate.load(const Locale('de'));
    expect(ServiceType.cleaning.label(de), 'Reinigung');
    expect(ServiceType.cleaning.label(de),
        isNot(ServiceType.cleaning.displayName));
  });
}
```

- [ ] **Step 5: Run the test to verify it fails**

Run: `flutter test test/features/equipment/presentation/utils/service_type_label_test.dart`
Expected: FAIL, `Target of URI doesn't exist: '.../service_type_label.dart'`.

- [ ] **Step 6: Write the extension**

Create `lib/features/equipment/presentation/utils/service_type_label.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized labels for [ServiceType].
///
/// [ServiceType.displayName] stays hardcoded English on purpose: it is the
/// value written to spreadsheet exports, which are analysis targets rather
/// than UI surfaces. Only screens use this extension.
extension ServiceTypeL10n on ServiceType {
  String label(AppLocalizations l10n) => switch (this) {
    ServiceType.annual => l10n.equipment_serviceType_annual,
    ServiceType.repair => l10n.equipment_serviceType_repair,
    ServiceType.inspection => l10n.equipment_serviceType_inspection,
    ServiceType.overhaul => l10n.equipment_serviceType_overhaul,
    ServiceType.replacement => l10n.equipment_serviceType_replacement,
    ServiceType.cleaning => l10n.equipment_serviceType_cleaning,
    ServiceType.calibration => l10n.equipment_serviceType_calibration,
    ServiceType.warranty => l10n.equipment_serviceType_warranty,
    ServiceType.recall => l10n.equipment_serviceType_recall,
    ServiceType.other => l10n.equipment_serviceType_other,
  };
}
```

The exhaustive `switch` expression means adding an enum value later is a compile error rather than a silent English fallback.

- [ ] **Step 7: Run the test to verify it passes**

Run: `flutter test test/features/equipment/presentation/utils/service_type_label_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/equipment/presentation/utils/service_type_label.dart \
        test/features/equipment/presentation/utils/service_type_label_test.dart \
        lib/l10n/arb/
git commit -m "feat(equipment): localize ServiceType labels (#829)"
```

---

## Task 2: Extract the history section and dialog into their own files

Pure move, no behavior change. `equipment_detail_page.dart` is 1596 lines against an 800 line ceiling, and Tasks 3, 5 and 11 all add code to this region.

**Files:**
- Create: `lib/features/equipment/presentation/widgets/service_history_section.dart`
- Create: `lib/features/equipment/presentation/widgets/service_record_dialog.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart:823-1594` (delete), `:174` (call site)
- Modify: `test/features/equipment/presentation/pages/service_record_dialog_kind_test.dart` (import)

**Interfaces:**
- Consumes: nothing.
- Produces: `class ServiceHistorySection extends ConsumerWidget { const ServiceHistorySection({super.key, required String equipmentId}); }` and `class ServiceRecordDialog extends ConsumerStatefulWidget` at its new path. Tasks 3, 5 and 11 modify these files.

- [ ] **Step 1: Move `_ServiceHistorySection` and `_ServiceRecordTile`**

Cut `equipment_detail_page.dart:823-1163` into `service_history_section.dart`. Rename `_ServiceHistorySection` to public `ServiceHistorySection` (it now crosses a file boundary) and give it a `super.key`. Keep `_ServiceRecordTile` private. Carry over the imports the moved code uses: `package:flutter/material.dart`, `package:flutter_riverpod/flutter_riverpod.dart`, `package:submersion/core/utils/currency.dart`, `package:submersion/core/utils/unit_formatter.dart`, `package:submersion/l10n/l10n_extension.dart`, the equipment providers, the settings providers, `service_record.dart`, and `enums.dart`.

- [ ] **Step 2: Move `ServiceRecordDialog`**

Cut `equipment_detail_page.dart:1165-1594` into `service_record_dialog.dart`. It is already public. It needs `package:submersion/core/utils/number_input.dart` for `formatDecimalForInput` and `parseUserDecimal`, plus `currency.dart` and the date picker helper.

- [ ] **Step 3: Update the call sites**

In `equipment_detail_page.dart`, import both new files and change line 174:

```dart
ServiceHistorySection(equipmentId: equipmentId),
```

`_showAddServiceDialogForKind` (`:634-660`) also constructs `ServiceRecordDialog` and now resolves it through the new import.

- [ ] **Step 4: Update the dialog test import**

In `test/features/equipment/presentation/pages/service_record_dialog_kind_test.dart`, replace the `equipment_detail_page.dart` import with:

```dart
import 'package:submersion/features/equipment/presentation/widgets/service_record_dialog.dart';
```

- [ ] **Step 5: Verify nothing changed behaviorally**

Run: `flutter test test/features/equipment/`
Expected: PASS. Every pre-existing equipment test must stay green; this task changes no behavior.

- [ ] **Step 6: Confirm the page shrank**

Run: `wc -l lib/features/equipment/presentation/pages/equipment_detail_page.dart`
Expected: roughly 830 lines, down from 1596.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/equipment/presentation/ test/features/equipment/
git commit -m "refactor(equipment): extract service history section and dialog (#829)"
```

---

## Task 3: Name the task in the row, and stop starving the title

Two changes that must land together. The row title becomes the `ServiceKind` name, and cost moves out of `ListTile.trailing`.

`_RenderListTile` lays `trailing` out against the full tile width first and gives the title what remains, clamped at zero, so a text bearing trailing widget starves the title. Flutter's guard is behind an `assert`, so release builds degrade silently to one glyph per line. This is the issue #935 class swept in PR #1026; this tile was missed. Replacing a short English title with a long user authored kind name would make it visibly worse.

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/service_history_section.dart`
- Create: `test/features/equipment/presentation/widgets/service_history_section_test.dart`
- Modify: `lib/l10n/arb/*.arb` (one new key)

**Interfaces:**
- Consumes: `ServiceTypeL10n.label` from Task 1; `ServiceHistorySection` from Task 2.
- Produces: `_ServiceRecordTile` gains a `List<ServiceKind> kinds` parameter. Task 5 passes the filtered record list to the same widget.

- [ ] **Step 1: Add the next-due label key to all 11 ARB files**

English:

```json
  "equipment_service_nextDueLabel": "Next due {date}",
  "@equipment_service_nextDueLabel": {
    "placeholders": { "date": { "type": "String" } }
  },
```

German: `"Nächste Fälligkeit {date}"`. Translate for the other nine. Then run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

Create `test/features/equipment/presentation/widgets/service_history_section_test.dart`. Build the widget under a `ProviderScope` with `serviceKindsProvider` and `serviceRecordNotifierProvider` overridden, following the setup already used in `test/features/equipment/presentation/pages/equipment_detail_service_test.dart`.

```dart
testWidgets('row titles with the maintenance task name', (tester) async {
  // record with serviceKindId: 'scrubber-repack', serviceType: cleaning
  await tester.pumpWidget(harness());
  await tester.pumpAndSettle();

  expect(find.text('Scrubber repack'), findsOneWidget);
});

testWidgets('row falls back to the localized type when untagged',
    (tester) async {
  // record with serviceKindId: null, serviceType: cleaning
  await tester.pumpWidget(harness(locale: const Locale('de')));
  await tester.pumpAndSettle();

  expect(find.text('Reinigung'), findsOneWidget);
});

testWidgets('row renders notes and next due', (tester) async {
  await tester.pumpWidget(harness());
  await tester.pumpAndSettle();

  expect(find.textContaining('Rinsed and dried'), findsOneWidget);
  expect(find.textContaining('Next due'), findsOneWidget);
});

testWidgets('a long German task name keeps its title width', (tester) async {
  // Regression for the issue #935 class: a text-bearing ListTile.trailing
  // starves the title to near-zero width, and the guard is assert-only so
  // release builds render one glyph per line instead of throwing.
  const longName = 'Sauerstoffsensor ersetzen und kalibrieren';
  await tester.binding.setSurfaceSize(const Size(360, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(harness(locale: const Locale('de'), kindName: longName));
  await tester.pumpAndSettle();

  expect(tester.getSize(find.text(longName)).width, greaterThan(150));
});
```

The width assertion is the point. `find.text(...)` with `findsOneWidget` passes happily while the text renders vertically, which is exactly how #935 reached a user.

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/presentation/widgets/service_history_section_test.dart`
Expected: FAIL. The title test fails because the row shows the service type; the width test fails because cost is still in `trailing`.

- [ ] **Step 4: Pass the kinds into the tile**

In `ServiceHistorySection.build`, watch the kinds and index them once rather than per row:

```dart
final kindsAsync = ref.watch(serviceKindsProvider);
final kindsById = {
  for (final kind in kindsAsync.valueOrNull ?? const <ServiceKind>[])
    kind.id: kind,
};
```

Pass `kindsById` to each `_ServiceRecordTile`. While kinds are still loading the map is empty and rows fall back to the service type, which is the correct transient state rather than a spinner.

- [ ] **Step 5: Rewrite the tile**

Replace the `title`, `subtitle` and `trailing` of `_ServiceRecordTile`:

```dart
final l10n = context.l10n;
final kindName = kindsById[record.serviceKindId]?.name;
final typeLabel = record.serviceType.label(l10n);
final theme = Theme.of(context);

return ListTile(
  contentPadding: EdgeInsets.zero,
  isThreeLine: true,
  leading: CircleAvatar(
    backgroundColor: theme.colorScheme.primaryContainer,
    child: Icon(
      _getServiceTypeIcon(record.serviceType),
      color: theme.colorScheme.onPrimaryContainer,
      size: 20,
    ),
  ),
  // maxLines + ellipsis is a backstop: if a future change puts a
  // text-bearing widget back in trailing, the title ellipsizes instead
  // of rendering one glyph per line (issue #935).
  title: Text(
    kindName ?? typeLabel,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
  subtitle: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // The type is secondary once the task names the row, but the issue
      // asks for both: the task says which job, the type says what kind.
      Text(
        kindName == null
            ? units.formatDate(record.serviceDate)
            : '$typeLabel · ${units.formatDate(record.serviceDate)}',
        style: theme.textTheme.bodySmall,
      ),
      if (record.provider != null || record.cost != null)
        Text(
          [
            if (record.provider != null) record.provider!,
            if (record.cost != null)
              formatMoney(record.cost!, record.currency),
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
      if (record.nextServiceDue != null)
        Text(
          l10n.equipment_service_nextDueLabel(
            units.formatDate(record.nextServiceDue!),
          ),
          style: theme.textTheme.bodySmall,
        ),
      if (record.notes.isNotEmpty)
        Text(
          record.notes,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
    ],
  ),
  // Only fixed-width widgets belong in trailing.
  trailing: PopupMenuButton<String>(
    onSelected: (value) {
      if (value == 'edit') {
        onTap();
      } else if (value == 'delete') {
        onDelete();
      }
    },
    itemBuilder: (context) => [
      PopupMenuItem(
        value: 'edit',
        child: Text(l10n.equipment_service_editMenuItem),
      ),
      PopupMenuItem(
        value: 'delete',
        child: Text(
          l10n.equipment_service_deleteMenuItem,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    ],
  ),
  onTap: onTap,
);
```

The separator is a literal middle dot, matching `service_clocks_card.dart:74` which already joins its trigger parts with `' · '`.

- [ ] **Step 6: Localize the other two `displayName` call sites**

In the delete confirmation (moved from `equipment_detail_page.dart:1028`), replace `record.serviceType.displayName` with `record.serviceType.label(context.l10n)`. In `service_record_dialog.dart`, replace `Text(type.displayName)` in the dropdown with `Text(type.label(context.l10n))`.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/presentation/widgets/service_history_section_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 8: Run the whole equipment suite**

Run: `flutter test test/features/equipment/`
Expected: PASS. Existing tests asserting on `displayName` strings need updating to the localized label.

- [ ] **Step 9: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/equipment/ test/features/equipment/ lib/l10n/arb/
git commit -m "feat(equipment): name the maintenance task in service history (#829)"
```

---

## Task 4: The filter value object

A pure, widget-free object so the matching rules get unit tests without pumping a widget.

**Files:**
- Create: `lib/features/equipment/domain/entities/maintenance_history_filter.dart`
- Create: `test/features/equipment/domain/entities/maintenance_history_filter_test.dart`

**Interfaces:**
- Consumes: `ServiceRecord`, `ServiceType`.
- Produces: `MaintenanceHistoryFilter` with `serviceKindId`, `serviceType`, `year`, `isActive`, `matches(ServiceRecord)`, `copyWith`, and `const MaintenanceHistoryFilter.untaggedSentinel`. Task 5 consumes all of it.

- [ ] **Step 1: Write the failing test**

Create `test/features/equipment/domain/entities/maintenance_history_filter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/maintenance_history_filter.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';

ServiceRecord record({
  String? kindId,
  ServiceType type = ServiceType.cleaning,
  int year = 2026,
}) {
  final date = DateTime(year, 3, 14);
  return ServiceRecord(
    id: 'r-$kindId-$year-${type.name}',
    equipmentId: 'e1',
    serviceType: type,
    serviceKindId: kindId,
    serviceDate: date,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  test('an empty filter is inactive and matches everything', () {
    const filter = MaintenanceHistoryFilter();
    expect(filter.isActive, isFalse);
    expect(filter.matches(record(kindId: 'disinfect')), isTrue);
    expect(filter.matches(record(kindId: null)), isTrue);
  });

  test('the kind filter selects one task', () {
    const filter = MaintenanceHistoryFilter(serviceKindId: 'disinfect');
    expect(filter.isActive, isTrue);
    expect(filter.matches(record(kindId: 'disinfect')), isTrue);
    expect(filter.matches(record(kindId: 'scrubber-repack')), isFalse);
    expect(filter.matches(record(kindId: null)), isFalse);
  });

  test('the untagged sentinel selects records with no kind', () {
    const filter = MaintenanceHistoryFilter(
      serviceKindId: MaintenanceHistoryFilter.untaggedSentinel,
    );
    expect(filter.matches(record(kindId: null)), isTrue);
    expect(filter.matches(record(kindId: 'disinfect')), isFalse);
  });

  test('type and year filters intersect with the kind filter', () {
    const filter = MaintenanceHistoryFilter(
      serviceKindId: 'disinfect',
      serviceType: ServiceType.cleaning,
      year: 2026,
    );
    expect(
      filter.matches(record(kindId: 'disinfect', year: 2026)),
      isTrue,
    );
    expect(
      filter.matches(record(kindId: 'disinfect', year: 2025)),
      isFalse,
    );
    expect(
      filter.matches(
        record(kindId: 'disinfect', type: ServiceType.repair),
      ),
      isFalse,
    );
  });

  test('copyWith clears a dimension back to null', () {
    const filter = MaintenanceHistoryFilter(serviceKindId: 'disinfect');
    expect(filter.copyWith(serviceKindId: null).serviceKindId, isNull);
    expect(filter.copyWith(serviceKindId: null).isActive, isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/domain/entities/maintenance_history_filter_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the value object**

Create `lib/features/equipment/domain/entities/maintenance_history_filter.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';

/// Narrows one equipment item's service history.
///
/// Filtering happens in the presentation layer over the already loaded
/// per-item record list: the repository already scopes by equipment and these
/// lists are small, so a query-level filter would add a code path without
/// buying anything.
class MaintenanceHistoryFilter extends Equatable {
  /// Selects records whose [ServiceRecord.serviceKindId] is null. A real kind
  /// id can never collide with it, because kind ids are uuids or the built-in
  /// slugs.
  static const untaggedSentinel = '__untagged__';

  final String? serviceKindId;
  final ServiceType? serviceType;
  final int? year;

  const MaintenanceHistoryFilter({
    this.serviceKindId,
    this.serviceType,
    this.year,
  });

  bool get isActive =>
      serviceKindId != null || serviceType != null || year != null;

  bool matches(ServiceRecord record) {
    if (serviceKindId == untaggedSentinel) {
      if (record.serviceKindId != null) return false;
    } else if (serviceKindId != null &&
        record.serviceKindId != serviceKindId) {
      return false;
    }
    if (serviceType != null && record.serviceType != serviceType) return false;
    if (year != null && record.serviceDate.year != year) return false;
    return true;
  }

  /// Every field is nullable and clearable, so each parameter takes the plain
  /// value: passing null means "clear this dimension", which is what the
  /// "All" option in each dropdown does.
  MaintenanceHistoryFilter copyWith({
    String? serviceKindId,
    ServiceType? serviceType,
    int? year,
  }) => MaintenanceHistoryFilter(
    serviceKindId: serviceKindId,
    serviceType: serviceType,
    year: year,
  );

  @override
  List<Object?> get props => [serviceKindId, serviceType, year];
}
```

Note the deliberate difference from `ServiceKind.copyWith`: there the `_undefined` sentinel exists so a field can be cleared *or* left alone. Here clearing is the only thing callers ever want, so plain nullable parameters are correct and simpler. Callers pass every field they want to keep.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/domain/entities/maintenance_history_filter_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/equipment/domain/entities/maintenance_history_filter.dart \
        test/features/equipment/domain/entities/maintenance_history_filter_test.dart
git commit -m "feat(equipment): maintenance history filter model (#829)"
```

---

## Task 5: The filter bar

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/service_history_section.dart`
- Modify: `test/features/equipment/presentation/widgets/service_history_section_test.dart`
- Modify: `lib/l10n/arb/*.arb`

**Interfaces:**
- Consumes: `MaintenanceHistoryFilter` (Task 4), `ServiceTypeL10n.label` (Task 1).
- Produces: `ServiceHistorySection` becomes a `ConsumerStatefulWidget` holding `MaintenanceHistoryFilter _filter`. Task 11 reads the same filtered list for the item-level export.

- [ ] **Step 1: Add the filter keys to all 11 ARB files**

English:

```json
  "equipment_service_filterTaskAll": "All tasks",
  "equipment_service_filterTypeAll": "All types",
  "equipment_service_filterYearAll": "All years",
  "equipment_service_filterUntagged": "Not tied to a clock",
  "equipment_service_filterClear": "Clear filter",
  "equipment_service_filterNoMatches": "No maintenance matches this filter",
```

German: `"Alle Aufgaben"`, `"Alle Typen"`, `"Alle Jahre"`, `"Keinem Intervall zugeordnet"`, `"Filter zurücksetzen"`, `"Keine Wartung entspricht diesem Filter"`. Translate for the other nine, then run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

Add to `test/features/equipment/presentation/widgets/service_history_section_test.dart`:

```dart
testWidgets('selecting a task narrows the list', (tester) async {
  // Seed two records: one 'Disinfect', one 'Scrubber repack'.
  await tester.pumpWidget(harness());
  await tester.pumpAndSettle();

  expect(find.text('Disinfect'), findsOneWidget);
  expect(find.text('Scrubber repack'), findsOneWidget);

  await tester.tap(find.text('All tasks'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Disinfect').last);
  await tester.pumpAndSettle();

  expect(find.text('Scrubber repack'), findsNothing);
});

testWidgets('a filter matching nothing shows its own empty state',
    (tester) async {
  await tester.pumpWidget(harness());
  await tester.pumpAndSettle();

  await tester.tap(find.text('All years'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('2019').last);
  await tester.pumpAndSettle();

  expect(find.text('No maintenance matches this filter'), findsOneWidget);
  // Distinct from the "no records at all" state.
  expect(find.text('No service records yet'), findsNothing);
});

testWidgets('the filter bar is hidden when there is nothing to filter',
    (tester) async {
  // Single record, single task, single year.
  await tester.pumpWidget(harness(singleRecord: true));
  await tester.pumpAndSettle();

  expect(find.text('All tasks'), findsNothing);
});
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/presentation/widgets/service_history_section_test.dart`
Expected: FAIL, the dropdowns do not exist.

- [ ] **Step 4: Convert the section to stateful and derive the options**

Change `ServiceHistorySection` to `ConsumerStatefulWidget` with `MaintenanceHistoryFilter _filter = const MaintenanceHistoryFilter();`. Local state is right here: the filter does not need to outlive the page, matching `equipment_list_content.dart:636-696`.

Derive each dropdown's options from the records actually present, so there are no dead options:

```dart
/// Options come from the records themselves, so a diver never sees a task
/// they have never logged, and every option yields at least one row.
List<String?> _taskOptions(List<ServiceRecord> records) {
  final ids = <String?>{for (final r in records) r.serviceKindId};
  final tagged = ids.whereType<String>().toList()..sort();
  return [
    null, // All
    ...tagged,
    if (ids.contains(null)) MaintenanceHistoryFilter.untaggedSentinel,
  ];
}

List<ServiceType?> _typeOptions(List<ServiceRecord> records) {
  final types = {for (final r in records) r.serviceType}.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  return [null, ...types];
}

List<int?> _yearOptions(List<ServiceRecord> records) {
  final years = {for (final r in records) r.serviceDate.year}.toList()
    ..sort((a, b) => b.compareTo(a));
  return [null, ...years];
}
```

- [ ] **Step 5: Build the filter bar**

Render above the totals box, only when there is more than one option on some axis:

```dart
final showFilter = _taskOptions(records).length > 2 ||
    _typeOptions(records).length > 2 ||
    _yearOptions(records).length > 2;
```

Use a `Wrap` so three controls sit on one row on desktop and wrap on a phone. Each is a `DropdownButton` inside a bordered `Container` with `underline: SizedBox()`, matching `equipment_list_content.dart:636-696`. Label each option with the kind name, `type.label(l10n)`, or the year, using the "All" strings for the null entry and `equipment_service_filterUntagged` for the sentinel.

Below the bar, when `_filter.isActive`, show a row with a count and a clear action following `statistics_filter_bar.dart:11-47`:

```dart
TextButton.icon(
  onPressed: () =>
      setState(() => _filter = const MaintenanceHistoryFilter()),
  icon: const Icon(Icons.close, size: 16),
  label: Text(l10n.equipment_service_filterClear),
),
```

- [ ] **Step 6: Apply the filter**

```dart
final visible = records.where(_filter.matches).toList();
```

Render `visible` instead of `records`. When `visible.isEmpty` and `_filter.isActive`, show `equipment_service_filterNoMatches`; when `records.isEmpty`, keep the existing `equipment_service_emptyState`. The two states must stay distinct, because "you have logged nothing" and "your filter hides everything" call for different actions.

Leave the totals box reading the unfiltered `serviceRecordTotalCostProvider`. Lifetime cost of ownership is a property of the item, not of the current view, and recomputing it per filter would make the number jump for no reason the diver asked for.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/presentation/widgets/service_history_section_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/equipment/ test/features/equipment/ lib/l10n/arb/
git commit -m "feat(equipment): filter maintenance history by task, type and year (#829)"
```

---

## Task 6: Schema v157, the two column pairs

**Files:**
- Modify: `lib/core/database/database.dart:1137-1159`, `:1165-1189`, `:3072`, `:3283-3293`, `:8074-8093`, `:8241`, plus a new helper near `:4718`
- Create: `test/core/database/migration_v157_service_cost_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: columns `default_cost` (REAL, nullable) and `default_currency` (TEXT, nullable) on `service_kinds` and `service_schedules`; generated `ServiceKindRow.defaultCost`, `ServiceKindsCompanion.defaultCost` and the schedule equivalents. Tasks 7, 8 and 9 depend on these.

- [ ] **Step 1: Re-check the schema version**

Run: `git fetch origin && git show origin/main:lib/core/database/database.dart | grep -n "currentSchemaVersion = "`
Expected: `155` (main took 154 for #1104 and 155 for #828). Use the next free number consistently everywhere below; this plan was executed at **156**.

- [ ] **Step 2: Add the columns to both tables**

In `ServiceKinds` (after `defaultIntervalHours`, `database.dart:1146`) and in `ServiceSchedules` (after `intervalHours`, `:1175`), add the identical pair:

```dart
  /// Default price for this maintenance, prefilled into a new service record.
  /// Nullable currency means "no opinion, use the diver's default currency";
  /// a NOT NULL default would make every task silently claim USD.
  RealColumn get defaultCost => real().nullable()();
  TextColumn get defaultCurrency => text().nullable()();
```

- [ ] **Step 3: Bump the version constant**

`database.dart:3072`:

```dart
  static const int currentSchemaVersion = 157;
```

- [ ] **Step 4: Append to `migrationVersions`**

At the tail of the list (`database.dart:3291`), after `153,`:

```dart
    // v157 (issue #829): default service price on service_kinds and
    // service_schedules, prefilled when a maintenance record is logged.
    157,
```

- [ ] **Step 5: Write the migration helper**

Next to `_assertO2CellMillivoltColumns` (`database.dart:4718`):

```dart
  /// Default service price columns on service_kinds and service_schedules
  /// (issue #829). PRAGMA-guarded so a healthy database no-ops; the
  /// cols.isEmpty early return matters because minimal migration fixtures
  /// build databases without these tables and would otherwise crash the
  /// whole migration.
  Future<void> _assertServiceCostColumns() async {
    for (final table in const ['service_kinds', 'service_schedules']) {
      final cols = await customSelect("PRAGMA table_info('$table')").get();
      if (cols.isEmpty) continue;
      final names = cols.map((c) => c.read<String>('name')).toSet();
      if (!names.contains('default_cost')) {
        await customStatement(
          'ALTER TABLE $table ADD COLUMN default_cost REAL',
        );
      }
      if (!names.contains('default_currency')) {
        await customStatement(
          'ALTER TABLE $table ADD COLUMN default_currency TEXT',
        );
      }
    }
  }
```

- [ ] **Step 6: Register in the ladder and the backstop**

At the tail of `onUpgrade` (`database.dart:8093`), after the v153 pair:

```dart
        // v157: default service price on kinds and schedules (issue #829).
        if (from < 157) {
          await _assertServiceCostColumns();
        }
        if (from < 157) await reportProgress();
```

The pair is mandatory: the progress step count is derived from `migrationVersions.length`, so a missing `reportProgress()` desynchronizes the migration progress bar.

At the tail of the `beforeOpen` backstops (`database.dart:8243`):

```dart
        // v157 backstop: re-assert the default service price columns
        // (issue #829; parallel-branch version-collision self-heal).
        await _assertServiceCostColumns();
```

- [ ] **Step 7: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exit 0. This regenerates `toJson`/`fromJson`, which is what puts the new columns on the sync wire with no serializer edits.

- [ ] **Step 8: Write the migration test**

Create `test/core/database/migration_v157_service_cost_test.dart`, modeled on `migration_v153_o2_cell_mv_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v157 adds default cost columns, preserving rows', () async {
    final native = NativeDatabase.memory(
      setup: (db) {
        db.execute('PRAGMA user_version = 156');
        db.execute('''
          CREATE TABLE service_kinds (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            applicable_types TEXT NOT NULL DEFAULT '[]',
            default_interval_days INTEGER,
            default_interval_dives INTEGER,
            default_interval_hours REAL,
            auto_attach INTEGER NOT NULL DEFAULT 0,
            is_built_in INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
        db.execute(
          "INSERT INTO service_kinds (id, name, created_at, updated_at) "
          "VALUES ('disinfect', 'Disinfect', 1, 1)",
        );
      },
    );

    final db = AppDatabase(native);
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('service_kinds')")
        .get();
    final byName = {
      for (final c in cols) c.read<String>('name'): c,
    };
    expect(byName.containsKey('default_cost'), isTrue);
    expect(byName.containsKey('default_currency'), isTrue);
    expect(byName['default_cost']!.read<String>('type').toUpperCase(), 'REAL');
    expect(byName['default_currency']!.read<String>('type').toUpperCase(),
        'TEXT');

    final row = await db
        .customSelect("SELECT name, default_cost FROM service_kinds")
        .getSingle();
    expect(row.read<String>('name'), 'Disinfect');
    expect(row.read<double?>('default_cost'), isNull);
  });

  test('migration list includes v157 and schema is at least 156', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(157));
    expect(AppDatabase.migrationVersions, contains(157));
  });

  test('v157 is idempotent when a column already exists', () async {
    final native = NativeDatabase.memory(
      setup: (db) {
        db.execute('PRAGMA user_version = 156');
        db.execute('''
          CREATE TABLE service_schedules (
            id TEXT NOT NULL PRIMARY KEY,
            equipment_id TEXT NOT NULL,
            service_kind_id TEXT NOT NULL,
            interval_days INTEGER,
            interval_dives INTEGER,
            interval_hours REAL,
            anchor_date INTEGER,
            enabled INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT,
            default_cost REAL
          )
        ''');
      },
    );

    final db = AppDatabase(native);
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('service_schedules')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toList();
    expect(names.where((n) => n == 'default_cost').length, 1);
    expect(names, contains('default_currency'));
  });

  test('the helper no-ops when the tables are absent', () async {
    final native = NativeDatabase.memory(
      setup: (db) => db.execute('PRAGMA user_version = 156'),
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });
}
```

- [ ] **Step 9: Run the migration test**

Run: `flutter test test/core/database/migration_v157_service_cost_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 10: Guard the built-in seed**

Built-in kinds get no seeded price. `kSeedBuiltInServiceKindsSql` (`database.dart:2220-2258`) is `INSERT OR IGNORE`, so seeded values would never reach an existing installation anyway, and prices are personal and regional. Leaving the seed alone also keeps its positional column list intact.

Add to `test/core/database/service_ledger_schema_test.dart`:

```dart
test('built-in kinds carry no default cost', () async {
  final rows = await db
      .customSelect(
        'SELECT default_cost, default_currency FROM service_kinds '
        'WHERE is_built_in = 1',
      )
      .get();
  expect(rows, isNotEmpty);
  for (final row in rows) {
    expect(row.read<double?>('default_cost'), isNull);
    expect(row.read<String?>('default_currency'), isNull);
  }
});
```

- [ ] **Step 11: Run the ledger schema and sync suites**

Run: `flutter test test/core/database/ test/core/services/sync/`
Expected: PASS. Sync needs no serializer edits, because `sync_data_serializer.dart` routes these tables through the generated `toJson`/`fromJson`.

- [ ] **Step 12: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/database/ test/core/database/
git commit -m "feat(db): default service cost columns, schema v157 (#829)"
```

---

## Task 7: Entities and repositories carry the new fields

**Files:**
- Modify: `lib/features/equipment/domain/entities/service_kind.dart`
- Modify: `lib/features/equipment/domain/entities/service_schedule.dart`
- Modify: `lib/features/equipment/data/repositories/service_kind_repository.dart:52-114`, `:145-168`
- Modify: `lib/features/equipment/data/repositories/service_schedule_repository.dart:49-99`, `:168-183`
- Create: `test/features/equipment/domain/entities/service_cost_fields_test.dart`

**Interfaces:**
- Consumes: the generated companions from Task 6.
- Produces: `ServiceKind.defaultCost`, `ServiceKind.defaultCurrency`, `ServiceSchedule.defaultCost`, `ServiceSchedule.defaultCurrency`, all `double?`/`String?` and clearable through `copyWith`. Tasks 8 and 9 depend on them.

- [ ] **Step 1: Write the failing test**

Create `test/features/equipment/domain/entities/service_cost_fields_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

void main() {
  final now = DateTime(2026, 8, 18);

  test('ServiceKind.copyWith clears defaultCost to null', () {
    final kind = ServiceKind(
      id: 'k1',
      name: 'Disinfect',
      defaultCost: 12.5,
      defaultCurrency: 'EUR',
      createdAt: now,
      updatedAt: now,
    );

    expect(kind.copyWith(defaultCost: null).defaultCost, isNull);
    expect(kind.copyWith(defaultCurrency: null).defaultCurrency, isNull);
    // Omitting the argument leaves the value alone.
    expect(kind.copyWith(name: 'Rinse').defaultCost, 12.5);
  });

  test('ServiceSchedule.copyWith clears defaultCost to null', () {
    final schedule = ServiceSchedule(
      id: 's1',
      equipmentId: 'e1',
      serviceKindId: 'k1',
      defaultCost: 45,
      defaultCurrency: 'EUR',
      createdAt: now,
      updatedAt: now,
    );

    expect(schedule.copyWith(defaultCost: null).defaultCost, isNull);
    expect(schedule.copyWith(enabled: false).defaultCost, 45);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/domain/entities/service_cost_fields_test.dart`
Expected: FAIL, `No named parameter with the name 'defaultCost'`.

- [ ] **Step 3: Extend `ServiceKind`**

Add the fields, constructor entries, `props` entries, and `copyWith` handling. Both new fields are nullable and clearable, so they use the existing `_undefined` sentinel exactly like `defaultIntervalDays`:

```dart
  final double? defaultCost;
  final String? defaultCurrency;
```

```dart
    this.defaultCost,
    this.defaultCurrency,
```

```dart
    Object? defaultCost = _undefined,
    Object? defaultCurrency = _undefined,
```

```dart
      defaultCost: defaultCost == _undefined
          ? this.defaultCost
          : defaultCost as double?,
      defaultCurrency: defaultCurrency == _undefined
          ? this.defaultCurrency
          : defaultCurrency as String?,
```

Add both to `props`. Update the `copyWith` docstring to name the new fields alongside the interval ones.

- [ ] **Step 4: Extend `ServiceSchedule` identically**

Same four edits in `service_schedule.dart`, using its own `_undefined` sentinel.

- [ ] **Step 5: Run the entity test to verify it passes**

Run: `flutter test test/features/equipment/domain/entities/service_cost_fields_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 6: Extend the kind repository**

In `createKind` (`:58`) and `updateKind` (`:96`) companions, add next to `defaultIntervalHours`:

```dart
            defaultCost: Value(kind.defaultCost),
            defaultCurrency: Value(kind.defaultCurrency),
```

In `_mapRow` (`:145`), add next to `defaultIntervalHours`:

```dart
      defaultCost: row.defaultCost,
      defaultCurrency: row.defaultCurrency,
```

- [ ] **Step 7: Extend the schedule repository identically**

Same three edits in `createSchedule` (`:57`), `updateSchedule` (`:82`) and `_mapRow` (`:168`), placed next to `intervalHours`.

- [ ] **Step 8: Add a sync round-trip assertion**

In `test/core/services/sync/service_ledger_sync_test.dart`, extend the existing kind and schedule round-trip cases so the wire maps carry `default_cost` and `default_currency`, and assert they survive export and re-import.

- [ ] **Step 9: Run the equipment and sync suites**

Run: `flutter test test/features/equipment/ test/core/services/sync/`
Expected: PASS.

- [ ] **Step 10: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/equipment/ test/features/equipment/ test/core/services/sync/
git commit -m "feat(equipment): carry default service cost through entities and repos (#829)"
```

---

## Task 8: The cost resolver

A pure function, so the precedence rule gets tested without a widget or a database.

**Files:**
- Create: `lib/features/equipment/domain/services/default_service_cost_resolver.dart`
- Create: `test/features/equipment/domain/services/default_service_cost_resolver_test.dart`

**Interfaces:**
- Consumes: `ServiceKind`, `ServiceSchedule` (Task 7).
- Produces:

```dart
typedef DefaultServiceCost = ({double? cost, String? currency});

DefaultServiceCost resolveDefaultServiceCost({
  required String? serviceKindId,
  required List<ServiceSchedule> schedules,
  required List<ServiceKind> kinds,
});
```

Task 9 calls it.

- [ ] **Step 1: Write the failing test**

Create `test/features/equipment/domain/services/default_service_cost_resolver_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/services/default_service_cost_resolver.dart';

void main() {
  final now = DateTime(2026, 8, 18);

  ServiceKind kind({double? cost, String? currency}) => ServiceKind(
    id: 'scrubber-repack',
    name: 'Scrubber repack',
    defaultCost: cost,
    defaultCurrency: currency,
    createdAt: now,
    updatedAt: now,
  );

  ServiceSchedule schedule({double? cost, String? currency}) => ServiceSchedule(
    id: 's1',
    equipmentId: 'e1',
    serviceKindId: 'scrubber-repack',
    defaultCost: cost,
    defaultCurrency: currency,
    createdAt: now,
    updatedAt: now,
  );

  test('the per-item schedule wins over the catalog kind', () {
    final result = resolveDefaultServiceCost(
      serviceKindId: 'scrubber-repack',
      schedules: [schedule(cost: 45, currency: 'EUR')],
      kinds: [kind(cost: 60, currency: 'USD')],
    );
    expect(result.cost, 45);
    expect(result.currency, 'EUR');
  });

  test('the kind is used when the schedule has no cost', () {
    final result = resolveDefaultServiceCost(
      serviceKindId: 'scrubber-repack',
      schedules: [schedule()],
      kinds: [kind(cost: 60, currency: 'USD')],
    );
    expect(result.cost, 60);
    expect(result.currency, 'USD');
  });

  test('cost and currency resolve independently', () {
    // A schedule that prices the job but says nothing about currency should
    // still inherit the kind's currency rather than dropping it.
    final result = resolveDefaultServiceCost(
      serviceKindId: 'scrubber-repack',
      schedules: [schedule(cost: 45)],
      kinds: [kind(cost: 60, currency: 'EUR')],
    );
    expect(result.cost, 45);
    expect(result.currency, 'EUR');
  });

  test('nothing resolves when neither defines a cost', () {
    final result = resolveDefaultServiceCost(
      serviceKindId: 'scrubber-repack',
      schedules: [schedule()],
      kinds: [kind()],
    );
    expect(result.cost, isNull);
    expect(result.currency, isNull);
  });

  test('an untagged record resolves nothing', () {
    final result = resolveDefaultServiceCost(
      serviceKindId: null,
      schedules: [schedule(cost: 45)],
      kinds: [kind(cost: 60)],
    );
    expect(result.cost, isNull);
  });

  test('an unknown kind id resolves nothing', () {
    final result = resolveDefaultServiceCost(
      serviceKindId: 'deleted-kind',
      schedules: [schedule(cost: 45)],
      kinds: [kind(cost: 60)],
    );
    expect(result.cost, isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/domain/services/default_service_cost_resolver_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the resolver**

Create `lib/features/equipment/domain/services/default_service_cost_resolver.dart`:

```dart
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

typedef DefaultServiceCost = ({double? cost, String? currency});

/// Resolves the price to prefill when logging maintenance, most specific
/// first: the per-item schedule, then the shared kind catalog.
///
/// Issue #829 lists the catalog before the interval. That is inverted
/// relative to specificity: a kind is global across every item using it,
/// while a schedule belongs to one piece of equipment, so two rebreathers
/// serviced at different shops could never reach their own price. The issue
/// also says the value can be overwritten or deleted, which makes the whole
/// chain a prefill rather than a binding value, so letting the per-item
/// figure win serves the stated goal.
///
/// Cost and currency resolve independently: a schedule that names a price but
/// no currency still inherits the kind's currency instead of dropping it.
DefaultServiceCost resolveDefaultServiceCost({
  required String? serviceKindId,
  required List<ServiceSchedule> schedules,
  required List<ServiceKind> kinds,
}) {
  if (serviceKindId == null) return (cost: null, currency: null);

  ServiceSchedule? schedule;
  for (final candidate in schedules) {
    if (candidate.serviceKindId == serviceKindId) {
      schedule = candidate;
      break;
    }
  }

  ServiceKind? kind;
  for (final candidate in kinds) {
    if (candidate.id == serviceKindId) {
      kind = candidate;
      break;
    }
  }

  return (
    cost: schedule?.defaultCost ?? kind?.defaultCost,
    currency: schedule?.defaultCurrency ?? kind?.defaultCurrency,
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/domain/services/default_service_cost_resolver_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/equipment/domain/services/ test/features/equipment/domain/services/
git commit -m "feat(equipment): resolve default service cost, schedule before kind (#829)"
```

---

## Task 9: Editors set the default, the dialog prefills it

**Files:**
- Modify: `lib/features/equipment/presentation/pages/service_kind_list_page.dart:293-321`, `:433-479`
- Modify: `lib/features/equipment/presentation/widgets/service_schedule_dialogs.dart:145-291`
- Modify: `lib/features/equipment/presentation/widgets/service_record_dialog.dart`
- Modify: `test/features/equipment/presentation/pages/service_kind_list_page_test.dart`
- Create: `test/features/equipment/presentation/widgets/service_record_dialog_prefill_test.dart`
- Modify: `lib/l10n/arb/*.arb`

**Interfaces:**
- Consumes: `resolveDefaultServiceCost` (Task 8), the entity fields (Task 7).
- Produces: no new public API.

- [ ] **Step 1: Add the editor keys to all 11 ARB files**

English:

```json
  "equipment_serviceKinds_defaultCostLabel": "Default price",
  "equipment_serviceKinds_defaultCostHint": "Leave blank for no default",
  "equipment_scheduleDialog_defaultCostLabel": "Default price for this item",
```

German: `"Standardpreis"`, `"Leer lassen für keinen Standardwert"`, `"Standardpreis für dieses Teil"`. Translate for the other nine, then run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing prefill test**

Create `test/features/equipment/presentation/widgets/service_record_dialog_prefill_test.dart`. Override `serviceKindsProvider` and `serviceSchedulesForEquipmentProvider`, following the harness in `service_record_dialog_kind_test.dart`.

```dart
testWidgets('creating a record prefills the schedule price', (tester) async {
  await tester.pumpWidget(harness(
    kindCost: 60,
    scheduleCost: 45,
    serviceKindId: 'scrubber-repack',
  ));
  await tester.pumpAndSettle();

  final field = tester.widget<TextFormField>(find.byKey(costFieldKey));
  expect(field.controller!.text, '45');
});

testWidgets('editing an existing record never prefills', (tester) async {
  // A record whose cost the diver deliberately cleared must stay cleared.
  await tester.pumpWidget(harness(
    kindCost: 60,
    scheduleCost: 45,
    existingRecordWithNullCost: true,
  ));
  await tester.pumpAndSettle();

  final field = tester.widget<TextFormField>(find.byKey(costFieldKey));
  expect(field.controller!.text, isEmpty);
});

testWidgets('a cost the diver has typed is not overwritten', (tester) async {
  await tester.pumpWidget(harness(kindCost: 60));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(costFieldKey), '99');
  // Changing the clock re-resolves, but must not clobber a typed value.
  await tester.tap(find.text('Scrubber repack'));
  await tester.pumpAndSettle();

  final field = tester.widget<TextFormField>(find.byKey(costFieldKey));
  expect(field.controller!.text, '99');
});
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/presentation/widgets/service_record_dialog_prefill_test.dart`
Expected: FAIL, the cost field is empty because no prefill exists.

- [ ] **Step 4: Add the cost field to the kind editor**

In `_ServiceKindEditDialogState` (`service_kind_list_page.dart:293`), add `final _defaultCost = TextEditingController();` and a currency `DropdownMenu` mirroring the record dialog. Seed in `initState` with `formatDecimalForInput`, dispose it, and add a `TextFormField` after the interval fields:

```dart
TextFormField(
  controller: _defaultCost,
  decoration: InputDecoration(
    labelText: l10n.equipment_serviceKinds_defaultCostLabel,
    hintText: l10n.equipment_serviceKinds_defaultCostHint,
  ),
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
),
```

In `_save()` (`:433`), read it with `parseUserDecimal(_defaultCost.text)` and pass it to the directly constructed `ServiceKind`. That constructor is built by hand rather than through `copyWith` on purpose, per the comment at `:461`.

`formatDecimalForInput` and `parseUserDecimal` must be used as a pair. `toString()` would seed `"12.5"` in a locale where `.` is a thousands separator (issue #1091), exactly as the existing hours field already guards against.

- [ ] **Step 5: Add the cost field to the schedule dialog**

In `_ScheduleOverrideDialogState` (`service_schedule_dialogs.dart:145`), add the same controller and field, with the kind's value as a hint when the override is blank, reusing the inherit-hint idiom at `:196-208`:

```dart
hintText: kind.defaultCost == null
    ? l10n.equipment_serviceKinds_defaultCostHint
    : l10n.equipment_scheduleDialog_inheritHint(
        formatDecimalForInput(kind.defaultCost!),
      ),
```

In `_save()` (`:269`), pass `parseUserDecimal(_defaultCost.text)` into the directly constructed `ServiceSchedule`.

- [ ] **Step 6: Prefill in the record dialog**

In `service_record_dialog.dart`, add a `bool _costTouched = false;` and mark it in the cost field's `onChanged`. Give the cost `TextFormField` a `Key('service-record-cost')` so the tests can find it.

Prefill cannot run in `initState`, because the kinds and schedules arrive from `FutureProvider`s. Apply it in `build` once both have data:

```dart
// The prefill is a convenience, not a binding value: it only ever fills an
// untouched field on a NEW record. Editing must never re-prefill, or a cost
// the diver deliberately cleared would silently come back.
void _maybePrefillCost(List<ServiceKind> kinds, List<ServiceSchedule> schedules) {
  if (isEditing || _costTouched) return;
  final resolved = resolveDefaultServiceCost(
    serviceKindId: _serviceKindId,
    schedules: schedules,
    kinds: kinds,
  );
  final text = resolved.cost == null
      ? ''
      : formatDecimalForInput(resolved.cost!);
  if (_costController.text != text) {
    _costController.text = text;
  }
  if (resolved.currency != null && !_costTouched) {
    _currencyController.text = resolved.currency!;
  }
}
```

Call it from `build` after reading both providers' values, and again when the clock dropdown's `onChanged` fires so switching tasks re-resolves.

- [ ] **Step 7: Run the prefill tests to verify they pass**

Run: `flutter test test/features/equipment/presentation/widgets/service_record_dialog_prefill_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 8: Add a locale round-trip test**

In `test/features/equipment/presentation/pages/service_kind_list_page_test.dart`, add a case that enters a comma-decimal default cost under `Locale('de')` and asserts the saved `ServiceKind.defaultCost` is `12.5`, matching the existing `equipment_edit_price_locale_test.dart` pattern.

- [ ] **Step 9: Run the equipment suite**

Run: `flutter test test/features/equipment/`
Expected: PASS.

- [ ] **Step 10: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/equipment/ test/features/equipment/ lib/l10n/arb/
git commit -m "feat(equipment): default service price on kind and schedule (#829)"
```

---

## Task 10: The Maintenance Log sheet builder

**Files:**
- Create: `lib/core/services/export/excel/maintenance_excel_export_service.dart`
- Create: `test/core/services/export/excel/maintenance_excel_export_service_test.dart`

**Interfaces:**
- Consumes: `ServiceRecord`, `ServiceKind`, `EquipmentItem`.
- Produces:

```dart
class MaintenanceExcelExportService {
  static const maintenanceSheet = 'Maintenance Log';
  void buildSheet(xl.Excel excel, {required List<MaintenanceLogRow> rows, required DateFormatPreference dateFormat});
  List<int> generateBytes({required List<MaintenanceLogRow> rows, required DateFormatPreference dateFormat});
  Future<String> exportToExcel({required List<MaintenanceLogRow> rows, required DateFormatPreference dateFormat});
  Future<String?> saveToFile({required List<MaintenanceLogRow> rows, required DateFormatPreference dateFormat});
}

typedef MaintenanceLogRow = ({
  String equipmentName,
  String equipmentType,
  String taskName,
  ServiceType serviceType,
  ServiceRecord record,
});
```

Task 11 builds the rows and calls all four methods.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/export/excel/maintenance_excel_export_service_test.dart`, modeled on `pre_dive_excel_export_service_test.dart`:

```dart
import 'package:excel_community/excel_community.dart' as xl;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/excel/maintenance_excel_export_service.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';

void main() {
  final service = MaintenanceExcelExportService();
  final date = DateTime(2026, 3, 14);

  MaintenanceLogRow row({String task = 'Scrubber repack', double? cost = 45}) => (
    equipmentName: 'JJ-CCR',
    equipmentType: 'Rebreather',
    taskName: task,
    serviceType: ServiceType.cleaning,
    record: ServiceRecord(
      id: 'r1',
      equipmentId: 'e1',
      serviceType: ServiceType.cleaning,
      serviceKindId: 'scrubber-repack',
      serviceDate: date,
      provider: 'DiveShop Bonn',
      cost: cost,
      currency: 'EUR',
      nextServiceDue: DateTime(2026, 6, 14),
      notes: 'Packed 2.4kg',
      createdAt: date,
      updatedAt: date,
    ),
  );

  test('writes the header row', () {
    final excel = xl.Excel.createExcel();
    service.buildSheet(excel, rows: [row()],
        dateFormat: DateFormatPreference.yyyymmdd);

    final sheet = excel[MaintenanceExcelExportService.maintenanceSheet];
    final headers = sheet.rows.first
        .map((c) => (c?.value as xl.TextCellValue?)?.value.toString())
        .toList();

    expect(headers, [
      'Equipment', 'Equipment Type', 'Task', 'Category', 'Date',
      'Provider', 'Cost', 'Currency', 'Next Due', 'Notes',
    ]);
  });

  test('maps a record onto one row', () {
    final excel = xl.Excel.createExcel();
    service.buildSheet(excel, rows: [row()],
        dateFormat: DateFormatPreference.yyyymmdd);

    final sheet = excel[MaintenanceExcelExportService.maintenanceSheet];
    final values = sheet.rows[1].map((c) => c?.value).toList();

    expect((values[0] as xl.TextCellValue).value.toString(), 'JJ-CCR');
    expect((values[2] as xl.TextCellValue).value.toString(), 'Scrubber repack');
    expect((values[3] as xl.TextCellValue).value.toString(), 'Cleaning');
    expect((values[6] as xl.DoubleCellValue).value, 45.0);
    expect((values[7] as xl.TextCellValue).value.toString(), 'EUR');
  });

  test('an untagged record leaves the task column blank', () {
    final excel = xl.Excel.createExcel();
    service.buildSheet(excel, rows: [row(task: '')],
        dateFormat: DateFormatPreference.yyyymmdd);

    final sheet = excel[MaintenanceExcelExportService.maintenanceSheet];
    final task = sheet.rows[1][2]?.value as xl.TextCellValue;
    expect(task.value.toString(), isEmpty);
  });

  test('generateBytes produces a decodable workbook without Sheet1', () {
    final bytes = service.generateBytes(
      rows: [row()],
      dateFormat: DateFormatPreference.yyyymmdd,
    );

    expect(bytes, isNotEmpty);
    final decoded = xl.Excel.decodeBytes(bytes);
    expect(decoded.tables.keys,
        contains(MaintenanceExcelExportService.maintenanceSheet));
    expect(decoded.tables.keys, isNot(contains('Sheet1')));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/export/excel/maintenance_excel_export_service_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the service**

Create `lib/core/services/export/excel/maintenance_excel_export_service.dart`, following `pre_dive_excel_export_service.dart` exactly:

```dart
import 'dart:typed_data';

import 'package:excel_community/excel_community.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/export/shared/unit_converters.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';

/// One maintenance entry, flattened with the names it needs.
///
/// The sheet needs the equipment name and the resolved service kind name,
/// neither of which lives on [ServiceRecord]. Resolving them at the call site
/// keeps this service free of repository dependencies and trivially testable.
typedef MaintenanceLogRow = ({
  String equipmentName,
  String equipmentType,
  String taskName,
  ServiceType serviceType,
  ServiceRecord record,
});

/// Exports maintenance history to a spreadsheet.
///
/// Column headers are English constants, matching [ExcelExportService]: the
/// workbook is an analysis target, not a UI surface.
class MaintenanceExcelExportService {
  static const maintenanceSheet = 'Maintenance Log';

  static const _mimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  final _fileDateFormat = DateFormat('yyyy-MM-dd');

  /// Writes the sheet into an existing workbook, so the whole-library export
  /// can carry maintenance history alongside its other sheets.
  void buildSheet(
    xl.Excel excel, {
    required List<MaintenanceLogRow> rows,
    required DateFormatPreference dateFormat,
  }) {
    final sheet = excel[maintenanceSheet];

    _writeRow(sheet, 0, const [
      'Equipment',
      'Equipment Type',
      'Task',
      'Category',
      'Date',
      'Provider',
      'Cost',
      'Currency',
      'Next Due',
      'Notes',
    ]);

    for (var i = 0; i < rows.length; i++) {
      final entry = rows[i];
      final record = entry.record;
      _writeRow(sheet, i + 1, [
        entry.equipmentName,
        entry.equipmentType,
        entry.taskName,
        entry.serviceType.displayName,
        formatDateForExport(record.serviceDate, dateFormat),
        record.provider ?? '',
        record.cost,
        record.currency,
        record.nextServiceDue == null
            ? ''
            : formatDateForExport(record.nextServiceDue!, dateFormat),
        record.notes.replaceAll('\n', ' '),
      ]);
    }
  }

  /// Builds a standalone maintenance workbook.
  List<int> generateBytes({
    required List<MaintenanceLogRow> rows,
    required DateFormatPreference dateFormat,
  }) {
    final excel = xl.Excel.createExcel();
    buildSheet(excel, rows: rows, dateFormat: dateFormat);
    // Deleted only after the real sheet exists: the excel package refuses to
    // remove a workbook's last remaining sheet, so deleting first is a no-op
    // that leaves a stray empty "Sheet1" in the output.
    excel.delete('Sheet1');
    return excel.encode() ?? const <int>[];
  }

  /// Writes the workbook to the documents directory and opens the system share
  /// sheet. Share-only by contract; see [saveToFile] for the save path.
  Future<String> exportToExcel({
    required List<MaintenanceLogRow> rows,
    required DateFormatPreference dateFormat,
  }) {
    final bytes = generateBytes(rows: rows, dateFormat: dateFormat);
    return saveAndShareFileBytes(bytes, _fileName(), _mimeType);
  }

  /// Prompts for a destination. Returns null when the diver cancelled, which
  /// callers must treat as a no-op rather than as success.
  Future<String?> saveToFile({
    required List<MaintenanceLogRow> rows,
    required DateFormatPreference dateFormat,
  }) async {
    final bytes = generateBytes(rows: rows, dateFormat: dateFormat);
    final result = await FilePicker.saveFile(
      dialogTitle: 'Save Maintenance Log',
      fileName: _fileName(),
      type: FileType.custom,
      bytes: Uint8List.fromList(bytes),
      mimeType: _mimeType,
    );

    if (result == null) return null;
    return savedFileLocation(result);
  }

  String _fileName() =>
      'submersion_maintenance_${_fileDateFormat.format(DateTime.now())}.xlsx';

  void _writeRow(xl.Sheet sheet, int rowIndex, List<dynamic> values) {
    for (var col = 0; col < values.length; col++) {
      sheet
          .cell(
            xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
          )
          .value = _toCellValue(
        values[col],
      );
    }
  }

  xl.CellValue _toCellValue(dynamic value) {
    if (value == null || value == '') {
      return xl.TextCellValue('');
    } else if (value is int) {
      return xl.IntCellValue(value);
    } else if (value is double) {
      return xl.DoubleCellValue(value);
    } else {
      return xl.TextCellValue(value.toString());
    }
  }
}
```

Note `serviceType.displayName` here, not the localized label: spreadsheet headers and values stay English by the documented convention.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/services/export/excel/maintenance_excel_export_service_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/services/export/excel/maintenance_excel_export_service.dart \
        test/core/services/export/excel/maintenance_excel_export_service_test.dart
git commit -m "feat(export): Maintenance Log Excel sheet builder (#829)"
```

---

## Task 11: Wire the three export surfaces

**Files:**
- Modify: `lib/core/services/export/excel/excel_export_service.dart:21`, `:66-118`
- Modify: `lib/core/services/export/export_service.dart:152-224`
- Modify: `lib/features/settings/presentation/providers/export_providers.dart`
- Modify: `lib/features/transfer/presentation/pages/transfer_page.dart:361-378`
- Modify: `lib/features/equipment/presentation/widgets/service_history_section.dart`
- Modify: `lib/l10n/arb/*.arb`

**Interfaces:**
- Consumes: `MaintenanceExcelExportService` (Task 10), `MaintenanceHistoryFilter` (Task 4), the kind map (Task 3).
- Produces: `ExportNotifier.exportMaintenanceLog()` and `ExportNotifier.saveMaintenanceLogToFile()`.

- [ ] **Step 1: Add the export keys to all 11 ARB files**

English:

```json
  "equipment_service_exportMenuItem": "Export maintenance log",
  "transfer_export_maintenanceTitle": "Maintenance Log",
  "transfer_export_maintenanceSubtitle": "Service history for all equipment as a spreadsheet",
  "settings_export_progress_maintenance": "Exporting maintenance log...",
  "settings_export_success_maintenance": "Maintenance log exported",
  "settings_export_saved_maintenance": "Maintenance log saved"
```

German: `"Wartungsprotokoll exportieren"`, `"Wartungsprotokoll"`, `"Serviceverlauf für die gesamte Ausrüstung als Tabelle"`, `"Wartungsprotokoll wird exportiert..."`, `"Wartungsprotokoll exportiert"`, `"Wartungsprotokoll gespeichert"`. Translate for the other nine, then run `flutter gen-l10n`.

- [ ] **Step 2: Ride the sheet into the whole-library workbook**

In `excel_export_service.dart`, add the field next to `_preDive` (`:21`):

```dart
  final _maintenance = MaintenanceExcelExportService();
```

Add an optional `List<MaintenanceLogRow> maintenanceRows = const []` parameter to `exportToExcel`, `generateExcelBytes` and `saveExcelToFile`, and call the builder inside `generateExcelBytes` before `excel.delete('Sheet1')`:

```dart
    if (maintenanceRows.isNotEmpty) {
      _maintenance.buildSheet(
        excel,
        rows: maintenanceRows,
        dateFormat: dateFormat,
      );
    }
```

Defaulting to empty keeps every existing caller compiling unchanged. Thread the same parameter through `export_service.dart:152-224`.

- [ ] **Step 3: Add the row builder to the export providers**

In `export_providers.dart`, add a private helper that resolves names once:

```dart
  /// Flattens every equipment item's service history into log rows.
  ///
  /// Resolved here rather than in the export service so the service stays a
  /// pure sheet builder with no repository dependencies.
  Future<List<MaintenanceLogRow>> _buildMaintenanceRows() async {
    final equipment = await _ref.read(allEquipmentProvider.future);
    final kinds = await _ref.read(serviceKindsProvider.future);
    final kindsById = {for (final k in kinds) k.id: k};
    final repository = _ref.read(serviceRecordRepositoryProvider);

    final rows = <MaintenanceLogRow>[];
    for (final item in equipment) {
      final records = await repository.getRecordsForEquipment(item.id);
      for (final record in records) {
        rows.add((
          equipmentName: item.name,
          equipmentType: item.type.name,
          taskName: kindsById[record.serviceKindId]?.name ?? '',
          serviceType: record.serviceType,
          record: record,
        ));
      }
    }
    return rows;
  }
```

- [ ] **Step 4: Add the two notifier methods**

Model them on `exportToExcel` (`:504-558`) and `saveExcelToFile` (`:610-671`), including the cancellation branch:

```dart
  Future<void> saveMaintenanceLogToFile() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_maintenance,
    );
    try {
      final rows = await _buildMaintenanceRows();
      if (rows.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_data,
        );
        return;
      }
      final settings = _ref.read(settingsProvider);
      state = state.copyWith(
        message: _l10n.settings_export_progress_chooseLocation,
      );
      final path = await MaintenanceExcelExportService().saveToFile(
        rows: rows,
        dateFormat: settings.dateFormat,
      );
      // null means the diver cancelled the save panel, which is a no-op and
      // must never be reported as success.
      if (path == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: _l10n.settings_export_cancelled_save,
        );
        return;
      }
      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_saved_maintenance,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_export_saveFailed('$e'),
      );
    }
  }
```

Write `exportMaintenanceLog()` the same way, calling `exportToExcel` and reporting `settings_export_success_maintenance`.

- [ ] **Step 5: Add the transfer page tile**

In `transfer_page.dart`, after the Excel tile (`:378`) and its `Divider`:

```dart
                ListTile(
                  leading: const Icon(Icons.build_circle_outlined),
                  title: Text(context.l10n.transfer_export_maintenanceTitle),
                  subtitle:
                      Text(context.l10n.transfer_export_maintenanceSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showExportOptions(
                    context,
                    ref,
                    title: context.l10n.transfer_export_maintenanceTitle,
                    shareAction: () => ref
                        .read(exportNotifierProvider.notifier)
                        .exportMaintenanceLog(),
                    saveAction: () => ref
                        .read(exportNotifierProvider.notifier)
                        .saveMaintenanceLogToFile(),
                  ),
                ),
                const Divider(height: 1),
```

- [ ] **Step 6: Add the item-level export action**

In `service_history_section.dart`, add a `PopupMenuButton` next to the "Add" button in the header with one item, `equipment_service_exportMenuItem`. On tap, build rows from the **currently filtered** list and route through `showExportDestinationSheet`:

```dart
final destination = await showExportDestinationSheet(
  context,
  title: l10n.equipment_service_exportMenuItem,
);
if (destination == null) return;
final service = MaintenanceExcelExportService();
final rows = [
  for (final record in visible)
    (
      equipmentName: item.name,
      equipmentType: item.type.name,
      taskName: kindsById[record.serviceKindId]?.name ?? '',
      serviceType: record.serviceType,
      record: record,
    ),
];
if (destination == ExportDestination.share) {
  await service.exportToExcel(rows: rows, dateFormat: settings.dateFormat);
} else {
  await service.saveToFile(rows: rows, dateFormat: settings.dateFormat);
}
```

Do not raise a progress dialog over `FilePicker.saveFile`. The native save panel must not open while a modal route is up.

- [ ] **Step 7: Write the item-level export test**

Add to `test/features/equipment/presentation/widgets/service_history_section_test.dart`:

```dart
testWidgets('the item-level export offers share and save', (tester) async {
  await tester.pumpWidget(harness());
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.more_vert).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Export maintenance log'));
  await tester.pumpAndSettle();

  expect(find.text('Save to File'), findsOneWidget);
  expect(find.text('Share'), findsOneWidget);
});
```

- [ ] **Step 8: Run the affected suites**

Run: `flutter test test/features/equipment/ test/core/services/export/ test/features/transfer/ test/features/settings/`
Expected: PASS.

- [ ] **Step 9: Run the full suite**

Run: `flutter test`
Expected: PASS. Two known pre-existing flakes may appear under full-suite parallelism and are not regressions: the recovery-code split tests and the security-settings recovery dialog. Re-run any failure in isolation before treating it as yours.

- [ ] **Step 10: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/ test/
git commit -m "feat(export): Excel maintenance log entry points (#829)"
```

---

## Task 12: Manual verification and PR

- [ ] **Step 1: Run the app on macOS**

Run: `flutter run -d macos`

Verify against a rebreather item with several custom kinds:

1. History rows name the task, not the category.
2. An untagged record falls back to the localized category.
3. Notes and next due render.
4. The three filter dropdowns appear only when there is something to filter, and narrow correctly.
5. A default price on a kind prefills a new record; a schedule price overrides it; editing does not re-prefill.
6. Both export paths produce a readable workbook.

- [ ] **Step 2: Check the German build for the layout regression**

Switch the app language to German, give a task a long name, and confirm the title ellipsizes rather than rendering one glyph per line. This is the symptom the automated width assertion guards, checked once by eye on a real window.

- [ ] **Step 3: Open the PR**

```bash
git push -u origin worktree-issue-829-maintenance-history
```

The PR body must state the multi-device caveat: a default price set on a task or interval will not reach a second device until a full base export runs, because `serviceKinds` and `serviceSchedules` are absent from `SyncRepository._hlcTargets`. That gap is tracked separately in issue #1144. Do not include Claude Code attribution or a session link.

---

## Self-Review

**Spec coverage:**

| Spec section | Task |
| --- | --- |
| Rows that name the task | 3 |
| Cost out of `trailing` (#935 class) | 3 |
| `ServiceType` localization | 1, 3 |
| Notes and next due rendered | 3 |
| Filter | 4, 5 |
| Default price columns, migration v157 | 6 |
| Entity and repository plumbing | 7 |
| Resolution order | 8 |
| Editors and prefill | 9 |
| Excel sheet builder | 10 |
| Three export surfaces | 11 |
| File extraction | 2 |
| Localization (11 locales) | 1, 3, 5, 9, 11 |
| Deferred HLC gap noted in PR | 12 |

**Type consistency:** `MaintenanceLogRow` is defined once in Task 10 and constructed identically in Tasks 10, 11 (provider) and 11 (item-level). `resolveDefaultServiceCost` returns the `DefaultServiceCost` record type defined in Task 8 and destructured as `.cost`/`.currency` in Task 9. `MaintenanceHistoryFilter.untaggedSentinel` is defined in Task 4 and referenced in Task 5. `ServiceTypeL10n.label` is defined in Task 1 and called in Tasks 3, 5. `ServiceHistorySection` is made public in Task 2 and modified in Tasks 3, 5, 11.

**Placeholder scan:** no TBD, TODO, or "similar to Task N" references. Every code step carries the code.
