# Equipment Service Status Everywhere Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a piece of equipment's service status (overdue and due soon) on every current-facing surface that names it, from one shared widget.

**Architecture:** A single `ServiceStatusIndicator` widget renders three densities from a `RollupClock?`, owning the nothing-to-say filter, the rollup naming rule, the severity colour lookup and the accessibility wrapping. Every surface obtains its clock by indexing the existing batch `equipmentRollupClockProvider` map by equipment id, so no surface adds a query. An architecture guard, landing with the final migration, keeps future surfaces from re-implementing the lookup.

**Tech Stack:** Flutter, Riverpod 3, Drift, `flutter_localizations` with ARB files in 11 locales.

**Spec:** `docs/superpowers/specs/2026-09-22-equipment-service-status-everywhere-design.md`

## As Shipped

This plan records what was planned. Five steps changed once the code was
read, and are marked inline below. The spec's "As shipped" notes give the
same reasoning at design level.

1. **Task 1, short-form strings.** One generic `equipment_service_shortRemaining`
   (`"{count} {unit} left"`) became seven per-unit keys
   (`equipment_service_shortDives` and friends, `"in {count} {unit noun}"`).
   The only existing per-unit string is a form-field label, so the generic
   form rendered "in 3 Interval (dives)", and a unit noun cannot be composed
   generically across locales anyway.
2. **Task 6 Step 6, the pre-dive N+1: deferred.** Both batch providers would
   have hidden clocks in a safety checklist: the rollup carries only the
   worst clock where the tile shows every one, and `activeEquipmentClocksProvider`
   is active-only where the start sheet offers all gear. Filed separately.
3. **Task 6 Step 7, three surfaces: not migrated.** `TripServiceAlertBanner`
   keeps its trip-relative due-soon wording (it adopts the shared overdue
   key); `GaugeStrip` names the gear item rather than the service kind; the
   equipment detail header keeps its page-level banner.
4. **Task 7, the guard: changed target.** Shipped as
   `test/architecture/service_status_wording_single_source_test.dart`,
   guarding the status *wording* rather than reads of
   `equipmentRollupClockProvider`. Six of seven readers of that map are
   legitimate non-rendering uses, so a read guard would have allowlisted
   almost everything it existed to catch.
5. **Task 5, adoption tests.** No single `service_status_adoption_test.dart`;
   coverage landed per surface in `equipment_picker_service_status_test.dart`,
   `dive_gear_service_status_test.dart`,
   `equipment_surfaces_service_status_test.dart` and the scrubber card test,
   with the chip-avatar mechanism covered in the indicator's own tests.

## Global Constraints

- Issue link: every commit body and the PR description must reference `#2260`. The PR description must contain `Closes #2260`.
- No output written to this repository or to GitHub may name the authoring tool or model in any form. This covers co-author trailers, generated-with lines, session URLs, and any "addressed by" line, in commits, PR titles and bodies, issue comments and review replies. See the Attribution section of CLAUDE.md.
- Never use the em-dash character (U+2014) in any file, commit message, or PR text. En-dashes as sentence punctuation, double hyphens and spaced hyphens used as prose punctuation are equally forbidden.
- No emojis in code, comments, or documentation.
- Immutability always. Never mutate objects or arrays in place.
- Anything displaying units must respect the active diver's unit settings, via `UnitFormatter(ref.watch(settingsProvider))`.
- All 11 ARB files must be updated together: `app_en.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`. Only `app_en.arb` is alphabetical; in the other ten, anchor the insert on a neighbouring key.
- Run `dart format .` after completing any task.
- Files: 200 to 400 lines typical, 800 maximum.
- TDD: write the failing test first, watch it fail, then implement.

---

### Task 1: Short trigger formatter and its strings

A service clock can tick on a date, on dives, on hours, and on five other exposure units, and can have several triggers at once. The existing `formatServiceTriggerText` joins every configured trigger with a middle dot, which is correct for a roomy card and far too long for a one-line chip or a tooltip. This task adds the short form.

**Selection rule (implement exactly):** if `status.dueDate != null`, use the date trigger. Otherwise use the usage unit with the smallest `remaining / interval` ratio, ties broken by `ExposureUnit.values` order. `ExposureUnit.days` never produces a usage line.

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/service_trigger_text.dart`
- Modify: `lib/l10n/arb/app_en.arb` and the other ten ARB files
- Test: `test/features/equipment/presentation/widgets/service_trigger_short_test.dart`

**Interfaces:**
- Consumes: `ServiceClockStatus` (`lib/features/equipment/domain/entities/service_clock_status.dart`), `ClockUsage` with `.interval`, `.since`, `.remaining`; `UnitFormatter` (`lib/core/utils/unit_formatter.dart`); `ExposureUnitDisplay.intervalLabel(l10n)`.
- Produces:
  ```dart
  String formatServiceTriggerShort(
    BuildContext context, {
    required UnitFormatter units,
    required DateTime now,
    required ServiceClockStatus status,
  });
  ```
  Task 2 calls this for the `compact` and `dot` densities.

- [ ] **Step 1: Add the two new ARB keys to `app_en.arb`**

Insert alphabetically, next to the existing `equipment_serviceClocks_*` keys:

```json
  "equipment_service_shortRemaining": "{count} {unit} left",
  "@equipment_service_shortRemaining": {
    "description": "Short form of a usage-based service clock's remaining budget, for a one-line chip or tooltip. {unit} is an already-localized unit noun such as dives or salt hours.",
    "placeholders": {
      "count": { "type": "String" },
      "unit": { "type": "String" }
    }
  },
  "equipment_service_overdue": "{kind} overdue",
  "@equipment_service_overdue": {
    "description": "One-line service status for an overdue clock. {kind} is the service kind name, or component and kind when the clock belongs to a part.",
    "placeholders": { "kind": { "type": "String" } }
  },
  "equipment_service_dueRelative": "{kind} due {relative}",
  "@equipment_service_dueRelative": {
    "description": "One-line service status for a due-soon clock. {relative} is a short trigger such as in 12d or 3 dives left.",
    "placeholders": {
      "kind": { "type": "String" },
      "relative": { "type": "String" }
    }
  },
