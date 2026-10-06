# Dashboard Revamp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize the dashboard homepage from 7 vertically stacked sections to 4, integrating stats into the hero, compacting alerts, and placing records + quick actions side by side.

**Architecture:** The hero header widget gets the biggest rewrite -- absorbing the activity stats and career stats that previously lived in separate widgets. The dashboard page simplifies to 4 children. The alerts card, personal records card, and quick actions card get restyled but keep their existing providers.

**Tech Stack:** Flutter, Riverpod, Material 3, go_router, Drift (providers only -- no schema changes)

---

### Task 1: Add New Localization Keys

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`

New keys are needed for the hero stat labels. The existing keys for activity stats (`dashboard_activity_*`) and greeting (`dashboard_greeting_*`) stay in the ARB for now -- they'll be cleaned up after all widgets are migrated.

- [ ] **Step 1: Add new l10n keys to app_en.arb**

Add the following entries alongside the existing `dashboard_hero_*` keys (around line 1143 in `app_en.arb`):

```json
  "dashboard_hero_divesLoggedLabel": "dives logged",
  "dashboard_hero_hoursUnderwaterLabel": "hours underwater",
  "dashboard_hero_daysSinceLabel": "days since last dive",
  "dashboard_hero_thisMonthLabel": "this month",
  "dashboard_hero_thisYearLabel": "this year",
  "dashboard_hero_todayLabel": "today!",
  "dashboard_hero_noDivesLabel": "no dives yet",
  "dashboard_hero_diverFallbackName": "Diver",
  "dashboard_semantics_statsBar": "Dive statistics summary",
```

- [ ] **Step 2: Run codegen to regenerate localizations**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Succeeds, updates `lib/l10n/arb/app_localizations*.dart` files.

- [ ] **Step 3: Verify the new keys compile**

Run: `flutter analyze lib/l10n/`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/
git commit -m "feat(l10n): add dashboard hero stat label keys"
```

---

### Task 2: Rewrite Hero Header Widget

**Files:**
- Modify: `lib/features/dashboard/presentation/widgets/hero_header.dart`

This is the largest change. The hero keeps its ocean animation (`_OceanEffectPainter`, `_BubbleSpec`, `_bubbleSpecs`) but replaces the greeting + headline stats with: diver name + icon (top-right), career totals (left, large), and activity stats row (bottom, inline).

- [ ] **Step 1: Write the test for the new hero layout**

Create: `test/features/dashboard/presentation/widgets/hero_header_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/hero_header.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('HeroHeader', () {
    testWidgets('shows diver full name and career stats', (tester) async {
      final dives = [
        createTestDiveWithBottomTime(
          id: 'd1',
          bottomTime: const Duration(minutes: 60),
          maxDepth: 30.0,
        ),
        createTestDiveWithBottomTime(
          id: 'd2',
          bottomTime: const Duration(minutes: 45),
          maxDepth: 25.0,
        ),
      ];
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            divesProvider.overrideWith((ref) async => dives),
            currentDiverProvider.overrideWith(
              (ref) async => const Diver(
                id: '1',
                name: 'Eric Griffin',
              ),
            ),
          ].cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SingleChildScrollView(child: HeroHeader())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Diver name displayed
      expect(find.text('Eric Griffin'), findsOneWidget);
      // Total dives displayed
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('shows fallback name when no diver set', (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            divesProvider.overrideWith((ref) async => <dynamic>[]),
            currentDiverProvider.overrideWith((ref) async => null),
          ].cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SingleChildScrollView(child: HeroHeader())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Diver'), findsOneWidget);
    });

    testWidgets('does not display greeting text', (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            divesProvider.overrideWith((ref) async => <dynamic>[]),
            currentDiverProvider.overrideWith((ref) async => null),
          ].cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SingleChildScrollView(child: HeroHeader())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Good morning'), findsNothing);
      expect(find.text('Good afternoon'), findsNothing);
      expect(find.text('Good evening'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dashboard/presentation/widgets/hero_header_test.dart`
Expected: FAIL -- the current hero still shows greeting text and doesn't display the diver's full name prominently.

