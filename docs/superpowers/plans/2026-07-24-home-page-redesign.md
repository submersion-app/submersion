# Home Page Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Home tab (Dashboard) as a monitor-first, responsive card grid that is dense on desktop and identical in content/order on phone, per the approved spec at `docs/superpowers/specs/2026-07-24-home-page-redesign-design.md`.

**Architecture:** A new `DashboardGrid` widget lays out an ordered list of blocks (full-width, one-third, or lead+side group) into 1/2/3 columns keyed off the existing `ResponsiveBreakpoints`. A new always-on `GaugeStrip` (plus a conditional `UrgentBanner`) replaces `ActivityStatsBar`, `AlertsCard`, and `ServiceDueCard`. `HeroHeader` gains a left logo and subdued center stats at desktop widths. Five new cards (milestones, photo ribbon, on-this-day, year-in-review, recent-sites map) are backed by new read-only providers; `PersonalRecordsCard` is deleted. No schema changes.

**Tech Stack:** Flutter 3 / Material 3, Riverpod (`FutureProvider` + `invalidateSelfWhen`), Drift (read-only queries, some via `customSelect`), go_router, flutter_map + latlong2, intl/ARB l10n.

## Global Constraints

- Execute in a dedicated git worktree (per repo convention). After creating it run: `git submodule update --init --recursive`, `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`.
- Anything displaying units goes through `UnitFormatter(ref.watch(settingsProvider))` (`lib/core/utils/unit_formatter.dart`) — never hard-code m/ft/°C.
- All user-facing strings via `context.l10n.<key>` from `lib/l10n/arb/app_en.arb`; every new key must also be added (translated) to the 10 non-English ARB files: `app_es.arb`, `app_fr.arb`, `app_de.arb`, `app_it.arb`, `app_pt.arb`, `app_nl.arb`, `app_zh.arb`, `app_ar.arb`, `app_he.arb`, `app_hu.arb`, then run `flutter gen-l10n`.
- No emojis in code or comments. `dart format .` (whole project) before every commit. Run `flutter analyze` on the whole project — infos are CI-fatal.
- Commit messages: conventional style, no Co-Authored-By line, no session URL.
- Test commands may be long-running; never pipe `flutter analyze` through `tail`.
- New widgets must not introduce provider dependencies into shared widgets used by other features (breaks their tests silently); all new widgets are dashboard-local.
- Error-handling rule (spec): conditional (hide-when-empty) cards also hide on provider error; always-on blocks show a contained retry affordance, never a blank page.
- Already satisfied, no task needed: the spec's "Log your first dive" empty-state CTA in `RecentDivesCard` already exists (`recent_dives_card.dart:130-164`); do not modify that widget.

---

### Task 1: DashboardGrid layout widget

**Files:**
- Create: `lib/features/dashboard/presentation/widgets/dashboard_grid.dart`
- Test: `test/features/dashboard/presentation/widgets/dashboard_grid_test.dart`

**Interfaces:**
- Consumes: `ResponsiveBreakpoints` (`lib/shared/widgets/master_detail/responsive_breakpoints.dart`).
- Produces (used by Task 9):
  - `sealed class DashboardEntry` with subclasses `FullBlock(Widget child)`, `ThirdBlock(Widget child)`, `LeadSideGroup({required Widget lead, required List<Widget> side})`
  - `DashboardGrid({required List<DashboardEntry> entries, double spacing = 12})`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dashboard/presentation/widgets/dashboard_grid_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/widgets/dashboard_grid.dart';