```

Note on `equipment_service_shortRemaining`: `{unit}` is an already-localized noun, so a locale with grammatical gender or case may need its own phrasing. If a translation cannot be made natural, fall back to per-unit keys mirroring `equipment_serviceClocks_divesUsedAndLeft` and friends. Do not leave a wrong translation in place.

- [ ] **Step 2: Add the same three keys to the other ten ARB files**

Only `app_en.arb` is alphabetical. In `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb` and `app_zh.arb`, locate the existing `equipment_serviceClocks_overdueSince` key and insert the three new keys immediately after it. Translate each value; do not copy the English through. Keep each locale's own word order and separators.

- [ ] **Step 3: Regenerate localizations**

```bash
flutter gen-l10n
```

Expected: `lib/l10n/arb/app_localizations.dart` gains `equipment_service_shortRemaining`, `equipment_service_overdue` and `equipment_service_dueRelative`.

- [ ] **Step 4: Write the failing test**

Create `test/features/equipment/presentation/widgets/service_trigger_short_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_trigger_text.dart';
import 'package:submersion/features/settings/domain/entities/app_settings.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final t0 = DateTime(2025, 1, 1);
  final now = DateTime(2026, 1, 1);

  ServiceClockStatus status({
    DateTime? dueDate,
    Map<ExposureUnit, ClockUsage> usageByUnit = const {},
    ServiceClockSeverity severity = ServiceClockSeverity.dueSoon,
  }) => ServiceClockStatus(
    schedule: ServiceSchedule(
      id: 's1',
      equipmentId: 'e1',
      serviceKindId: 'k1',
      createdAt: t0,
      updatedAt: t0,
    ),
    kind: ServiceKind(
      id: 'k1',
      name: 'General service',
      defaultIntervalDays: 365,
      isBuiltIn: true,
      createdAt: t0,
      updatedAt: t0,
    ),
    anchor: t0,
    dueDate: dueDate,
    usageByUnit: usageByUnit,
    severity: severity,
    now: now,
  );

  /// Pumps a throwaway widget so the formatter can read its l10n and theme.
  Future<String> render(
    WidgetTester tester,
    ServiceClockStatus s, {
    Locale locale = const Locale('en'),
  }) async {
    late String out;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            out = formatServiceTriggerShort(
              context,
              units: const UnitFormatter(AppSettings()),
              now: now,
              status: s,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    return out;
  }

  testWidgets('a date clock reads as a short relative day count', (
    tester,
  ) async {
    final text = await render(
      tester,
      status(dueDate: DateTime(2026, 1, 13)),
    );
    expect(text, 'in 12d');
  });

  testWidgets('a dives clock reads as a short remaining count', (tester) async {
    final text = await render(
      tester,
      status(
        usageByUnit: {
          ExposureUnit.dives: const ClockUsage(interval: 50, since: 47),
        },
      ),
    );
    expect(text, '3 dives left');
  });

  testWidgets('an hours clock keeps one fractional digit', (tester) async {
    final text = await render(
      tester,
      status(
        usageByUnit: {
          ExposureUnit.hours: const ClockUsage(interval: 100, since: 95.5),
        },
      ),
    );
    expect(text, '4.5 hours left');
  });

  testWidgets('a date trigger wins when the clock also ticks on dives', (
    tester,
  ) async {
    final text = await render(
      tester,
      status(
        dueDate: DateTime(2026, 1, 13),
        usageByUnit: {
          ExposureUnit.dives: const ClockUsage(interval: 50, since: 47),
        },
      ),
    );
    expect(text, 'in 12d');
  });

  testWidgets('with no date, the unit closest to expiry wins', (tester) async {
    final text = await render(
      tester,
      status(
        usageByUnit: {
          // 40 percent left.
          ExposureUnit.dives: const ClockUsage(interval: 50, since: 30),
          // 10 percent left, so this one is reported.
          ExposureUnit.hours: const ClockUsage(interval: 100, since: 90),
        },
      ),
    );
    expect(text, '10.0 hours left');
  });

  testWidgets('a spent usage clock never reports a negative remainder', (
    tester,
  ) async {
    final text = await render(
      tester,
      status(
        usageByUnit: {
          ExposureUnit.dives: const ClockUsage(interval: 50, since: 62),
        },
        severity: ServiceClockSeverity.overdue,
      ),
    );
    expect(text, '0 dives left');
  });

  testWidgets('a clock with no trigger at all yields an empty string', (
    tester,
  ) async {
    final text = await render(tester, status());
    expect(text, '');
  });
}
```

- [ ] **Step 5: Run the test to verify it fails**

```bash
flutter test test/features/equipment/presentation/widgets/service_trigger_short_test.dart
```

Expected: FAIL, `formatServiceTriggerShort` is not defined.

- [ ] **Step 6: Implement the formatter**

Append to `lib/features/equipment/presentation/widgets/service_trigger_text.dart`:

```dart
/// The single most urgent trigger for [status], in short form, for a
/// one-line chip or a tooltip where [formatServiceTriggerText]'s joined
/// line does not fit.
///
/// A date trigger wins whenever the clock has one, since most clocks are
/// date-based and a day count is the form divers read fastest. With no
/// date, the usage unit with the least budget left wins, measured as a
/// fraction of its interval so units of different magnitudes compare;
/// [ExposureUnit.values] order breaks ties. Returns an empty string for a
/// clock with no configured trigger at all.
String formatServiceTriggerShort(
  BuildContext context, {
  required UnitFormatter units,
  required DateTime now,
  required ServiceClockStatus status,
}) {
  final l10n = context.l10n;
  final dueDate = status.dueDate;
  if (dueDate != null) {
    final days = dueDate.difference(now).inDays;
    return l10n.common_relativeTime_inDays(days < 0 ? 0 : days);
  }

  ExposureUnit? pick;
  double? bestRatio;
  for (final unit in ExposureUnit.values) {
    if (unit == ExposureUnit.days) continue;
    final usage = status.usageByUnit[unit];
    if (usage == null || usage.interval <= 0) continue;
    final ratio = usage.remaining / usage.interval;
    if (bestRatio == null || ratio < bestRatio) {
      bestRatio = ratio;
      pick = unit;
    }
  }
  if (pick == null) return '';

  final usage = status.usageByUnit[pick]!;
  // A spent clock is overdue, not negatively remaining; the same clamp
  // formatServiceTriggerText applies.
  final remaining = usage.remaining < 0 ? 0.0 : usage.remaining;
  return l10n.equipment_service_shortRemaining(
    pick.isFractional
        ? remaining.toStringAsFixed(1)
        : remaining.round().toString(),
    pick.intervalLabel(l10n),
  );
}
```

- [ ] **Step 7: Run the test to verify it passes**

```bash
flutter test test/features/equipment/presentation/widgets/service_trigger_short_test.dart
```

Expected: PASS, 7 tests.

- [ ] **Step 8: Add the plural-category regression test**

The CLDR `one` category covers zero in French and Portuguese, so a count of zero can render the singular branch. Append to the same test file:

```dart
  testWidgets('a zero-day count does not render a stray singular in fr', (
    tester,
  ) async {
    final text = await render(
      tester,
      status(dueDate: now),
      locale: const Locale('fr'),
    );
    // Whatever the French wording, the count must appear as the digit 0
    // and must not be dropped by a hardcoded singular branch.
    expect(text, contains('0'));
  });