- [ ] **Step 3: Rewrite hero_header.dart**

Rewrite `lib/features/dashboard/presentation/widgets/hero_header.dart`. Keep the entire `_BubbleSpec` class, `_bubbleSpecs` constant, and `_OceanEffectPainter` class unchanged. Replace the `_HeroHeaderState.build` method and remove `_getGreeting` and `_buildHeadlineStats`.

The new build method should:
1. Watch `dashboardDiverProvider` for the name, `diveStatisticsProvider` for career totals, `daysSinceLastDiveProvider`, `monthlyDiveCountProvider`, `yearToDateDiveCountProvider` for the activity row
2. Keep the same gradient, border radius (20), and `ClipRRect` with `Stack`
3. Keep the `RepaintBoundary` + `AnimatedBuilder` + `_OceanEffectPainter` as the first child in the Stack
4. Replace the app icon `Positioned` with a new `Positioned(right: 16, top: 12)` containing a `Row` of: diver name `Text` (20px, bold, white, constrained to maxWidth 120, ellipsis overflow) + `SizedBox(width: 10)` + `Image.asset('assets/icon/icon.png', width: 52, height: 52)`
5. Replace the `Padding` content with a `Column` containing:
   - Career stats `Row`: two stat blocks (total dives + hours logged) with a vertical `Container(width: 1, height: 36)` divider between them. Values at 36px bold white, labels at `bodySmall` white 70% opacity. The Row has `padding-right: 190` to avoid the name+icon
   - `SizedBox(height: 14)`
   - Divider `Container(height: 1, color: white 10%)`
   - `SizedBox(height: 12)`
   - Activity stats `Row` with three inline pairs: value at `titleMedium` bold white + label at `labelSmall` white 60% opacity, separated by `SizedBox(width: 16)`

The `_formatHours` helper should be moved from `dashboard_page.dart` into this file (it's needed for the hours career stat).

For loading/error states: show placeholder values (`-` for numbers, fallback name) rather than a loading spinner, since the hero should always look complete.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dashboard/presentation/widgets/hero_header_test.dart`
Expected: PASS

- [ ] **Step 5: Run dart format**

Run: `dart format lib/features/dashboard/presentation/widgets/hero_header.dart test/features/dashboard/presentation/widgets/hero_header_test.dart`

- [ ] **Step 6: Commit**

```bash
git add lib/features/dashboard/presentation/widgets/hero_header.dart test/features/dashboard/presentation/widgets/hero_header_test.dart
git commit -m "feat(dashboard): rewrite hero header with integrated stats and diver name"
```

---

### Task 3: Rewrite Alerts Card as Compact Banner

**Files:**
- Modify: `lib/features/dashboard/presentation/widgets/alerts_card.dart`

Replace the full card layout with a single-line tappable banner. Keep the `AlertsCard` class name and `DashboardAlerts` data class (in providers file).

- [ ] **Step 1: Write the test for the compact alerts banner**

Create: `test/features/dashboard/presentation/widgets/alerts_card_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/alerts_card.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('AlertsCard compact banner', () {
    testWidgets('hidden when no alerts', (tester) async {
      final overrides = await getBaseOverrides();

      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: AlertsCard()),
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            serviceDueEquipmentProvider.overrideWith((ref) async => []),
            currentDiverProvider.overrideWith((ref) async => null),
          ].cast(),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render nothing
      expect(find.byType(AlertsCard), findsOneWidget);
      expect(find.byIcon(Icons.notification_important), findsNothing);
    });

    testWidgets('shows compact banner with alert count badge', (tester) async {
      final overrides = await getBaseOverrides();
      final equipment = EquipmentItem(
        id: 'eq1',
        name: 'Regulator',
        category: EquipmentCategory.regulator,
        nextServiceDate: DateTime.now().subtract(const Duration(days: 30)),
      );

      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: AlertsCard()),
        ),
        GoRoute(path: '/equipment/:id', builder: (_, __) => const Scaffold()),
        GoRoute(path: '/settings', builder: (_, __) => const Scaffold()),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            serviceDueEquipmentProvider.overrideWith(
              (ref) async => [equipment],
            ),
            currentDiverProvider.overrideWith((ref) async => null),
          ].cast(),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Badge count should be visible
      expect(find.text('1'), findsWidgets);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dashboard/presentation/widgets/alerts_card_test.dart`
Expected: FAIL -- the current `AlertsCard` has a different structure.

- [ ] **Step 3: Rewrite alerts_card.dart**

Rewrite `lib/features/dashboard/presentation/widgets/alerts_card.dart`. The `AlertsCard` widget stays as a `ConsumerWidget`. Replace `_AlertsCardContent` with a compact implementation:

- Single `GestureDetector` wrapping a `Container` styled as a banner:
  - `decoration`: `BoxDecoration` with `errorContainer.withValues(alpha: 0.3)` background, `Border.all(color: error.withValues(alpha: 0.2))`, `borderRadius: BorderRadius.circular(10)`
  - `padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10)`
  - Child: `Row` containing:
    - `Icon(Icons.warning_amber, color: error, size: 16)`
    - `SizedBox(width: 8)`
    - `Expanded(child: Text(alertText, style: bodyMedium, maxLines: 1, overflow: ellipsis))`
    - Badge `Container` with `error` background, circular border radius, showing `alerts.alertCount`
    - `SizedBox(width: 8)`
    - `Icon(Icons.chevron_right, size: 16, color: onSurfaceVariant)`
- `onTap`: if `alerts.alertCount == 1`, navigate to the specific target. If equipment: `context.push('/equipment/${equipment.id}')`. If insurance: `context.go('/settings')`. If multiple: `context.go('/settings')`.
- Alert text: show the first alert message. Priority order: insurance expired > insurance expiring > first equipment item's service message.

Remove the `_AlertTile` and `_EquipmentAlertTile` classes entirely.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dashboard/presentation/widgets/alerts_card_test.dart`
Expected: PASS