void main() {
  Future<void> pumpGrid(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardGrid(
              entries: const [
                FullBlock(SizedBox(key: Key('hero'), height: 40)),
                LeadSideGroup(
                  lead: SizedBox(key: Key('lead'), height: 120),
                  side: [
                    SizedBox(key: Key('side1'), height: 40),
                    SizedBox(key: Key('side2'), height: 40),
                  ],
                ),
                ThirdBlock(SizedBox(key: Key('t1'), height: 40)),
                ThirdBlock(SizedBox(key: Key('t2'), height: 40)),
                ThirdBlock(SizedBox(key: Key('t3'), height: 40)),
                FullBlock(SizedBox(key: Key('map'), height: 40)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('phone (<800) stacks all blocks in order', (tester) async {
    await pumpGrid(tester, 500);
    final keys = ['hero', 'lead', 'side1', 'side2', 't1', 't2', 't3', 'map'];
    double lastBottom = -1;
    for (final k in keys) {
      final rect = tester.getRect(find.byKey(Key(k)));
      expect(rect.top, greaterThan(lastBottom - 0.01),
          reason: '$k should be below the previous block');
      lastBottom = rect.top;
      // Full width (16px scroll-view has no padding here; grid stretches).
      expect(rect.width, 500);
    }
  });

  testWidgets('3 columns (>=1200): thirds share one row, lead spans 2/3',
      (tester) async {
    await pumpGrid(tester, 1300);
    final t1 = tester.getRect(find.byKey(const Key('t1')));
    final t2 = tester.getRect(find.byKey(const Key('t2')));
    final t3 = tester.getRect(find.byKey(const Key('t3')));
    expect(t1.top, t2.top);
    expect(t2.top, t3.top);
    final lead = tester.getRect(find.byKey(const Key('lead')));
    final side1 = tester.getRect(find.byKey(const Key('side1')));
    expect(side1.top, lead.top);
    expect(lead.width, greaterThan(side1.width * 1.8));
    // Side stack fills the lead's height.
    final side2 = tester.getRect(find.byKey(const Key('side2')));
    expect(side2.bottom, closeTo(lead.bottom, 1.0));
  });

  testWidgets('2 columns (800-1199): thirds flow 2-up, leftover shares row',
      (tester) async {
    await pumpGrid(tester, 1000);
    final t1 = tester.getRect(find.byKey(const Key('t1')));
    final t2 = tester.getRect(find.byKey(const Key('t2')));
    final t3 = tester.getRect(find.byKey(const Key('t3')));
    expect(t1.top, t2.top);
    expect(t3.top, greaterThan(t1.bottom - 0.01));
    // Leftover third expands across the full row.
    expect(t3.width, 1000);
    // Lead and side split 50/50 at 2 columns (minus spacing).
    final lead = tester.getRect(find.byKey(const Key('lead')));
    final side1 = tester.getRect(find.byKey(const Key('side1')));
    expect(lead.width, closeTo(side1.width, 1.0));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dashboard/presentation/widgets/dashboard_grid_test.dart`
Expected: FAIL — `dashboard_grid.dart` does not exist / `DashboardGrid` undefined.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/dashboard/presentation/widgets/dashboard_grid.dart
import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// An entry in the dashboard's responsive grid.
sealed class DashboardEntry {
  const DashboardEntry();
}

/// Spans all columns at every width.
class FullBlock extends DashboardEntry {
  final Widget child;
  const FullBlock(this.child);
}

/// Spans one column; consecutive [ThirdBlock]s share a row. A leftover
/// block on an incomplete row expands to fill the remaining width.
class ThirdBlock extends DashboardEntry {
  final Widget child;
  const ThirdBlock(this.child);
}

/// A lead widget with side widgets stacked in the remaining column.
/// At 3 columns the lead spans 2; at 2 columns it spans 1; at 1 column
/// the group dissolves into the plain ordered stack.
class LeadSideGroup extends DashboardEntry {
  final Widget lead;
  final List<Widget> side;
  const LeadSideGroup({required this.lead, required this.side});
}

/// Responsive dashboard layout: one ordered entry list drives phone and
/// desktop. Column count follows [ResponsiveBreakpoints]: 1 below 800,
/// 2 at 800-1199, 3 at >=1200.
class DashboardGrid extends StatelessWidget {
  final List<DashboardEntry> entries;
  final double spacing;

  const DashboardGrid({required this.entries, this.spacing = 12, super.key});

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveBreakpoints.isDesktopExtended(context)
        ? 3
        : ResponsiveBreakpoints.isDesktop(context)
        ? 2
        : 1;

    final rows = <Widget>[];
    final pendingThirds = <Widget>[];

    void flushThirds() {
      if (pendingThirds.isEmpty) return;
      if (columns == 1) {
        rows.addAll(pendingThirds);
      } else {
        for (var i = 0; i < pendingThirds.length; i += columns) {
          final end = i + columns > pendingThirds.length
              ? pendingThirds.length
              : i + columns;
          final chunk = pendingThirds.sublist(i, end);
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < chunk.length; j++) ...[
                    if (j > 0) SizedBox(width: spacing),
                    Expanded(child: chunk[j]),
                  ],
                ],
              ),
            ),
          );
        }
      }
      pendingThirds.clear();
    }

    for (final entry in entries) {
      switch (entry) {
        case ThirdBlock(:final child):
          pendingThirds.add(child);
        case FullBlock(:final child):
          flushThirds();
          rows.add(child);
        case LeadSideGroup(:final lead, :final side):
          flushThirds();
          if (columns == 1) {
            rows.add(lead);
            rows.addAll(side);
          } else {
            rows.add(
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: columns == 3 ? 2 : 1, child: lead),
                    SizedBox(width: spacing),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < side.length; i++) ...[
                            if (i > 0) SizedBox(height: spacing),
                            Expanded(child: side[i]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
      }
    }
    flushThirds();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          rows[i],
        ],
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dashboard/presentation/widgets/dashboard_grid_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dashboard/presentation/widgets/dashboard_grid.dart test/features/dashboard/presentation/widgets/dashboard_grid_test.dart
git commit -m "feat(dashboard): add responsive DashboardGrid layout widget"
```

---

### Task 2: Gauge providers, GaugeStrip, and UrgentBanner

**Files:**
- Create: `lib/features/dashboard/presentation/providers/gauge_providers.dart`
- Create: `lib/features/dashboard/presentation/widgets/gauge_strip.dart`
- Create: `lib/features/dashboard/presentation/widgets/urgent_banner.dart`
- Modify: `lib/l10n/arb/app_en.arb` (+ 10 locale files)
- Test: `test/features/dashboard/presentation/providers/gauge_providers_test.dart`
- Test: `test/features/dashboard/presentation/widgets/gauge_strip_test.dart`

**Interfaces:**
- Consumes: `activeEquipmentClocksProvider` (`FutureProvider<List<EquipmentClocks>>`, `EquipmentClocks = ({EquipmentItem item, List<ServiceClockStatus> statuses})`, `lib/features/equipment/presentation/providers/equipment_providers.dart:616`); `ServiceClockStatus` / `ServiceClockSeverity {ok, dueSoon, overdue}` (`lib/features/equipment/domain/entities/service_clock_status.dart`); `currentDiverProvider` (`Diver.insurance` -> `DiverInsurance{provider, expiryDate, isExpired, isExpiringSoon, isValid}`); `noFlyStatusProvider` (`FutureProvider<NoFlyStatus?>`, `NoFlyStatus.remaining(now)/isActiveAt(now)`); `daysSinceLastDiveProvider`; `dashboardAlertsProvider` (for UrgentBanner).
- Produces (used by Task 9):
  - `class GearGauge { EquipmentType type; String itemName; ServiceClockStatus status; }`
  - `class DashboardGauges { List<GearGauge> gearGauges; bool hasGear; DiverInsurance? insurance; NoFlyStatus? noFlyStatus; int? daysSinceLastDive; }`
  - `List<GearGauge> worstGaugePerType(List<EquipmentClocks> clocks)` (pure, exported for tests)
  - `final dashboardGaugesProvider = FutureProvider<DashboardGauges>`
  - Widgets `GaugeStrip()` and `UrgentBanner()` (both `ConsumerWidget`, render `SizedBox.shrink()` when they have nothing to show — UrgentBanner only; GaugeStrip is always-on).

- [ ] **Step 1: Write the failing pure-function test.** Note: build `ServiceClockStatus`/`EquipmentItem` fixtures by copying the fixture style used in `test/features/equipment/` (check existing tests for the exact constructors; `ServiceClockStatus` fields per `service_clock_status.dart:17`: `schedule`, `kind`, `anchor`, `dueDate`, `divesSinceAnchor`, `divesRemaining`, `hoursSinceAnchor`, `hoursRemaining`, `severity`, `now`).

```dart
// test/features/dashboard/presentation/providers/gauge_providers_test.dart
// (imports: flutter_test, gauge_providers.dart, equipment entities; copy
// entity-construction helpers from test/features/equipment/ fixtures)
void main() {
  group('worstGaugePerType', () {
    test('keeps the worst severity per equipment type', () {
      // two regulators: one ok, one overdue -> overdue wins
      // one BCD: dueSoon -> included as dueSoon
      final result = worstGaugePerType([
        clocks(regOk), // helper returning EquipmentClocks records
        clocks(regOverdue),
        clocks(bcdDueSoon),
      ]);
      expect(result, hasLength(2));
      expect(
        result.firstWhere((g) => g.type == regOverdue.item.type).status.severity,
        ServiceClockSeverity.overdue,
      );
    });

    test('tie on severity resolved by earlier dueDate', () {
      final result = worstGaugePerType([clocks(bcdDueSoonLater), clocks(bcdDueSoonSooner)]);
      expect(result.single.itemName, bcdDueSoonSooner.item.name);
    });

    test('empty input yields empty output', () {
      expect(worstGaugePerType([]), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dashboard/presentation/providers/gauge_providers_test.dart`
Expected: FAIL — `gauge_providers.dart` missing.

- [ ] **Step 3: Implement the providers**

```dart
// lib/features/dashboard/presentation/providers/gauge_providers.dart
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/providers/no_fly_providers.dart';

/// The worst service clock for one equipment type, shown as one chip.
class GearGauge {
  final EquipmentType type;
  final String itemName;
  final ServiceClockStatus status;

  const GearGauge({
    required this.type,
    required this.itemName,
    required this.status,
  });
}

/// Always-on status values for the dashboard gauge strip.
class DashboardGauges {
  final List<GearGauge> gearGauges;
  final bool hasGear;
  final DiverInsurance? insurance;
  final NoFlyStatus? noFlyStatus;
  final int? daysSinceLastDive;

  const DashboardGauges({
    required this.gearGauges,
    required this.hasGear,
    required this.insurance,
    required this.noFlyStatus,
    required this.daysSinceLastDive,
  });
}

int _severityRank(ServiceClockSeverity s) => switch (s) {
  ServiceClockSeverity.overdue => 2,
  ServiceClockSeverity.dueSoon => 1,
  ServiceClockSeverity.ok => 0,
};

/// Reduces per-item service clocks to the single worst clock per
/// equipment type. Severity wins; ties resolve to the earlier dueDate
/// (null dueDates sort last).
List<GearGauge> worstGaugePerType(List<EquipmentClocks> clocks) {
  final best = <EquipmentType, GearGauge>{};
  for (final entry in clocks) {
    for (final status in entry.statuses) {
      final candidate = GearGauge(
        type: entry.item.type,
        itemName: entry.item.name,
        status: status,
      );
      final current = best[entry.item.type];
      if (current == null) {
        best[entry.item.type] = candidate;
        continue;
      }
      final rankNew = _severityRank(status.severity);
      final rankCur = _severityRank(current.status.severity);
      if (rankNew > rankCur) {
        best[entry.item.type] = candidate;
      } else if (rankNew == rankCur) {
        final newDue = status.dueDate;
        final curDue = current.status.dueDate;
        if (newDue != null && (curDue == null || newDue.isBefore(curDue))) {
          best[entry.item.type] = candidate;
        }
      }
    }
  }
  return best.values.toList();
}

/// Always-on gauges: worst gear clock per type, insurance, no-fly,
/// days since last dive.
final dashboardGaugesProvider = FutureProvider<DashboardGauges>((ref) async {
  final clocks = await ref.watch(activeEquipmentClocksProvider.future);
  final diver = await ref.watch(currentDiverProvider.future);
  final noFly = await ref.watch(noFlyStatusProvider.future);
  final daysSince = await ref.watch(daysSinceLastDiveProvider.future);

  return DashboardGauges(
    gearGauges: worstGaugePerType(clocks),
    hasGear: clocks.isNotEmpty,
    insurance: diver?.insurance,
    noFlyStatus: noFly,
    daysSinceLastDive: daysSince,
  );
});
```

- [ ] **Step 4: Run the pure-function test — expect PASS.**

- [ ] **Step 5: Add l10n keys.** In `lib/l10n/arb/app_en.arb` add (then translated equivalents in all 10 locale files):

```json
"dashboard_gauges_addGear": "Add gear",
"dashboard_gauges_gearOk": "{name} OK",
"dashboard_gauges_gearDueIn": "{name} due in {days}d",
"dashboard_gauges_gearOverdue": "{name} overdue",
"dashboard_gauges_insuranceOk": "Insurance OK",
"dashboard_gauges_insuranceExpires": "Insurance expires {date}",
"dashboard_gauges_insuranceExpired": "Insurance expired",
"dashboard_gauges_noInsurance": "No insurance on file",
"dashboard_gauges_noFlyClear": "No-fly 0:00",
"dashboard_gauges_noFlyRemaining": "No-fly {hours}:{minutes}",
"dashboard_gauges_lastDiveDays": "Last dive {days}d ago",
"dashboard_gauges_lastDiveToday": "Dove today",
"dashboard_gauges_noDivesYet": "No dives yet",
"dashboard_urgent_title": "Needs attention",
"dashboard_gauges_retry": "Status unavailable - tap to retry"
```

(Add matching `@`-metadata placeholder blocks for parameterized keys, following the existing `dashboard_*` entries in the same file.)

- [ ] **Step 6: Write the failing GaugeStrip widget test** (pattern from `test/features/dashboard/presentation/widgets/alerts_card_test.dart`: `getBaseOverrides()` from `test/helpers/mock_providers.dart`, `ProviderScope`, `MaterialApp` with `AppLocalizations.localizationsDelegates`):

```dart
// test/features/dashboard/presentation/widgets/gauge_strip_test.dart
void main() {
  testWidgets('renders neutral gauges when everything is fine', (tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          dashboardGaugesProvider.overrideWith(
            (ref) async => const DashboardGauges(
              gearGauges: [],
              hasGear: false,
              insurance: null,
              noFlyStatus: null,
              daysSinceLastDive: 12,
            ),
          ),
        ],
        child: /* MaterialApp with l10n delegates */ testApp(const GaugeStrip()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Last dive 12d ago'), findsOneWidget);
    expect(find.text('Add gear'), findsOneWidget);
    expect(find.text('No-fly 0:00'), findsOneWidget);
  });

  testWidgets('gear gauge shows overdue chip with error color', (tester) async {
    // override with one overdue GearGauge fixture; assert
    // find.text('Regulator overdue') findsOneWidget
  });
}
```

- [ ] **Step 7: Run widget test — expect FAIL (GaugeStrip missing).**

- [ ] **Step 8: Implement GaugeStrip**

```dart
// lib/features/dashboard/presentation/widgets/gauge_strip.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Always-on status chips: gear service clocks, insurance, no-fly,
/// dive currency. Neutral when fine, tinted when due or overdue.
class GaugeStrip extends ConsumerWidget {
  const GaugeStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gaugesAsync = ref.watch(dashboardGaugesProvider);
    return gaugesAsync.when(
      data: (g) => _buildStrip(context, g),
      loading: () => const SizedBox(height: 40),
      // Always-on block: contained error with a retry affordance (spec's
      // error-handling rule) instead of vanishing.
      error: (_, _) => _chip(
        context,
        icon: Icons.refresh,
        label: context.l10n.dashboard_gauges_retry,
        tone: _Tone.neutral,
        onTap: () => ref.invalidate(dashboardGaugesProvider),
      ),
    );
  }

  Widget _buildStrip(BuildContext context, DashboardGauges g) {
    final l10n = context.l10n;
    final chips = <Widget>[];

    if (!g.hasGear) {
      chips.add(_chip(
        context,
        icon: Icons.add,
        label: l10n.dashboard_gauges_addGear,
        tone: _Tone.neutral,
        onTap: () => context.go('/gear'),
      ));
    } else {
      for (final gauge in g.gearGauges) {
        final (label, tone) = switch (gauge.status.severity) {
          ServiceClockSeverity.overdue => (
            l10n.dashboard_gauges_gearOverdue(gauge.itemName),
            _Tone.alert,
          ),
          ServiceClockSeverity.dueSoon => (
            l10n.dashboard_gauges_gearDueIn(
              gauge.itemName,
              gauge.status.daysUntilDue ?? 0,
            ),
            _Tone.warn,
          ),
          ServiceClockSeverity.ok => (
            l10n.dashboard_gauges_gearOk(gauge.itemName),
            _Tone.ok,
          ),
        };
        chips.add(_chip(
          context,
          icon: Icons.build_outlined,
          label: label,
          tone: tone,
          onTap: () => context.go('/gear'),
        ));
      }
    }

    final insurance = g.insurance;
    if (insurance == null || insurance.expiryDate == null) {
      chips.add(_chip(context,
          icon: Icons.health_and_safety_outlined,
          label: l10n.dashboard_gauges_noInsurance,
          tone: _Tone.neutral));
    } else if (insurance.isExpired) {
      chips.add(_chip(context,
          icon: Icons.health_and_safety_outlined,
          label: l10n.dashboard_gauges_insuranceExpired,
          tone: _Tone.alert));
    } else if (insurance.isExpiringSoon) {
      chips.add(_chip(context,
          icon: Icons.health_and_safety_outlined,
          label: l10n.dashboard_gauges_insuranceExpires(
              DateFormat.yMMMd().format(insurance.expiryDate!)),
          tone: _Tone.warn));
    } else {
      chips.add(_chip(context,
          icon: Icons.health_and_safety_outlined,
          label: l10n.dashboard_gauges_insuranceOk,
          tone: _Tone.ok));
    }

    final noFly = g.noFlyStatus;
    final now = DateTime.now().toUtc();
    if (noFly != null && noFly.isActiveAt(now)) {
      final remaining = noFly.remaining(now);
      chips.add(_chip(context,
          icon: Icons.flight_outlined,
          label: l10n.dashboard_gauges_noFlyRemaining(
              remaining.inHours.toString(),
              (remaining.inMinutes % 60).toString().padLeft(2, '0')),
          tone: _Tone.warn));
    } else {
      chips.add(_chip(context,
          icon: Icons.flight_outlined,
          label: l10n.dashboard_gauges_noFlyClear,
          tone: _Tone.ok));
    }

    final days = g.daysSinceLastDive;
    chips.add(_chip(
      context,
      icon: Icons.scuba_diving,
      label: days == null
          ? l10n.dashboard_gauges_noDivesYet
          : days == 0
          ? l10n.dashboard_gauges_lastDiveToday
          : l10n.dashboard_gauges_lastDiveDays(days),
      tone: _Tone.neutral,
    ));

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _chip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required _Tone tone,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      _Tone.alert => (scheme.errorContainer, scheme.onErrorContainer),
      _Tone.warn => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      _Tone.ok => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _Tone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Tone { neutral, ok, warn, alert }
```

- [ ] **Step 9: Implement UrgentBanner** (compact banner for overdue/expired/active-no-fly only; reuses `dashboardAlertsProvider`):

```dart
// lib/features/dashboard/presentation/widgets/urgent_banner.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Compact banner listing only genuinely urgent items: overdue service,
/// expired insurance, active no-fly. Hidden otherwise.
class UrgentBanner extends ConsumerWidget {
  const UrgentBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(dashboardAlertsProvider);
    final alerts = alertsAsync.valueOrNull;
    if (alerts == null) return const SizedBox.shrink();

    final overdue = alerts.serviceClocksDue
        .where((c) => c.status.severity == ServiceClockSeverity.overdue)
        .toList();
    final urgent = overdue.isNotEmpty || alerts.insuranceExpired;
    if (!urgent) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final lines = <String>[
      for (final clock in overdue)
        context.l10n.dashboard_gauges_gearOverdue(clock.item.name),
      if (alerts.insuranceExpired)
        context.l10n.dashboard_gauges_insuranceExpired,
    ];
    return Card(
      color: scheme.errorContainer,
      child: InkWell(
        onTap: () => context.go('/gear'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.dashboard_urgent_title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    for (final line in lines)
                      Text(
                        line,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 10: Run `flutter gen-l10n`, then both test files — expect PASS.**

- [ ] **Step 11: Format and commit**

```bash
dart format .
git add lib/features/dashboard lib/l10n test/features/dashboard
git commit -m "feat(dashboard): add always-on GaugeStrip and UrgentBanner"
```

---

### Task 3: HeroHeader rework (logo left, quiet desktop stats)

**Files:**
- Modify: `lib/features/dashboard/presentation/widgets/hero_header.dart`
- Modify: `lib/l10n/arb/app_en.arb` (+ 10 locale files)
- Test: `test/features/dashboard/presentation/widgets/hero_header_test.dart` (extend existing)

**Interfaces:**
- Consumes: `diveStatisticsProvider` (`DiveStatistics{totalDives, totalTimeSeconds, maxDepth, totalSites}`), `dashboardQuickStatsProvider` (`DashboardQuickStats.countriesVisited`), `dashboardDiverProvider`, `settingsProvider` + `UnitFormatter`, `ResponsiveBreakpoints.isDesktop`.
- Produces: `HeroHeader()` unchanged signature; internal layout only.

- [ ] **Step 1: Add l10n keys** to `app_en.arb` (+ translations in 10 locales):

```json
"dashboard_hero_statDives": "dives",
"dashboard_hero_statHours": "hours",
"dashboard_hero_statDeepest": "deepest",
"dashboard_hero_statSites": "sites",
"dashboard_hero_statCountries": "countries"
```

- [ ] **Step 2: Extend the existing widget test** with two cases (follow the file's existing override pattern):

```dart
testWidgets('desktop width shows quiet center stats', (tester) async {
  tester.view.physicalSize = const Size(1300, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // pump HeroHeader with diveStatisticsProvider overridden to
  // DiveStatistics fixture (totalDives: 247, totalTimeSeconds: 669600,
  // maxDepth: 52.0, totalSites: 83) and dashboardQuickStatsProvider
  // overridden to DashboardQuickStats(countriesVisited: 14).
  expect(find.text('247'), findsOneWidget);
  expect(find.text('dives'), findsOneWidget);
  expect(find.text('countries'), findsOneWidget);
});

testWidgets('phone width hides center stats, keeps headline line',
    (tester) async {
  tester.view.physicalSize = const Size(500, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // same overrides
  expect(find.text('countries'), findsNothing);
});
```

- [ ] **Step 3: Run the hero test file — expect FAIL (new expectations).**

Run: `flutter test test/features/dashboard/presentation/widgets/hero_header_test.dart`

- [ ] **Step 4: Rework the widget.** Keep `OceanBackground`, `Semantics`, greeting logic (`_getGreeting`), and the existing narrow headline-stats line untouched. Change the layout `Row` to:

```dart
// Inside OceanBackground > Padding(24):
Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    ExcludeSemantics(
      child: Image.asset('assets/icon/icon.png', width: 56, height: 56),
    ),
    const SizedBox(width: 16),
    // Greeting column (existing greeting + existing headline stats line;
    // on desktop the headline line is replaced by the current date).
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /* existing greeting diverAsync.when(...) block, unchanged */
        const SizedBox(height: 4),
        if (isDesktop)
          Text(
            DateFormat.yMMMMd(
              Localizations.localeOf(context).toString(),
            ).format(DateTime.now()),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          )
        else
          /* existing statsAsync.when(...) headline stats block, unchanged */,
      ],
    ),
    if (isDesktop) ...[
      const SizedBox(width: 24),
      Expanded(child: _QuietStats()),
    ] else
      const Spacer(),
  ],
)
```

with `isDesktop = ResponsiveBreakpoints.isDesktop(context)` and:

```dart
class _QuietStats extends ConsumerWidget {
  const _QuietStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(diveStatisticsProvider);
    final quickAsync = ref.watch(dashboardQuickStatsProvider);
    final settings = ref.watch(settingsProvider);
    final fmt = UnitFormatter(settings);
    final stats = statsAsync.valueOrNull;
    if (stats == null || stats.totalDives == 0) {
      return const SizedBox.shrink();
    }
    final countries = quickAsync.valueOrNull?.countriesVisited ?? 0;
    final hours = (stats.totalTimeSeconds / 3600).round();

    final items = <(String, String)>[
      ('${stats.totalDives}', context.l10n.dashboard_hero_statDives),
      ('$hours', context.l10n.dashboard_hero_statHours),
      (
        fmt.formatDepth(stats.maxDepth, decimals: 0),
        context.l10n.dashboard_hero_statDeepest,
      ),
      ('${stats.totalSites}', context.l10n.dashboard_hero_statSites),
      if (countries > 0)
        ('$countries', context.l10n.dashboard_hero_statCountries),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              color: Colors.white.withValues(alpha: 0.15),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                items[i].$1,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                items[i].$2.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.55),
                  letterSpacing: 1.2,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
```

Add imports: `intl`, `unit_formatter.dart`, `settings_providers.dart`, `responsive_breakpoints.dart`.

- [ ] **Step 5: Run hero test file — expect PASS. Run `flutter gen-l10n` first if not already.**

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/dashboard lib/l10n test/features/dashboard
git commit -m "feat(dashboard): hero header with left logo and quiet desktop stats"
```

---

### Task 4: Milestones provider and card

**Files:**
- Create: `lib/features/dashboard/presentation/providers/milestone_providers.dart`
- Create: `lib/features/dashboard/presentation/widgets/milestones_card.dart`
- Modify: `lib/l10n/arb/app_en.arb` (+ 10 locale files)
- Test: `test/features/dashboard/presentation/providers/milestone_providers_test.dart`

**Interfaces:**
- Consumes: `diveStatisticsProvider`, `certificationListNotifierProvider` (`AsyncValue<List<Certification>>`, `Certification.issueDate`).
- Produces (used by Task 9):
  - `int? nextDiveMilestone(int totalDives)` (pure)
  - `class CertAnniversary { String certName; int years; DateTime date; }`
  - `List<CertAnniversary> upcomingAnniversaries(List<Certification> certs, DateTime today, {int windowDays = 60})` (pure)
  - `class DashboardMilestones { int? nextMilestone; int? divesRemaining; List<CertAnniversary> anniversaries; bool get isEmpty; }`
  - `final milestonesProvider = FutureProvider<DashboardMilestones>`
  - `MilestonesCard()` widget.

- [ ] **Step 1: Write failing pure-function tests**

```dart
// test/features/dashboard/presentation/providers/milestone_providers_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/providers/milestone_providers.dart';

void main() {
  group('nextDiveMilestone', () {
    test('ladder below 1000', () {
      expect(nextDiveMilestone(0), isNull);
      expect(nextDiveMilestone(1), 10);
      expect(nextDiveMilestone(10), 25);
      expect(nextDiveMilestone(247), 250);
      expect(nextDiveMilestone(999), 1000);
    });
    test('every 500 above 1000', () {
      expect(nextDiveMilestone(1000), 1500);
      expect(nextDiveMilestone(1501), 2000);
    });
  });

  group('upcomingAnniversaries', () {
    test('includes anniversary within window, computes years', () {
      final certs = [certWithIssueDate(DateTime(2016, 8, 10), name: 'Open Water')];
      final result =
          upcomingAnniversaries(certs, DateTime(2026, 7, 24), windowDays: 60);
      expect(result.single.years, 10);
      expect(result.single.date, DateTime(2026, 8, 10));
    });
    test('excludes anniversary outside window', () {
      final certs = [certWithIssueDate(DateTime(2016, 12, 25))];
      expect(
        upcomingAnniversaries(certs, DateTime(2026, 7, 24), windowDays: 60),
        isEmpty,
      );
    });
    test('anniversary earlier this year rolls to next year', () {
      final certs = [certWithIssueDate(DateTime(2020, 1, 5))];
      final result =
          upcomingAnniversaries(certs, DateTime(2026, 12, 20), windowDays: 60);
      expect(result.single.date, DateTime(2027, 1, 5));
      expect(result.single.years, 7);
    });
    test('null issueDate ignored', () {
      expect(
        upcomingAnniversaries([certWithIssueDate(null)], DateTime(2026, 7, 24)),
        isEmpty,
      );
    });
  });
}
```

(`certWithIssueDate` is a local helper constructing a `Certification` with required fields — copy the constructor usage from `test/features/certifications/`.)

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement**

```dart
// lib/features/dashboard/presentation/providers/milestone_providers.dart
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

const _milestoneLadder = [10, 25, 50, 100, 250, 500, 1000];

/// Next round-number dive milestone, or null when there are no dives.
int? nextDiveMilestone(int totalDives) {
  if (totalDives <= 0) return null;
  for (final t in _milestoneLadder) {
    if (totalDives < t) return t;
  }
  return ((totalDives ~/ 500) + 1) * 500;
}

class CertAnniversary {
  final String certName;
  final int years;
  final DateTime date;
  const CertAnniversary({
    required this.certName,
    required this.years,
    required this.date,
  });
}

/// Certification anniversaries falling within [windowDays] of [today].
List<CertAnniversary> upcomingAnniversaries(
  List<Certification> certs,
  DateTime today, {
  int windowDays = 60,
}) {
  final result = <CertAnniversary>[];
  final todayDay = DateTime(today.year, today.month, today.day);
  for (final cert in certs) {
    final issued = cert.issueDate;
    if (issued == null) continue;
    var next = DateTime(todayDay.year, issued.month, issued.day);
    if (next.isBefore(todayDay)) {
      next = DateTime(todayDay.year + 1, issued.month, issued.day);
    }
    final years = next.year - issued.year;
    if (years <= 0) continue;
    if (next.difference(todayDay).inDays <= windowDays) {
      result.add(
        CertAnniversary(certName: cert.name, years: years, date: next),
      );
    }
  }
  result.sort((a, b) => a.date.compareTo(b.date));
  return result;
}

class DashboardMilestones {
  final int? nextMilestone;
  final int? divesRemaining;
  final List<CertAnniversary> anniversaries;
  const DashboardMilestones({
    required this.nextMilestone,
    required this.divesRemaining,
    required this.anniversaries,
  });
  bool get isEmpty => nextMilestone == null && anniversaries.isEmpty;
}

final milestonesProvider = FutureProvider<DashboardMilestones>((ref) async {
  final stats = await ref.watch(diveStatisticsProvider.future);
  final certsAsync = ref.watch(certificationListNotifierProvider);
  final certs = certsAsync.valueOrNull ?? const <Certification>[];

  final next = nextDiveMilestone(stats.totalDives);
  return DashboardMilestones(
    nextMilestone: next,
    divesRemaining: next == null ? null : next - stats.totalDives,
    anniversaries: upcomingAnniversaries(certs, DateTime.now()),
  );
});
```

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Add l10n keys** (+ 10 locales):

```json
"dashboard_milestones_title": "Milestones",
"dashboard_milestones_nextDive": "{remaining} dives to #{milestone}",
"dashboard_milestones_certYears": "{name}: {years} years in {month}"
```

- [ ] **Step 6: Implement MilestonesCard** (Card matching `QuickActionsCard` chrome: `Card > Padding(12) > Column` with bold `bodyMedium` title). Body: if milestones has `nextMilestone`, a row with `Icons.flag_outlined` and `dashboard_milestones_nextDive(divesRemaining, nextMilestone)`; one row per anniversary with `Icons.workspace_premium_outlined` and `dashboard_milestones_certYears(certName, years, DateFormat.MMMM(locale).format(date))`. `loading`/`error` -> `SizedBox.shrink()`. The card does not need to self-hide (page-level inclusion handles it, Task 9), but returning `SizedBox.shrink()` when `isEmpty` keeps it safe standalone.

- [ ] **Step 7: `flutter gen-l10n`; run the dashboard test dir**

Run: `flutter test test/features/dashboard/`
Expected: PASS.

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add lib/features/dashboard lib/l10n test/features/dashboard
git commit -m "feat(dashboard): milestones provider and card"
```

---

### Task 5: Recent photos query, provider, and PhotoRibbonCard

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart` (add one query)
- Create: `lib/features/dashboard/presentation/providers/photo_providers.dart`
- Create: `lib/features/dashboard/presentation/widgets/photo_ribbon_card.dart`
- Modify: `lib/l10n/arb/app_en.arb` (+ 10 locale files)
- Test: `test/features/media/data/repositories/media_repository_recent_photos_test.dart`

**Interfaces:**
- Consumes: `MediaRepository` internals (mirror `getMediaForDive` at `media_repository.dart:21` for row->entity mapping and the `mediaType` column encoding), `MediaItem`, `MediaItemView` (`lib/features/media/presentation/widgets/media_item_view.dart:36`, ctor `MediaItemView({required item, fit, targetSize, thumbnail})`).
- Produces (used by Task 9):
  - `Future<List<MediaItem>> MediaRepository.getRecentPhotos({int limit = 12})` — newest-first by `takenAt`, photos only
  - `final recentPhotosProvider = FutureProvider<List<MediaItem>>`
  - `PhotoRibbonCard()` widget.

- [ ] **Step 1: Write failing repository test** using `test/helpers/test_database.dart` (`setUpTestDatabase`/`tearDownTestDatabase`) and the media-insert helper used by existing tests in `test/features/media/` (check that directory for the canonical way to insert a `MediaItem`; use it rather than raw table inserts):

```dart
void main() {
  late MediaRepository repository;
  setUp(() async {
    await setUpTestDatabase();
    repository = MediaRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  test('returns newest photos first, capped at limit, photos only', () async {
    // Insert 3 photos with takenAt 2026-01-01, 2026-03-01, 2026-02-01
    // and 1 video with takenAt 2026-04-01 (should be excluded).
    final result = await repository.getRecentPhotos(limit: 2);
    expect(result, hasLength(2));
    expect(result[0].takenAt, DateTime(2026, 3, 1));
    expect(result[1].takenAt, DateTime(2026, 2, 1));
    expect(result.every((m) => m.mediaType == MediaType.photo), isTrue);
  });

  test('empty table returns empty list', () async {
    expect(await repository.getRecentPhotos(), isEmpty);
  });
}
```

- [ ] **Step 2: Run — expect FAIL (method missing).**

- [ ] **Step 3: Implement `getRecentPhotos`** in `MediaRepository`, modeled exactly on `getMediaForDive` (same select/map helpers, same `mediaType` encoding), but: no `diveId` filter, `where mediaType == photo`, `orderBy takenAt desc`, `limit(limit)`.

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Provider**

```dart
// lib/features/dashboard/presentation/providers/photo_providers.dart
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Newest dive photos for the dashboard ribbon. Reuse the app's existing
/// media repository provider if one exists (check
/// lib/features/media/presentation/providers/); otherwise construct
/// directly as below (MediaRepository reads DatabaseService.instance).
final recentPhotosProvider = FutureProvider<List<MediaItem>>((ref) async {
  final repository = MediaRepository();
  return repository.getRecentPhotos(limit: 12);
});
```

(Refreshed via pull-to-refresh invalidation in Task 9; media tables have no watch stream on this repository today, so no `invalidateSelfWhen`.)

- [ ] **Step 6: l10n key** (+ 10 locales): `"dashboard_photos_title": "Recent photos"`.

- [ ] **Step 7: Implement PhotoRibbonCard**

```dart
// lib/features/dashboard/presentation/widgets/photo_ribbon_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dashboard/presentation/providers/photo_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Horizontal ribbon of the newest dive photos.
class PhotoRibbonCard extends ConsumerWidget {
  const PhotoRibbonCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(recentPhotosProvider);
    final photos = photosAsync.valueOrNull ?? const [];
    if (photos.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.dashboard_photos_title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = photos[index];
                  return InkWell(
                    onTap: item.diveId == null
                        ? null
                        : () => context.push('/dives/${item.diveId}'),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 128,
                        child: MediaItemView(item: item, thumbnail: true),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 8: `flutter gen-l10n`; run media + dashboard tests; format; commit**

```bash
flutter test test/features/media test/features/dashboard
dart format .
git add lib/features/media lib/features/dashboard lib/l10n test/features/media
git commit -m "feat(dashboard): recent photos ribbon"
```

---

### Task 6: On-this-day query, provider, and card

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (add one query near `countDivesSince`, `:2627`)
- Create: `lib/features/dashboard/presentation/widgets/on_this_day_card.dart`
- Modify: `lib/features/dashboard/presentation/providers/dashboard_providers.dart` (add provider)
- Modify: `lib/l10n/arb/app_en.arb` (+ 10 locale files)
- Test: `test/features/dive_log/data/repositories/on_this_day_query_test.dart`

**Interfaces:**
- Consumes: Drift `customSelect` (pattern already used elsewhere in this repository class); `dives` table column `dive_date_time` (millisecondsSinceEpoch), `diver_id`, `id`.
- Produces (used by Task 9):
  - `Future<List<String>> DiveRepository.getOnThisDayDiveIds({required int month, required int day, required int excludeYear, String? diverId, int limit = 5})`
  - `final onThisDayProvider = FutureProvider<List<Dive>>`
  - `OnThisDayCard()` widget.

- [ ] **Step 1: Write failing repository test** (pattern from `test/features/dive_log/data/repositories/dashboard_queries_test.dart`):

```dart
void main() {
  late DiveRepository repository;
  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  test('matches month/day from prior years only', () async {
    await createDiveOn(repository, DateTime(2023, 7, 24, 10)); // match
    await createDiveOn(repository, DateTime(2024, 7, 24, 14)); // match
    await createDiveOn(repository, DateTime(2026, 7, 24, 9)); // this year: excluded
    await createDiveOn(repository, DateTime(2024, 7, 23, 9)); // wrong day
    final ids = await repository.getOnThisDayDiveIds(
      month: 7, day: 24, excludeYear: 2026);
    expect(ids, hasLength(2));
  });

  test('Feb 29 matches only leap-year dives and does not crash', () async {
    await createDiveOn(repository, DateTime(2024, 2, 29, 10));
    await createDiveOn(repository, DateTime(2023, 3, 1, 10));
    final ids = await repository.getOnThisDayDiveIds(
      month: 2, day: 29, excludeYear: 2026);
    expect(ids, hasLength(1));
  });

  test('respects diverId scoping', () async {
    // create dives for two diver ids; assert filter returns only the
    // requested diver's dive (use the same diver setup helper as
    // dashboard_queries_test.dart)
  });
}
```

(`createDiveOn` is a small local helper calling `repository.createDive(...)` with the given `DateTime` — copy the dive-construction call from `dashboard_queries_test.dart`.)

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement the query** in `DiveRepository` (next to `countDivesSince`). The `dives` table stores `dive_date_time` as milliseconds since epoch; compare wall-clock month/day via strftime:

```dart
/// Dive ids from prior years sharing the given month/day ("on this
/// day"). Newest first, capped at [limit].
Future<List<String>> getOnThisDayDiveIds({
  required int month,
  required int day,
  required int excludeYear,
  String? diverId,
  int limit = 5,
}) async {
  final monthDay =
      "${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
  final buffer = StringBuffer(
    "SELECT id FROM dives "
    "WHERE strftime('%m-%d', dive_date_time / 1000, 'unixepoch') = ? "
    "AND CAST(strftime('%Y', dive_date_time / 1000, 'unixepoch') AS INTEGER) != ? ",
  );
  final variables = <Variable>[
    Variable.withString(monthDay),
    Variable.withInt(excludeYear),
  ];
  if (diverId != null) {
    buffer.write('AND diver_id = ? ');
    variables.add(Variable.withString(diverId));
  }
  buffer.write('ORDER BY dive_date_time DESC LIMIT ?');
  variables.add(Variable.withInt(limit));

  final rows = await _db
      .customSelect(buffer.toString(), variables: variables,
          readsFrom: {_db.dives})
      .get();
  return rows.map((r) => r.read<String>('id')).toList();
}
```

(Match the field name for the database handle — this class may use `_db`, `db`, or `database`; and match how sibling `customSelect` calls in the same file reference the dives table.)

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Add provider** to `dashboard_providers.dart`:

```dart
/// Dives from this month/day in prior years ("on this day").
final onThisDayProvider = FutureProvider<List<Dive>>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final now = DateTime.now();
  final ids = await repository.getOnThisDayDiveIds(
    month: now.month,
    day: now.day,
    excludeYear: now.year,
    diverId: currentDiverId,
  );
  final dives = <Dive>[];
  for (final id in ids) {
    final dive = await repository.getDiveById(id);
    if (dive != null) dives.add(dive);
  }
  return dives;
});
```

- [ ] **Step 6: l10n keys** (+ 10 locales):

```json
"dashboard_onThisDay_title": "On this day",
"dashboard_onThisDay_entry": "{year} - {site}"
```

- [ ] **Step 7: Implement OnThisDayCard.** Card chrome as in Task 5. Body: for each dive a `ListTile`-style row (dense): leading `Icons.history`, title `dashboard_onThisDay_entry(dive.effectiveEntryTime.year.toString(), siteName)` (site via the dive entity's site fields; fall back to `dive.name` or a dash when absent), subtitle `'${fmt.formatDepth(dive.maxDepth)} · ${duration}'` using `UnitFormatter` and the dive's formatted duration, `onTap: () => context.push('/dives/${dive.id}')`. `valueOrNull ?? []`; empty -> `SizedBox.shrink()`.

- [ ] **Step 8: `flutter gen-l10n`; run dive_log + dashboard tests; format; commit**

```bash
flutter test test/features/dive_log/data/repositories/on_this_day_query_test.dart test/features/dashboard
dart format .
git add lib/features/dive_log lib/features/dashboard lib/l10n test/features/dive_log
git commit -m "feat(dashboard): on-this-day dives card"
```

---

### Task 7: Year-in-review query, provider, and card

**Files:**
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart` (add query near `getDivesPerYear`, `:800`)
- Create: `lib/features/dashboard/presentation/widgets/year_in_review_card.dart`
- Modify: `lib/features/dashboard/presentation/providers/dashboard_providers.dart` (add provider + data classes)
- Modify: `lib/l10n/arb/app_en.arb` (+ 10 locale files)
- Test: `test/features/statistics/data/repositories/year_stats_test.dart`

**Interfaces:**
- Consumes: `statisticsRepositoryProvider`, `statisticsVersionProvider`, `currentDiverIdProvider`, `UnitFormatter`.
- Produces (used by Task 9):
  - `class YearStats { int diveCount; int totalSeconds; double? maxDepth; }` (in statistics_repository.dart)
  - `Future<YearStats> StatisticsRepository.getYearStats(int year, {String? diverId})`
  - `class YearInReview { int year; YearStats current; YearStats previous; }`
  - `final yearInReviewProvider = FutureProvider<YearInReview?>` (null when both years have zero dives)
  - `YearInReviewCard()` widget.

- [ ] **Step 1: Write failing repository test** (same test-database pattern as Task 6; insert dives across two years with known durations and depths):

```dart
test('aggregates count, seconds, and max depth for one year', () async {
  // three dives in 2026 (durations 30+40+50 min, depths 18/32/25 m),
  // one dive in 2025
  final stats = await repository.getYearStats(2026);
  expect(stats.diveCount, 3);
  expect(stats.totalSeconds, (30 + 40 + 50) * 60);
  expect(stats.maxDepth, 32.0);
});

test('year with no dives returns zeros and null maxDepth', () async {
  final stats = await repository.getYearStats(2020);
  expect(stats.diveCount, 0);
  expect(stats.totalSeconds, 0);
  expect(stats.maxDepth, isNull);
});
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement `getYearStats`** modeled on `getDivesPerYear` (`statistics_repository.dart:800` — same `strftime('%Y', dive_date_time/1000, 'unixepoch')` predicate and diver scoping). IMPORTANT: for the duration sum, reuse the exact same column/expression that `DiveRepository.getStatistics` uses to compute `totalTimeSeconds` (open `dive_repository_impl.dart`, find `getStatistics`, and copy its SUM expression) so the card's hours agree with the hero's hours. Shape:

```dart
class YearStats {
  final int diveCount;
  final int totalSeconds;
  final double? maxDepth;
  const YearStats({
    required this.diveCount,
    required this.totalSeconds,
    this.maxDepth,
  });
}

Future<YearStats> getYearStats(int year, {String? diverId}) async {
  // SELECT COUNT(*), COALESCE(SUM(<duration expr>), 0), MAX(max_depth)
  // FROM dives
  // WHERE strftime('%Y', dive_date_time/1000, 'unixepoch') = ?
  //   [AND diver_id = ?]
  // via customSelect, following getDivesPerYear's variable binding.
}
```

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Provider** in `dashboard_providers.dart`:

```dart
class YearInReview {
  final int year;
  final YearStats current;
  final YearStats previous;
  const YearInReview({
    required this.year,
    required this.current,
    required this.previous,
  });
}

/// This year vs last year. Null when both years are empty.
final yearInReviewProvider = FutureProvider<YearInReview?>((ref) async {
  ref.watch(statisticsVersionProvider);
  final repository = ref.watch(statisticsRepositoryProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  final year = DateTime.now().year;
  final current = await repository.getYearStats(year, diverId: diverId);
  final previous = await repository.getYearStats(year - 1, diverId: diverId);
  if (current.diveCount == 0 && previous.diveCount == 0) return null;
  return YearInReview(year: year, current: current, previous: previous);
});
```

- [ ] **Step 6: l10n keys** (+ 10 locales):

```json
"dashboard_yearInReview_title": "This year",
"dashboard_yearInReview_divesVs": "{count} dives (vs {previous} last year)",
"dashboard_yearInReview_hours": "{hours} hours underwater",
"dashboard_yearInReview_maxDepth": "Deepest: {depth}"
```

- [ ] **Step 7: Implement YearInReviewCard.** Card chrome as in Task 5; three text rows from the keys above (`hours = (current.totalSeconds / 3600).toStringAsFixed(current.totalSeconds >= 36000 ? 0 : 1)`, depth via `UnitFormatter.formatDepth`, omit the depth row when `maxDepth == null`). `valueOrNull` null -> `SizedBox.shrink()`.

- [ ] **Step 8: `flutter gen-l10n`; run statistics + dashboard tests; format; commit**

```bash
flutter test test/features/statistics/data/repositories/year_stats_test.dart test/features/dashboard
dart format .
git add lib/features/statistics lib/features/dashboard lib/l10n test/features/statistics
git commit -m "feat(dashboard): year-in-review card"
```

---

### Task 8: Recent sites provider and map card

**Files:**
- Create: `lib/features/dashboard/presentation/widgets/recent_sites_map_card.dart`
- Modify: `lib/features/dashboard/presentation/providers/dashboard_providers.dart` (add provider + data class)
- Modify: `lib/l10n/arb/app_en.arb` (+ 10 locale files)
- Test: `test/features/dashboard/presentation/providers/recent_sites_provider_test.dart`

**Interfaces:**
- Consumes: `DiveRepository.getDiveSummaries` (`DiveSummary.siteLatitude/siteLongitude/siteName` — already inline, no join); map stack per `lib/features/dive_sites/presentation/widgets/match_sites_map.dart:16` (`MapController`, `TrackpadZoomMap`, `CameraFit.bounds`, tile layer from `lib/features/maps/presentation/providers/map_tile_providers.dart`, `MapAttribution`).
- Produces (used by Task 9):
  - `class RecentSitePin { String? siteName; double latitude; double longitude; }`
  - `final recentSitesProvider = FutureProvider<List<RecentSitePin>>`
  - `RecentSitesMapCard()` widget (height 220, hides when no pins).

- [ ] **Step 1: Write failing provider test** (container-override pattern from `test/features/dashboard/presentation/providers/dashboard_providers_test.dart` — but this provider reads the repository, so use the real-DB pattern instead: `setUpTestDatabase`, create dives with/without site GPS via the repository, then `ProviderContainer` + `container.read(recentSitesProvider.future)`):

```dart
test('returns deduplicated pins for GPS-bearing sites of last 10 dives',
    () async {
  // create: 2 dives at site A (lat 36.0, lng 25.0), 1 dive at site B
  // (lat 35.0, lng 24.0), 1 dive with no site
  final pins = await container.read(recentSitesProvider.future);
  expect(pins, hasLength(2));
});

test('empty when no dives have sited GPS', () async {
  final pins = await container.read(recentSitesProvider.future);
  expect(pins, isEmpty);
});
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement provider** in `dashboard_providers.dart`:

```dart
class RecentSitePin {
  final String? siteName;
  final double latitude;
  final double longitude;
  const RecentSitePin({
    required this.siteName,
    required this.latitude,
    required this.longitude,
  });
}

/// Distinct GPS-bearing sites among the last 10 dives.
final recentSitesProvider = FutureProvider<List<RecentSitePin>>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final summaries = await repository.getDiveSummaries(
    diverId: currentDiverId,
    limit: 10,
  );
  final seen = <String>{};
  final pins = <RecentSitePin>[];
  for (final summary in summaries) {
    final lat = summary.siteLatitude;
    final lng = summary.siteLongitude;
    if (lat == null || lng == null) continue;
    if (seen.add('$lat,$lng')) {
      pins.add(
        RecentSitePin(siteName: summary.siteName, latitude: lat, longitude: lng),
      );
    }
  }
  return pins;
});
```

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: l10n key** (+ 10 locales): `"dashboard_recentSites_title": "Recent sites"`.

- [ ] **Step 6: Implement RecentSitesMapCard** by copying the embedded-map setup from `MatchSitesMap` (`match_sites_map.dart`): `MapController` in a `ConsumerStatefulWidget`, `TrackpadZoomMap` child with the standard tile layer + `MapAttribution`, `MarkerLayer` with one `Marker` per pin (standard `Icons.location_on` marker as used there), initial camera `CameraFit.bounds` over all pins (single pin: fixed zoom 11). Wrap in the Task-5 card chrome with `dashboard_recentSites_title`, `SizedBox(height: 220)`, `ClipRRect(borderRadius: 12)`. Tap anywhere -> `context.go('/sites')`. `valueOrNull ?? []`; empty -> `SizedBox.shrink()`. Do NOT add a widget test that pumps the map (tile/network flakiness — known repo trap); the provider test plus `flutter run` verification covers this card.

- [ ] **Step 7: `flutter gen-l10n`; run dashboard tests; format; commit**

```bash
flutter test test/features/dashboard
dart format .
git add lib/features/dashboard lib/l10n test/features/dashboard
git commit -m "feat(dashboard): recent sites map card"
```

---

### Task 9: DashboardPage assembly and legacy widget removal

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/dashboard_page.dart` (rewrite build)
- Delete: `lib/features/dashboard/presentation/widgets/personal_records_card.dart`
- Delete: `lib/features/dashboard/presentation/widgets/activity_stats_bar.dart`
- Delete: `lib/features/dashboard/presentation/widgets/alerts_card.dart`
- Delete: `lib/features/dashboard/presentation/widgets/service_due_card.dart`
- Delete: matching test files under `test/features/dashboard/presentation/widgets/` for the four deleted widgets
- Modify: `lib/features/dashboard/presentation/providers/dashboard_providers.dart` (remove `PersonalRecords` + `personalRecordsProvider`)
- Test: `test/features/dashboard/presentation/pages/dashboard_page_test.dart` (update/create)

**Interfaces:**
- Consumes: everything produced by Tasks 1-8, plus existing `PreDiveDashboardCard`, `ActiveCourseProgressCard`, `RecentDivesCard`, `QuickActionsCard`, `activeCoursesProgressProvider`.
- Produces: final `DashboardPage`; no API consumed by others.

- [ ] **Step 1: Pre-deletion reference check.** Run and act on:

```bash
grep -rn "personalRecordsProvider\|PersonalRecordsCard\|ActivityStatsBar\|AlertsCard\|ServiceDueCard\|monthlyDiveCountProvider\|yearToDateDiveCountProvider" lib test --include="*.dart" | grep -v "features/dashboard"
```

Expected: no hits outside `features/dashboard` (the Statistics records page has its own records providers). If `monthlyDiveCountProvider`/`yearToDateDiveCountProvider` have no remaining consumers after `ActivityStatsBar` is deleted, delete them and their tests too; if something else consumes them, keep them.

- [ ] **Step 2: Rewrite `DashboardPage.build`**

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  // Conditional-block gating: include a block while loading (the card
  // renders its own placeholder/shrink) or when it has content; exclude
  // it once it has definitively resolved to empty, so the grid backfills
  // without phantom spacing.
  bool show<T>(AsyncValue<T> value, bool Function(T data) hasContent) =>
      value.maybeWhen(data: hasContent, orElse: () => value.isLoading);

  final alerts = ref.watch(dashboardAlertsProvider);
  final milestones = ref.watch(milestonesProvider);
  final photos = ref.watch(recentPhotosProvider);
  final onThisDay = ref.watch(onThisDayProvider);
  final yearInReview = ref.watch(yearInReviewProvider);
  final courses = ref.watch(activeCoursesProgressProvider);
  final sites = ref.watch(recentSitesProvider);

  final entries = <DashboardEntry>[
    const FullBlock(HeroHeader()),
    const FullBlock(GaugeStrip()),
    if (show(alerts, (a) => a.serviceClocksDue.any(
            (c) => c.status.severity == ServiceClockSeverity.overdue) ||
        a.insuranceExpired))
      const FullBlock(UrgentBanner()),
    const FullBlock(PreDiveDashboardCard()),
    LeadSideGroup(
      lead: const RecentDivesCard(),
      side: [
        const QuickActionsCard(),
        if (show(milestones, (m) => !m.isEmpty)) const MilestonesCard(),
      ],
    ),
    if (show(photos, (p) => p.isNotEmpty)) const FullBlock(PhotoRibbonCard()),
    if (show(onThisDay, (d) => d.isNotEmpty))
      const ThirdBlock(OnThisDayCard()),
    if (show(yearInReview, (y) => y != null))
      const ThirdBlock(YearInReviewCard()),
    if (show(courses, (c) => c.isNotEmpty))
      const ThirdBlock(ActiveCourseProgressCard()),
    if (show(sites, (s) => s.isNotEmpty))
      const FullBlock(RecentSitesMapCard()),
  ];

  return Scaffold(
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(diveStatisticsProvider);
          ref.invalidate(recentDivesProvider);
          ref.invalidate(dashboardAlertsProvider);
          ref.invalidate(dashboardGaugesProvider);
          ref.invalidate(daysSinceLastDiveProvider);
          ref.invalidate(dashboardQuickStatsProvider);
          ref.invalidate(milestonesProvider);
          ref.invalidate(recentPhotosProvider);
          ref.invalidate(onThisDayProvider);
          ref.invalidate(yearInReviewProvider);
          ref.invalidate(recentSitesProvider);
          ref.invalidate(certificationListNotifierProvider);
          ref.invalidate(activeEquipmentClocksProvider);
          ref.invalidate(activeCoursesProgressProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: DashboardGrid(entries: entries),
        ),
      ),
    ),
  );
}
```

Update imports accordingly (remove deleted widgets, add new ones; check whether `activeCoursesProgressProvider`'s value type is a list — adjust the `show` predicate to its actual shape, mirroring how `ActiveCourseProgressCard` decides emptiness today).

- [ ] **Step 3: Delete the four legacy widgets, their tests, and `PersonalRecords`/`personalRecordsProvider`** (plus `monthlyDiveCountProvider`/`yearToDateDiveCountProvider` if Step 1 cleared them, including their cases in `test/features/dashboard/presentation/providers/dashboard_providers_test.dart` and `dashboard_queries_test.dart` if present).

- [ ] **Step 4: Update/create `dashboard_page_test.dart`.** Assert with base overrides + all new providers overridden to empty/neutral values: `HeroHeader`, `GaugeStrip`, `RecentDivesCard`, `QuickActionsCard` are present; `UrgentBanner`, `PhotoRibbonCard`, `OnThisDayCard`, `YearInReviewCard`, `RecentSitesMapCard` are absent (`findsNothing`). Then a second case with non-empty overrides asserting the conditional cards appear.

- [ ] **Step 5: Run the full dashboard feature tests**

Run: `flutter test test/features/dashboard`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A lib/features/dashboard test/features/dashboard
git commit -m "feat(dashboard): responsive monitor-first home page assembly"
```

---

### Task 10: Full verification sweep

**Files:**
- Modify (verify only / fix fallout): whole project.

- [ ] **Step 1: Confirm every new l10n key exists in all 11 ARB files.**

```bash
for f in lib/l10n/arb/app_*.arb; do
  echo "$f: $(grep -c 'dashboard_gauges_\|dashboard_hero_stat\|dashboard_milestones_\|dashboard_photos_\|dashboard_onThisDay_\|dashboard_yearInReview_\|dashboard_recentSites_\|dashboard_urgent_' $f)";
done
```

Expected: identical counts for every locale file (metadata `@`-entries only exist in `app_en.arb`, so compare non-`@` key counts). Then `flutter gen-l10n`.

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: `No issues found!` (infos are failures).

- [ ] **Step 3: Run the FULL test suite** (new provider deps in dashboard widgets can break unrelated consumers' tests without analyze noticing)

Run: `flutter test`
Expected: all pass. Known flaky suites (backup, media upload pipeline) may need a re-run in isolation before concluding a regression.

- [ ] **Step 4: Manual smoke on macOS**

Run: `flutter run -d macos`
Verify: 3-column layout at full-screen width, 2-column at ~1000px, single column below 800px; hero quiet stats appear only at desktop widths; gauge chips show real values; conditional cards absent for empty data; map card renders tiles; pull-to-refresh works.

- [ ] **Step 5: Format, final commit**

```bash
dart format .
git add -A
git commit -m "chore(dashboard): home redesign verification fixes"
```

(Only commit if the sweep produced changes.)