```

- [ ] **Step 9: Run the whole file, format, and commit**

```bash
flutter test test/features/equipment/presentation/widgets/service_trigger_short_test.dart
dart format .
git add lib/features/equipment/presentation/widgets/service_trigger_text.dart lib/l10n/arb test/features/equipment/presentation/widgets/service_trigger_short_test.dart
git commit -m "feat(equipment): short service trigger formatter for one-line status

Refs #2260"
```

---

### Task 2: The shared indicator widget

**Files:**
- Create: `lib/features/equipment/presentation/widgets/service_status_indicator.dart`
- Test: `test/features/equipment/presentation/widgets/service_status_indicator_test.dart`

**Interfaces:**
- Consumes: `RollupClock` typedef and `equipmentRollupClockProvider` from `lib/features/equipment/presentation/providers/equipment_component_providers.dart`; `serviceSeveritySwatch` from `lib/features/equipment/presentation/utils/service_severity_colors.dart`; `formatServiceTriggerShort` and `formatServiceTriggerText` from Task 1's file.
- Produces:
  ```dart
  enum ServiceIndicatorDensity { full, compact, dot }

  class ServiceStatusIndicator extends ConsumerWidget {
    const ServiceStatusIndicator({
      super.key,
      required this.clock,
      required this.subjectId,
      this.density = ServiceIndicatorDensity.compact,
    });
    final RollupClock? clock;
    final String subjectId;
    final ServiceIndicatorDensity density;
  }

  /// Convenience for a surface that has an id and wants the widget to do
  /// its own map lookup.
  class ServiceStatusIndicatorFor extends ConsumerWidget {
    const ServiceStatusIndicatorFor({
      super.key,
      required this.equipmentId,
      this.density = ServiceIndicatorDensity.compact,
      this.enabled = true,
    });
    final String equipmentId;
    final ServiceIndicatorDensity density;
    final bool enabled;
  }
  ```
  Tasks 3 through 8 use `ServiceStatusIndicatorFor` at surfaces that hold only an id, and `ServiceStatusIndicator` where the caller already watched the map.

- [ ] **Step 1: Write the failing test**

Create `test/features/equipment/presentation/widgets/service_status_indicator_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  final t0 = DateTime(2025, 1, 1);
  final now = DateTime(2026, 1, 1);

  RollupClock clock({
    String ownerId = 'reg',
    String ownerName = 'Cold water reg',
    ServiceClockSeverity severity = ServiceClockSeverity.overdue,
    DateTime? dueDate,
  }) => (
    ownerId: ownerId,
    ownerName: ownerName,
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's1',
        equipmentId: ownerId,
        serviceKindId: 'k1',
        createdAt: t0,
        updatedAt: t0,
      ),
      kind: ServiceKind(
        id: 'k1',
        name: 'General service',
        defaultIntervalDays: 365,
        isBuiltIn: true,
        createdAt: t0,
        updatedAt: t0,
      ),
      anchor: t0,
      dueDate: dueDate ?? DateTime(2025, 6, 1),
      severity: severity,
      now: now,
    ),
  );

  Widget wrap(Widget child, {Map<String, RollupClock> map = const {}}) =>
      ProviderScope(
        overrides: [
          equipmentRollupClockProvider.overrideWith((ref) async => map),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  testWidgets('renders nothing for a null clock', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ServiceStatusIndicator(clock: null, subjectId: 'reg'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('renders nothing for an ok clock', (tester) async {
    await tester.pumpWidget(
      wrap(
        ServiceStatusIndicator(
          clock: clock(severity: ServiceClockSeverity.ok),
          subjectId: 'reg',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('compact names the kind alone when the subject owns the clock', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(ServiceStatusIndicator(clock: clock(), subjectId: 'reg')),
    );
    await tester.pumpAndSettle();
    expect(find.text('General service overdue'), findsOneWidget);
  });

  testWidgets('compact names the owning part when the clock rolls up', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ServiceStatusIndicator(
          clock: clock(ownerId: 'hose', ownerName: 'Necklace hose'),
          subjectId: 'reg',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Necklace hose'),
      findsOneWidget,
      reason: 'a rolled-up clock must say which part is overdue',
    );
  });

  testWidgets('a due-soon clock reads with its relative trigger', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ServiceStatusIndicator(
          clock: clock(
            severity: ServiceClockSeverity.dueSoon,
            dueDate: DateTime(2026, 1, 13),
          ),
          subjectId: 'reg',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('General service due in 12d'), findsOneWidget);
  });

  testWidgets('the dot density draws no text but carries a semantics label', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ServiceStatusIndicator(
          clock: clock(),
          subjectId: 'reg',
          density: ServiceIndicatorDensity.dot,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
    expect(
      find.bySemanticsLabel('General service overdue'),
      findsOneWidget,
      reason: 'colour alone must never carry the signal',
    );
  });

  testWidgets('ServiceStatusIndicatorFor looks the clock up by id', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ServiceStatusIndicatorFor(equipmentId: 'reg'),
        map: {'reg': clock()},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('General service overdue'), findsOneWidget);
  });

  testWidgets('ServiceStatusIndicatorFor renders nothing when disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ServiceStatusIndicatorFor(equipmentId: 'reg', enabled: false),
        map: {'reg': clock()},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/equipment/presentation/widgets/service_status_indicator_test.dart
```

Expected: FAIL, `service_status_indicator.dart` does not exist.

- [ ] **Step 3: Implement the widget**

Create `lib/features/equipment/presentation/widgets/service_status_indicator.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/service_severity_colors.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_trigger_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How much room the host surface has for the service signal.
enum ServiceIndicatorDensity {
  /// Kind label plus the full trigger line. For detail headers and cards.
  full,

  /// One line naming the kind and its urgency. For list and picker rows.
  compact,

  /// A coloured dot; the compact wording moves into the tooltip and the
  /// semantics label. For chips, dense rows and tree rows.
  dot,
}

/// The one place the app decides how a service clock looks.
///
/// Renders nothing at all for a null or ok clock, so a caller can pass the
/// raw map lookup without filtering first. Service state only: arbitration
/// against a competing condition finding stays with `pickBadgeSource`, and
/// a caller with a contested badge slot decides which to pass here.
class ServiceStatusIndicator extends ConsumerWidget {
  const ServiceStatusIndicator({
    super.key,
    required this.clock,
    required this.subjectId,
    this.density = ServiceIndicatorDensity.compact,
  });

  final RollupClock? clock;

  /// The item being rendered. When the clock's owner is someone else, the
  /// label names that part, matching the equipment list's rollup badge.
  final String subjectId;

  final ServiceIndicatorDensity density;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = clock;
    if (c == null || c.status.severity == ServiceClockSeverity.ok) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final swatch = serviceSeveritySwatch(
      StatusColors.of(context),
      c.status.severity,
    );

    final kindLabel = c.ownerId == subjectId
        ? c.status.kind.name
        : l10n.equipment_components_rollupClock(
            c.ownerName,
            c.status.kind.name,
          );

    final overdue = c.status.severity == ServiceClockSeverity.overdue;
    final line = overdue
        ? l10n.equipment_service_overdue(kindLabel)
        : l10n.equipment_service_dueRelative(
            kindLabel,
            formatServiceTriggerShort(
              context,
              units: units,
              now: c.status.now,
              status: c.status,
            ),
          );

    switch (density) {
      case ServiceIndicatorDensity.full:
        return Semantics(
          label: line,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: swatch?.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                formatServiceTriggerText(
                  context,
                  units: units,
                  now: c.status.now,
                  dueDate: c.status.dueDate,
                  usageByUnit: c.status.usageByUnit,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );

      case ServiceIndicatorDensity.compact:
        return Semantics(
          label: line,
          child: Text(
            line,
            style: theme.textTheme.labelSmall?.copyWith(
              color: swatch?.accent,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );

      case ServiceIndicatorDensity.dot:
        return Tooltip(
          message: line,
          child: Semantics(
            label: line,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: serviceSeverityDotColor(context, c.status.severity),
              ),
            ),
          ),
        );
    }
  }
}

/// [ServiceStatusIndicator] for a surface that holds an equipment id rather
/// than a clock. Watches the batch rollup map, so a list of a thousand rows
/// still costs one provider, not one per row.
///
/// [enabled] is how a surface expresses the current-facing rule: a logged
/// past dive passes false, so its gear tree stays a faithful record of that
/// dive rather than a statement about today.
class ServiceStatusIndicatorFor extends ConsumerWidget {
  const ServiceStatusIndicatorFor({
    super.key,
    required this.equipmentId,
    this.density = ServiceIndicatorDensity.compact,
    this.enabled = true,
  });

  final String equipmentId;
  final ServiceIndicatorDensity density;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) return const SizedBox.shrink();
    final clock = ref.watch(equipmentRollupClockProvider).value?[equipmentId];
    return ServiceStatusIndicator(
      clock: clock,
      subjectId: equipmentId,
      density: density,
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/equipment/presentation/widgets/service_status_indicator_test.dart
```

Expected: PASS, 8 tests.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/equipment/presentation/widgets/service_status_indicator.dart test/features/equipment/presentation/widgets/service_status_indicator_test.dart
git commit -m "feat(equipment): shared service status indicator in three densities

Refs #2260"
```

---

### Task 3: Dive surfaces and the current-facing rule

This is the gap the issue exists for. A diver choosing gear gets the warning at the moment it is actionable, and a logged past dive stays clean.

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_gear_tree_view.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:4651`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart:3457`
- Modify: `lib/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart:233`
- Modify: `lib/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart:127`
- Modify: `lib/features/dive_log/presentation/widgets/tank_editor.dart:614`
- Test: `test/features/dive_log/presentation/widgets/dive_gear_service_status_test.dart`
- Test: `test/features/dive_log/presentation/widgets/equipment_picker_service_status_test.dart`

**Interfaces:**
- Consumes: `ServiceStatusIndicatorFor` and `ServiceIndicatorDensity` from Task 2.
- Produces: `DiveGearTreeView` gains `final bool showServiceStatus;` defaulting to `false`.

- [ ] **Step 1: Write the failing gear-tree test**

Create `test/features/dive_log/presentation/widgets/dive_gear_service_status_test.dart`. Build the same `wrap` and `clock` helpers as Task 2's test (repeated deliberately, since tasks are read out of order), then:

```dart
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Cold water reg',
    type: EquipmentType.regulator,
  );
  const links = [GearLink(item: reg)];

  testWidgets('a dive being edited shows overdue gear', (tester) async {
    await tester.pumpWidget(
      wrap(
        const DiveGearTreeView(links: links, showServiceStatus: true),
        map: {'reg': clock()},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('General service overdue'), findsOneWidget);
  });

  testWidgets('a logged past dive stays clean', (tester) async {
    await tester.pumpWidget(
      wrap(
        const DiveGearTreeView(links: links, showServiceStatus: false),
        map: {'reg': clock()},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('General service overdue'), findsNothing);
  });
```

`DiveGearTreeView` is a `ConsumerStatefulWidget` that watches
`equipmentArrangementProvider`, `equipmentSetsProvider`,
`equipmentComponentsIndexProvider` and `activeComponentIdsProvider`, so the
`wrap` helper must override all four in addition to
`equipmentRollupClockProvider` and `settingsProvider`, or the pump throws.

- [ ] **Step 2: Run the tests to verify they fail**

```bash
flutter test test/features/dive_log/presentation/widgets/dive_gear_service_status_test.dart
```

Expected: FAIL, `showServiceStatus` is not a parameter of `DiveGearTreeView`.

- [ ] **Step 3: Add the parameter and render the dot**

In `dive_gear_tree_view.dart`, add the field:

```dart
  /// Whether this tree is a present-tense view of the gear. Dive edit and a
  /// planned dive pass true; a logged past dive passes false, so its record
  /// does not gain a mark about today's service state.
  final bool showServiceStatus;
```

and default it to `false` in the constructor. In the row builder, alongside the existing `rowTrailing` usage that renders `ObservationStatusChip`, add:

```dart
ServiceStatusIndicatorFor(
  equipmentId: link.item.id,
  density: ServiceIndicatorDensity.dot,
  enabled: showServiceStatus,
),
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
flutter test test/features/dive_log/presentation/widgets/dive_gear_service_status_test.dart
```

Expected: PASS, 2 tests.

- [ ] **Step 5: Wire the two call sites**

In `dive_edit_page.dart:3457`, pass `showServiceStatus: true`.

In `dive_detail_page.dart:4651`, pass `showServiceStatus: dive.diveDateTime.isAfter(DateTime.now())`, so planned and future dives signal and logged dives do not.

- [ ] **Step 6: Adopt the three pickers**

In `equipment_picker_sheet.dart:233`, `equipment_set_picker_sheet.dart:127` and `tank_editor.dart:614`, add to each row's trailing slot:

```dart
ServiceStatusIndicatorFor(
  equipmentId: item.id,
  density: ServiceIndicatorDensity.compact,
),
```

For `equipment_set_picker_sheet.dart`, whose subtitle joins member names rather than listing rows, use `ServiceIndicatorDensity.dot` on the set tile, driven by whichever member has the worst clock; if that needs more than a lookup, render one dot per member name instead.

- [ ] **Step 7: Write and run the picker test**

Create `test/features/dive_log/presentation/widgets/equipment_picker_service_status_test.dart` asserting that a picker row for an overdue item shows `find.text('General service overdue')`, and that a row for an item absent from the map shows no status text.

```bash
flutter test test/features/dive_log/presentation/widgets/equipment_picker_service_status_test.dart
```

Expected: PASS.

- [ ] **Step 8: Repair the existing dive_log tests**

Adding a provider dependency breaks every existing test that pumps these widgets without an override.

```bash
flutter test test/features/dive_log/
```

For each failure, add to that test's `ProviderScope.overrides`:

```dart
equipmentRollupClockProvider.overrideWith((ref) async => const {}),
```

Re-run until green. Do not skip a test to make it pass.

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add lib/features/dive_log test/features/dive_log
git commit -m "feat(dive-log): service status on gear trees and equipment pickers

Refs #2260"
```

---

### Task 4: Equipment feature adoption

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/component_picker_sheet.dart:290`
- Modify: `lib/features/equipment/presentation/widgets/part_of_section.dart:76`
- Modify: `lib/features/equipment/presentation/widgets/installed_in_row.dart:118`
- Modify: `lib/features/equipment/presentation/pages/equipment_set_detail_page.dart:295`
- Modify: `lib/features/equipment/presentation/pages/equipment_set_edit_page.dart:409`
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_page.dart:415`
- Test: `test/features/equipment/presentation/widgets/equipment_pickers_service_status_test.dart`

**Interfaces:**
- Consumes: `ServiceStatusIndicatorFor`, `ServiceIndicatorDensity` from Task 2.
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

Create `test/features/equipment/presentation/widgets/equipment_pickers_service_status_test.dart` with one `testWidgets` per surface above, each pumping the widget with `{'reg': clock()}` and asserting the overdue wording is found, plus one asserting an item absent from the map renders no status.

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/features/equipment/presentation/widgets/equipment_pickers_service_status_test.dart
```

Expected: FAIL on every test, no indicator rendered.

- [ ] **Step 3: Adopt each surface**

In each row builder listed above, add to the trailing slot:

```dart
ServiceStatusIndicatorFor(
  equipmentId: item.id,
  density: ServiceIndicatorDensity.compact,
),
```

For `equipment_edit_page.dart:415`, which is a `DropdownButtonFormField`, put the indicator inside each `DropdownMenuItem`'s child `Row` at `ServiceIndicatorDensity.dot`, since a dropdown item has no trailing slot and little width.

For `installed_in_row.dart:118`, the subject is the host item, so pass the host's id.

- [ ] **Step 4: Run to verify the tests pass**

```bash
flutter test test/features/equipment/presentation/widgets/equipment_pickers_service_status_test.dart
```

Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/equipment test/features/equipment
git commit -m "feat(equipment): service status on component pickers and set pages

Refs #2260"
```

---

### Task 5: Remaining feature adoption

**Files:**
- Modify: `lib/features/pre_dive/presentation/widgets/start_session_sheet.dart:221`
- Modify: `lib/features/trips/presentation/widgets/trip_scrubber_margin_card.dart:126`
- Modify: `lib/features/safety/presentation/pages/incident_edit_page.dart:284` and `:440`
- Modify: `lib/features/dive_computer/presentation/pages/device_detail_page.dart:1048`
- Modify: `lib/features/weight_planner/presentation/widgets/rig_composer.dart:172`
- Modify: `lib/features/dive_planner/presentation/widgets/plan_gear_weights_section.dart:170`
- Modify: `lib/features/settings/presentation/pages/retype_other_gear_page.dart:108`
- Test: `test/features/equipment/presentation/widgets/service_status_adoption_test.dart`

**Interfaces:**
- Consumes: `ServiceStatusIndicatorFor`, `ServiceIndicatorDensity` from Task 2.
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

Create `test/features/equipment/presentation/widgets/service_status_adoption_test.dart` with one `testWidgets` per surface, pumping it with an overdue map and asserting the signal is present by semantics label.

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/features/equipment/presentation/widgets/service_status_adoption_test.dart
```

Expected: FAIL on every test.

- [ ] **Step 3: Adopt each surface**

Rows and list tiles take `ServiceIndicatorDensity.compact`. The chip surfaces, `rig_composer.dart` and `plan_gear_weights_section.dart`, take `ServiceIndicatorDensity.dot` placed inside the chip's `avatar` slot, so a chip never grows wider:

```dart
InputChip(
  avatar: ServiceStatusIndicatorFor(
    equipmentId: item.id,
    density: ServiceIndicatorDensity.dot,
  ),
  // existing label and callbacks unchanged
)
```

- [ ] **Step 4: Run to verify the tests pass**

```bash
flutter test test/features/equipment/presentation/widgets/service_status_adoption_test.dart
```

Expected: PASS.

- [ ] **Step 5: Repair the affected features' existing tests**

```bash
flutter test test/features/pre_dive/ test/features/trips/ test/features/safety/ test/features/dive_computer/ test/features/weight_planner/ test/features/dive_planner/ test/features/settings/
```

Add `equipmentRollupClockProvider.overrideWith((ref) async => const {})` to each failing test's overrides until green.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib test
git commit -m "feat(equipment): service status on pre-dive, trips, safety and planner gear

Refs #2260"
```

---

### Task 6: Migrate the working surfaces and fold in the three fixes

Done last, behind the tests that already guard these surfaces, so a regression in something that works today is caught rather than shipped.

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart:1267-1330`
- Modify: `lib/features/equipment/presentation/widgets/dense_equipment_list_tile.dart:160-180`
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart:414`
- Modify: `lib/features/equipment/presentation/widgets/components_card.dart:94`
- Modify: `lib/features/equipment/presentation/widgets/children_card.dart:50`
- Modify: `lib/features/equipment/presentation/widgets/equipment_summary_widget.dart:22`
- Modify: `lib/features/trips/presentation/widgets/trip_service_alert_banner.dart:127`
- Modify: `lib/features/pre_dive/presentation/widgets/session_item_tile.dart:72-87`
- Modify: `lib/features/dashboard/presentation/widgets/gauge_strip.dart:88`

**Interfaces:**
- Consumes: `ServiceStatusIndicator` from Task 2.
- Produces: nothing new.

- [ ] **Step 1: Run the existing guard tests and record the baseline**

```bash
flutter test test/features/equipment/presentation/widgets/equipment_tile_rollup_badge_test.dart test/features/equipment/presentation/widgets/equipment_tile_service_badge_test.dart test/features/equipment/presentation/widgets/dense_equipment_list_tile_test.dart
```

Expected: PASS. These must still pass after the migration, unchanged where possible.

- [ ] **Step 2: Replace the hand-rolled badge in the two list tiles**

In `equipment_list_content.dart`, inside `_buildTrailing`, replace the `if (worstClock != null) { ... }` block's inner `Text(...)` with:

```dart
ServiceStatusIndicator(
  clock: worstClock,
  subjectId: item.id,
),
```

keeping the surrounding `Column` with `typeLabel` and the `SizedBox(height: 2)`. Do the same in `dense_equipment_list_tile.dart`'s `_buildServiceStatus`.

- [ ] **Step 3: Run the guard tests**

```bash
flutter test test/features/equipment/presentation/widgets/
```

Expected: PASS. If a test now fails on exact wording, the migration changed user-visible text; reconcile the widget rather than loosening the test.

- [ ] **Step 4: Fix the Components and Children card provider drift**

In `components_card.dart:94` and `children_card.dart:50`, replace

```dart
ref.watch(equipmentWorstClockProvider).value ?? const {};
```

with

```dart
ref.watch(equipmentRollupClockProvider).value ?? const {};
```

and adjust the dot call sites, which now read `.status.severity` off a `RollupClock` rather than a `DueClock`. Add a test asserting that a part whose own sub-part is overdue now shows a dot in the Components card.

- [ ] **Step 5: Give the summary widget per-row severity**

In `equipment_summary_widget.dart:22`, switch the Service Due list from `serviceDueEquipmentProvider` to `dueClocksProvider`, so each row has its own `DueClock` and can render `ServiceStatusIndicator`. Add a test asserting an overdue row and a due-soon row render differently.

- [ ] **Step 6: Remove the pre-dive N+1** *(Deferred, see As Shipped item 2.)*

In `session_item_tile.dart:72-87`, replace the per-row `serviceClockStatusesProvider(equipmentId)` watch with a lookup into `equipmentRollupClockProvider`. Keep the frozen `overdueServices` path untouched: a resolved item must keep rendering its frozen snapshot, not today's live state.

- [ ] **Step 7: Migrate the remaining three surfaces** *(Not done, see As Shipped item 3.)*

`trip_service_alert_banner.dart:127`, `gauge_strip.dart:88` and `equipment_detail_page.dart:414` each render their own wording; replace with `ServiceStatusIndicator` at `compact` for the banner and gauges, `full` for the detail header.

- [ ] **Step 8: Retire the two duplicated ARB keys**

Delete `equipment_list_worstClock` and `trips_serviceAlert_overdue`, with their `@` metadata, from all 11 ARB files. Confirm no Dart call site remains:

```bash
grep -rn "equipment_list_worstClock\|trips_serviceAlert_overdue" lib/ test/
```

Expected: no output. Then `flutter gen-l10n`.

- [ ] **Step 9: Run the full affected suites**

```bash
flutter test test/features/equipment/ test/features/trips/ test/features/pre_dive/ test/features/dashboard/
```

Expected: PASS.

- [ ] **Step 10: Format and commit**

```bash
dart format .
git add lib test
git commit -m "refactor(equipment): migrate existing service badges onto the shared indicator

Fixes the Components card reading own-clocks while the list read the rollup,
gives the summary widget per-row severity, and drops a per-row provider from
the pre-dive checklist.

Refs #2260"
```

---

### Task 7: Adoption guard, full verification, and the PR

*(The guard shipped with a different target; see As Shipped item 4.)*

The guard lands with the last migration, never before it, so no window exists in which the guard and a violating surface coexist and redden main for every open PR.

**Files:**
- Create: `test/architecture/service_status_indicator_adoption_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

- [ ] **Step 1: Write the guard**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The service signal is rendered in exactly one place, so its wording and
/// its colours cannot drift apart. Two files rendering the same thing is
/// how the Components card and the equipment list came to disagree about
/// whether a sub-part's overdue state counts.
void main() {
  test('only the shared indicator renders from the rollup clock map', () {
    const allowed = {
      'lib/features/equipment/presentation/widgets/service_status_indicator.dart',
      'lib/features/equipment/presentation/providers/equipment_component_providers.dart',
    };
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (allowed.contains(path)) continue;
      final source = entity.readAsStringSync();
      if (source.contains('equipmentRollupClockProvider')) {
        offenders.add(path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'render service status through ServiceStatusIndicator or '
          'ServiceStatusIndicatorFor instead of reading the rollup map '
          'directly',
    );
  });
}
```

- [ ] **Step 2: Run the guard and fix what it finds**

```bash
flutter test test/architecture/service_status_indicator_adoption_test.dart
```

Expected: FAIL initially, listing the surfaces from Task 6 that still watch the provider directly. Route each through `ServiceStatusIndicatorFor` until the guard passes. Where a surface genuinely needs the raw clock for something other than rendering, add it to `allowed` with a comment saying why.

- [ ] **Step 3: Run the whole architecture suite**

The suite scans all of `lib/`, and affected-directory runs never include it, so the new `lib/` file means running it explicitly.

```bash
flutter test test/architecture/
```

Expected: PASS.

- [ ] **Step 4: Verify l10n is not stale**

```bash
flutter gen-l10n
git diff --stat lib/l10n/arb/app_localizations
```

Expected: no diff. A diff here means generated l10n was committed stale and the pre-push hook will reject it.

- [ ] **Step 5: Analyze the whole project**

Never pipe this; a pipe masks the exit status. Infos are fatal in CI.

```bash
flutter analyze
```

Expected: no issues.

- [ ] **Step 6: Run the full suite once**

```bash
dart format .
flutter test
```

Expected: PASS. One full run is sufficient. Do not overlap it with another local run.

- [ ] **Step 7: Commit and push**

```bash
git add test/architecture/service_status_indicator_adoption_test.dart
git commit -m "test(equipment): guard single-source rendering of service status

Refs #2260"
git push -u origin ericgriffin/equipment-overdue-service-indicator-3bce1a
```

- [ ] **Step 8: Open the PR**

The body must contain `Closes #2260` with the keyword directly before the number, or the issue will not close on merge and the PR Issue Link check will block. No attribution, no session URL, no em-dashes.

```bash
gh pr create --repo submersion-app/submersion --title "Show service status wherever a piece of equipment is shown" --body-file <path to a prepared body file>
```

---

## Self-Review

**Spec coverage.** Shared widget: Task 2. Short formatter: Task 1. Current-facing rule: Task 3 Steps 3 and 5. Adopt list: Tasks 3, 4, 5. Migrate list: Task 6. Fix 1 (Components and Children drift): Task 6 Step 4. Fix 2 (summary severity): Task 6 Step 5. Fix 3 (pre-dive N+1): Task 6 Step 6. Localisation: Task 1 Steps 1 and 2, retirement in Task 6 Step 8. Architecture guard: Task 7. Existing-test fallout: Task 3 Step 8 and Task 5 Step 5. Excluded surfaces are excluded by omission and named in the spec.

**Gap found and closed.** The spec's `full` density claims it matches `ServiceClocksCard`; Task 2 Step 3 renders the long trigger line beneath the label to satisfy that.