- [ ] **Step 5: Run dart format**

Run: `dart format lib/features/dashboard/presentation/widgets/alerts_card.dart test/features/dashboard/presentation/widgets/alerts_card_test.dart`

- [ ] **Step 6: Commit**

```bash
git add lib/features/dashboard/presentation/widgets/alerts_card.dart test/features/dashboard/presentation/widgets/alerts_card_test.dart
git commit -m "feat(dashboard): compact alerts banner replacing full card layout"
```

---

### Task 4: Restyle Personal Records Card

**Files:**
- Modify: `lib/features/dashboard/presentation/widgets/personal_records_card.dart`
- Modify: `test/features/dashboard/presentation/widgets/personal_records_card_test.dart`

Change from `Wrap` of `_RecordChip` widgets to a compact vertical list inside a `Card`. Remove site name subtitle. Keep navigation on tap.

- [ ] **Step 1: Update the existing test**

The existing test at `test/features/dashboard/presentation/widgets/personal_records_card_test.dart` checks for `'60min'` text. It should still pass after the restyle since we still display the value. No test changes needed for the restyle -- verify the existing test still passes after the change.

- [ ] **Step 2: Rewrite personal_records_card.dart**

Rewrite the widget. Remove the `_RecordChip` class entirely. The new `PersonalRecordsCard` build method:

- Still returns `SizedBox.shrink()` for loading, error, or no records
- When records exist, return a `Card` with `Padding(padding: EdgeInsets.all(12))` containing a `Column`:
  - Header `Row`: `Icon(Icons.emoji_events, size: 16, color: primary)` + `SizedBox(width: 6)` + `Text('Personal Records', style: bodyMedium.bold)`
  - `SizedBox(height: 10)`
  - For each non-null record (deepest, longest, coldest, warmest), a `_RecordRow` widget
- `_RecordRow` is a private `StatelessWidget` with: `label` (String), `value` (String), `color` (Color), `onTap` (VoidCallback?)
  - Renders: `InkWell` wrapping a `Padding(vertical: 4)` containing a `Row` with:
    - `Text(label, style: bodySmall.copyWith(color: onSurfaceVariant))` 
    - `Spacer()`
    - `Text(value, style: bodyMedium.copyWith(fontWeight: bold, color: color))`

Colors remain: deepest=`Colors.indigo`, longest=`Colors.teal`, coldest=`Colors.blue`, warmest=`Colors.orange`.

Values use the same `UnitFormatter` conversions as current. Drop the site name subtitle entirely.

- [ ] **Step 3: Run existing test to verify it passes**

Run: `flutter test test/features/dashboard/presentation/widgets/personal_records_card_test.dart`
Expected: PASS -- the `'60min'` text is still present.

- [ ] **Step 4: Run dart format**

Run: `dart format lib/features/dashboard/presentation/widgets/personal_records_card.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/features/dashboard/presentation/widgets/personal_records_card.dart
git commit -m "feat(dashboard): restyle personal records as compact vertical list"
```

---

### Task 5: Restyle Quick Actions Card

**Files:**
- Modify: `lib/features/dashboard/presentation/widgets/quick_actions_card.dart`

Change from wrapped buttons to vertical stack. Remove "Add Site" button. Remove the outer `Card` wrapper (the parent dashboard page will wrap it in a `Card`).

- [ ] **Step 1: Rewrite quick_actions_card.dart**

The `QuickActionsCard` build method returns a `Card` with `Padding(padding: EdgeInsets.all(12))` containing a `Column`:
- Header: `Text('Quick Actions', style: bodyMedium.bold)`
- `SizedBox(height: 10)`
- `Column` with `mainAxisSize: MainAxisSize.min` and 6px spacing between children:
  - `SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: showAddDiveBottomSheet..., icon: Icon(Icons.add), label: Text('Log Dive')))` 
  - `SizedBox(width: double.infinity, child: FilledButton.tonalIcon(onPressed: () => context.go('/planning/dive-planner'), icon: Icon(Icons.edit_calendar), label: Text('Plan Dive')))`
  - `SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => context.go('/statistics'), icon: Icon(Icons.bar_chart), label: Text('Statistics')))`

Use `SizedBox(width: double.infinity)` to make buttons full-width within the card.

Remove the "Add Site" button and its tooltip. Remove existing `Wrap` layout.

Keep localized labels using `context.l10n.dashboard_quickActions_*` keys.

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/dashboard/presentation/widgets/quick_actions_card.dart`
Expected: No issues found.

- [ ] **Step 3: Run dart format**

Run: `dart format lib/features/dashboard/presentation/widgets/quick_actions_card.dart`

- [ ] **Step 4: Commit**

```bash
git add lib/features/dashboard/presentation/widgets/quick_actions_card.dart
git commit -m "feat(dashboard): restyle quick actions as vertical button stack"
```

---

### Task 6: Rebuild Dashboard Page Layout

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/dashboard_page.dart`

This is where the 7-to-4 section reduction happens. Remove old widget imports and the stats section builder methods.

- [ ] **Step 1: Rewrite dashboard_page.dart**

The `DashboardPage` is currently a `ConsumerWidget`. Simplify it:

1. Remove imports: `activity_status_row.dart`, `stat_summary_card.dart`
2. Remove imports: `UnitFormatter`, `settingsProvider` (no longer needed here -- hero handles stats)
3. Remove the entire `_buildStatsSection`, `_buildStatsGrid`, `_buildStatsGridLoading`, `_buildStatsGridError` methods
4. Remove `_formatHours` (moved to hero_header.dart in Task 2)
5. The `build` method no longer needs `statsAsync`, `settings`, or `units` local variables

The new `Column` children in the `SingleChildScrollView`:
```
HeroHeader(),
SizedBox(height: 12),
AlertsCard(),
SizedBox(height: 12),
RecentDivesCard(),
SizedBox(height: 12),
_buildBottomRow(context, ref),
SizedBox(height: 24),
```

Add a `_buildBottomRow` method that returns:
```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Expanded(child: PersonalRecordsCard()),
    const SizedBox(width: 8),
    const Expanded(child: QuickActionsCard()),
  ],
)
```

The `RefreshIndicator.onRefresh` should still invalidate all the same providers (they're still used, just by different widgets now). Keep `diveStatisticsProvider` in the invalidation list even though it's consumed by the hero -- refresh should still reload everything.

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/dashboard/presentation/pages/dashboard_page.dart`
Expected: No issues found.

- [ ] **Step 3: Run dart format**

Run: `dart format lib/features/dashboard/presentation/pages/dashboard_page.dart`

- [ ] **Step 4: Commit**

```bash
git add lib/features/dashboard/presentation/pages/dashboard_page.dart
git commit -m "feat(dashboard): rebuild page layout - 4 sections from 7"
```

---

### Task 7: Delete Unused Widgets

**Files:**
- Delete: `lib/features/dashboard/presentation/widgets/activity_status_row.dart`
- Delete: `lib/features/dashboard/presentation/widgets/stat_summary_card.dart`
- Delete: `lib/features/dashboard/presentation/widgets/quick_stats_row.dart`

- [ ] **Step 1: Verify no remaining imports**

Run: `grep -r 'activity_status_row\|stat_summary_card\|quick_stats_row' lib/`
Expected: No matches (these are only imported by dashboard_page.dart which was updated in Task 6).

- [ ] **Step 2: Delete the files**

```bash
rm lib/features/dashboard/presentation/widgets/activity_status_row.dart
rm lib/features/dashboard/presentation/widgets/stat_summary_card.dart
rm lib/features/dashboard/presentation/widgets/quick_stats_row.dart
```

- [ ] **Step 3: Verify the project still compiles**

Run: `flutter analyze lib/features/dashboard/`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add -A lib/features/dashboard/presentation/widgets/
git commit -m "chore(dashboard): remove unused activity_status_row, stat_summary_card, quick_stats_row"
```

---

### Task 8: Update Existing Tests

**Files:**
- Modify: `test/features/dashboard/presentation/widgets/recent_dives_card_test.dart` (likely no changes needed)
- Verify: `test/features/dashboard/presentation/providers/dashboard_providers_test.dart` (no changes -- providers unchanged)

- [ ] **Step 1: Run the full dashboard test suite**

Run: `flutter test test/features/dashboard/`
Expected: All tests pass. If the recent dives card test or providers test fail, investigate and fix.

- [ ] **Step 2: Run flutter analyze on the full project dashboard files**

Run: `flutter analyze lib/features/dashboard/ test/features/dashboard/`
Expected: No issues found.

- [ ] **Step 3: Run dart format on all changed files**

Run: `dart format lib/features/dashboard/ test/features/dashboard/`
Expected: 0 changed (everything already formatted).

- [ ] **Step 4: Commit any test fixes**

Only if changes were needed:
```bash
git add test/features/dashboard/
git commit -m "test(dashboard): update tests for revamped layout"
```

---

### Task 9: Final Verification

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: All tests pass. Watch for failures in tests outside the dashboard that may reference deleted widgets or changed imports.

- [ ] **Step 2: Run flutter analyze on entire project**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Run dart format on all code**

Run: `dart format lib/ test/`
Expected: 0 changed.

- [ ] **Step 4: Manual verification**

Run: `flutter run -d macos`
Verify:
- Hero shows diver name (full name, 20px) left of app icon
- Hero shows career stats (large numbers) for total dives and hours
- Hero shows activity row (days since, this month, this year)
- Ocean animation (bubbles, caustics) still works
- Alerts banner appears if equipment service is due (compact single line)
- Alerts banner hidden if no alerts
- Recent dives section shows below alerts
- Records and Quick Actions sit side by side at the bottom
- "Log Dive" button opens the add dive bottom sheet
- "Plan Dive" navigates to dive planner
- "Statistics" navigates to statistics
- Pull-to-refresh reloads all data
- Test at narrow width (~375px) -- name truncates, layout doesn't overflow

- [ ] **Step 5: Final commit if any cleanup needed**

```bash
git add -A
git commit -m "fix(dashboard): final cleanup from revamp"
```
