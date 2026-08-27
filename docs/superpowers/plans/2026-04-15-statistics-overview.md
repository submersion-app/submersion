# Statistics Overview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a unified Statistics Overview page that works on both phone (<1100px) and desktop (≥1100px master-detail). Delivers the aggregate-stats section requested in [#167](https://github.com/submersion-app/submersion/issues/167): total dives, total time, lifetime avg dives/month, lifetime avg dives/year, deepest and longest dives, and more.

**Architecture:** Add `firstDiveDate` + three lifetime-average getters to the existing `DiveStatistics` class. Build a new `StatisticsOverviewPage` that composes four sections (aggregate stats grid, personal records, most visited sites, distributions). Wire it in as a new `overview` pseudo-category (first tile in the category list, with a divider separating it from the 9 domain categories) and as the desktop `MasterDetailScaffold.summaryBuilder` target. Delete the now-obsolete `StatisticsSummaryWidget`.

**Tech Stack:** Flutter, Riverpod, go_router, Drift (SQL aggregates), existing `UnitFormatter` for locale formatting, existing chart widgets used by `StatisticsSummaryWidget`.

---

## Spec correction note

The approved spec at [docs/superpowers/specs/2026-04-15-statistics-overview-design.md](../specs/2026-04-15-statistics-overview-design.md) describes creating a new `diveTypeDistributionProvider`. That provider **already exists** in [lib/features/statistics/presentation/providers/statistics_providers.dart:83](../../lib/features/statistics/presentation/providers/statistics_providers.dart#L83) and returns `List<DistributionSegment>` via the statistics repository. This plan reuses it rather than creating a new one. Task 6 uses the existing provider; no `DiveTypeCount` value type is needed.

## File Structure

### Modify

- `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (around lines 1635, 3941) — add `firstDiveDate` field, SQL `MIN(dive_date_time)` selection, three computed getters.
- `lib/features/statistics/presentation/pages/statistics_page.dart` — change `summaryBuilder` to new page; add `'overview'` branch in `_buildCategoryPage`; update mobile list separator.
- `lib/features/statistics/presentation/widgets/statistics_list_content.dart` — add `overview` `StatisticsCategory` at position 0; update list builder to draw a divider below it.
- `lib/core/router/app_router.dart` — add `overview` sub-route and import.
- `lib/l10n/arb/app_en.arb` and peer ARB files — add `statistics_category_overview_title` and `statistics_category_overview_subtitle`.

### Create

- `lib/features/statistics/presentation/pages/statistics_overview_page.dart` — the new page.
- `test/features/dive_log/data/dive_statistics_lifetime_averages_test.dart` — unit tests for new getters.
- `test/features/statistics/presentation/pages/statistics_overview_page_test.dart` — widget tests.
- `integration_test/statistics_overview_flow_test.dart` — integration test.

### Delete

- `lib/features/statistics/presentation/widgets/statistics_summary_widget.dart` — replaced by `StatisticsOverviewPage`.

---

## Task 1: Extend `DiveStatistics` with `firstDiveDate`

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (around lines 1635–1645 for SQL, 3941–3971 for class)
- Test: `test/features/dive_log/data/dive_statistics_lifetime_averages_test.dart` (create)

- [ ] **Step 1: Create the test file and write a failing test for the new field**

Create `test/features/dive_log/data/dive_statistics_lifetime_averages_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

void main() {
  group('DiveStatistics.firstDiveDate', () {
    test('accepts null firstDiveDate (no dives logged)', () {
      final stats = DiveStatistics(
        totalDives: 0,
        totalTimeSeconds: 0,
        maxDepth: 0,
        avgMaxDepth: 0,
        totalSites: 0,
      );
      expect(stats.firstDiveDate, isNull);
    });

    test('accepts a non-null firstDiveDate', () {
      final date = DateTime(2020, 1, 15);
      final stats = DiveStatistics(
        totalDives: 5,
        totalTimeSeconds: 3600,
        maxDepth: 20,
        avgMaxDepth: 15,
        totalSites: 2,
        firstDiveDate: date,
      );
      expect(stats.firstDiveDate, equals(date));
    });
  });
}
```

- [ ] **Step 2: Run the test — expect failure**

Run: `flutter test test/features/dive_log/data/dive_statistics_lifetime_averages_test.dart`
Expected: FAIL — `firstDiveDate` is not a named parameter of `DiveStatistics`.

- [ ] **Step 3: Add `firstDiveDate` field to the `DiveStatistics` class**

Edit `lib/features/dive_log/data/repositories/dive_repository_impl.dart` starting at line 3941:

```dart
class DiveStatistics {
  final int totalDives;
  final int totalTimeSeconds;
  final double maxDepth;
  final double avgMaxDepth;
  final double? avgTemperature;
  final int totalSites;
  final DateTime? firstDiveDate;
  final List<MonthlyDiveCount> divesByMonth;
  final List<DepthRangeStat> depthDistribution;
  final List<TopSiteStat> topSites;

  DiveStatistics({
    required this.totalDives,
    required this.totalTimeSeconds,
    required this.maxDepth,
    required this.avgMaxDepth,
    this.avgTemperature,
    required this.totalSites,
    this.firstDiveDate,
    this.divesByMonth = const [],
    this.depthDistribution = const [],
    this.topSites = const [],
  });

  Duration get totalTime => Duration(seconds: totalTimeSeconds);

  String get totalTimeFormatted {
    final hours = totalTime.inHours;
    final minutes = totalTime.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}
```

- [ ] **Step 4: Run the test — expect pass**

Run: `flutter test test/features/dive_log/data/dive_statistics_lifetime_averages_test.dart`
Expected: PASS.

- [ ] **Step 5: Update the SQL query to select `MIN(dive_date_time)`**

Edit `lib/features/dive_log/data/repositories/dive_repository_impl.dart` at lines 1635–1645. Replace the `SELECT` with:

```dart
      final stats = await _db.customSelect('''
      SELECT
        COUNT(*) as total_dives,
        SUM(COALESCE(runtime, bottom_time)) as total_time,
        MAX(max_depth) as max_depth,
        AVG(max_depth) as avg_max_depth,
        AVG(water_temp) as avg_temp,
        COUNT(DISTINCT site_id) as total_sites,
        MIN(dive_date_time) as first_dive_date
      FROM dives
      $whereClause
    ''', variables: vars).getSingle();
```

- [ ] **Step 6: Populate `firstDiveDate` when constructing `DiveStatistics`**

Find the `DiveStatistics(...)` constructor call at the bottom of `getStatistics()` (around line 1750). Add `firstDiveDate` parsing above the constructor call, then pass it in:

```dart
      final firstDiveEpochMs = stats.data['first_dive_date'] as int?;
      final firstDiveDate = firstDiveEpochMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(firstDiveEpochMs);

      return DiveStatistics(
        totalDives: (stats.data['total_dives'] as int?) ?? 0,
        totalTimeSeconds: (stats.data['total_time'] as int?) ?? 0,
        maxDepth: ((stats.data['max_depth'] as num?) ?? 0).toDouble(),
        avgMaxDepth: ((stats.data['avg_max_depth'] as num?) ?? 0).toDouble(),
        avgTemperature: (stats.data['avg_temp'] as num?)?.toDouble(),
        totalSites: (stats.data['total_sites'] as int?) ?? 0,
        firstDiveDate: firstDiveDate,
        divesByMonth: divesByMonth,
        depthDistribution: depthRanges,
        topSites: topSites,
      );
```

Note: the exact field names on the left of each `:` are already present in the existing constructor call — verify against the real file and only add `firstDiveDate: firstDiveDate,`. Do not rewrite already-correct fields.

- [ ] **Step 7: Run the full test suite to confirm no regression**

Run: `flutter test test/features/dive_log/`
Expected: PASS for all previously passing tests plus the new one.

- [ ] **Step 8: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart \
        test/features/dive_log/data/dive_statistics_lifetime_averages_test.dart
git commit -m "feat(statistics): add firstDiveDate to DiveStatistics (#167)"
```

---

## Task 2: Add lifetime-average getters

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (inside the `DiveStatistics` class, around line 3970)
- Modify: `test/features/dive_log/data/dive_statistics_lifetime_averages_test.dart` (extend existing file)

- [ ] **Step 1: Add failing tests for `monthsSinceFirstDive`, `divesPerMonth`, and `divesPerYear`**

Append to `test/features/dive_log/data/dive_statistics_lifetime_averages_test.dart`:

```dart
  group('DiveStatistics.monthsSinceFirstDive', () {
    test('returns null when firstDiveDate is null', () {
      final stats = DiveStatistics(
        totalDives: 0,
        totalTimeSeconds: 0,
        maxDepth: 0,
        avgMaxDepth: 0,
        totalSites: 0,
      );
      expect(stats.monthsSinceFirstDive, isNull);
    });

    test('returns null when firstDiveDate is in the future', () {
      final future = DateTime.now().add(const Duration(days: 10));
      final stats = DiveStatistics(
        totalDives: 1,
        totalTimeSeconds: 3000,
        maxDepth: 18,
        avgMaxDepth: 18,
        totalSites: 1,
        firstDiveDate: future,
      );
      expect(stats.monthsSinceFirstDive, isNull);
    });

    test('returns null when tenure is under 1 month', () {
      final recent = DateTime.now().subtract(const Duration(days: 10));
      final stats = DiveStatistics(
        totalDives: 3,
        totalTimeSeconds: 9000,
        maxDepth: 20,
        avgMaxDepth: 15,
        totalSites: 1,
        firstDiveDate: recent,
      );
      expect(stats.monthsSinceFirstDive, isNull);
    });

    test('returns approximately 12 for a 1-year tenure', () {
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      final stats = DiveStatistics(
        totalDives: 24,
        totalTimeSeconds: 86400,
        maxDepth: 30,
        avgMaxDepth: 20,
        totalSites: 5,
        firstDiveDate: oneYearAgo,
      );
      expect(stats.monthsSinceFirstDive, closeTo(12.0, 0.5));
    });
  });

  group('DiveStatistics.divesPerMonth', () {
    test('returns null when monthsSinceFirstDive is null', () {
      final stats = DiveStatistics(
        totalDives: 5,
        totalTimeSeconds: 0,
        maxDepth: 0,
        avgMaxDepth: 0,
        totalSites: 0,
      );
      expect(stats.divesPerMonth, isNull);
    });

    test('divides totalDives by months for a 1-year diver', () {
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      final stats = DiveStatistics(
        totalDives: 24,
        totalTimeSeconds: 86400,
        maxDepth: 30,
        avgMaxDepth: 20,
        totalSites: 5,
        firstDiveDate: oneYearAgo,
      );
      expect(stats.divesPerMonth, closeTo(2.0, 0.2));
    });
  });

  group('DiveStatistics.divesPerYear', () {
    test('returns null when monthsSinceFirstDive is null', () {
      final stats = DiveStatistics(
        totalDives: 5,
        totalTimeSeconds: 0,
        maxDepth: 0,
        avgMaxDepth: 0,
        totalSites: 0,
      );
      expect(stats.divesPerYear, isNull);
    });

    test('divides totalDives by years for a 2-year diver', () {
      final twoYearsAgo = DateTime.now().subtract(const Duration(days: 730));
      final stats = DiveStatistics(
        totalDives: 40,
        totalTimeSeconds: 144000,
        maxDepth: 40,
        avgMaxDepth: 25,
        totalSites: 10,
        firstDiveDate: twoYearsAgo,
      );
      expect(stats.divesPerYear, closeTo(20.0, 1.0));
    });
  });
```

- [ ] **Step 2: Run tests — expect failures**

Run: `flutter test test/features/dive_log/data/dive_statistics_lifetime_averages_test.dart`
Expected: FAIL — getters do not exist.

- [ ] **Step 3: Add the three getters to `DiveStatistics`**

In `lib/features/dive_log/data/repositories/dive_repository_impl.dart`, inside the `DiveStatistics` class, add after the existing `totalTimeFormatted` getter:

```dart
  /// Lifetime tenure in months since the diver's first dive.
  /// Returns null if no dives, firstDiveDate is in the future, or tenure < 1 month.
  double? get monthsSinceFirstDive {
    final first = firstDiveDate;
    if (first == null) return null;
    final now = DateTime.now();
    if (first.isAfter(now)) return null;
    final months = now.difference(first).inDays / 30.44;
    return months < 1 ? null : months;
  }

  /// Lifetime average dives per month. Returns null when tenure is unavailable.
  double? get divesPerMonth {
    final months = monthsSinceFirstDive;
    return months == null ? null : totalDives / months;
  }

  /// Lifetime average dives per year. Returns null when tenure is unavailable.
  double? get divesPerYear {
    final months = monthsSinceFirstDive;
    return months == null ? null : totalDives / (months / 12);
  }
```

- [ ] **Step 4: Run tests — expect pass**

Run: `flutter test test/features/dive_log/data/dive_statistics_lifetime_averages_test.dart`
Expected: PASS.

- [ ] **Step 5: Run `dart format` on touched files**

Run: `dart format lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/dive_statistics_lifetime_averages_test.dart`
Expected: no output or "formatted N files" — no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart \
        test/features/dive_log/data/dive_statistics_lifetime_averages_test.dart
git commit -m "feat(statistics): add lifetime avg dives/month and avg dives/year getters (#167)"
```

---

## Task 3: Create `StatisticsOverviewPage` with aggregate stats grid

**Files:**
- Create: `lib/features/statistics/presentation/pages/statistics_overview_page.dart`
- Create: `test/features/statistics/presentation/pages/statistics_overview_page_test.dart`

- [ ] **Step 1: Write a failing widget test for the aggregate grid**

Create `test/features/statistics/presentation/pages/statistics_overview_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_overview_page.dart';

void main() {
  group('StatisticsOverviewPage aggregate cards', () {
    testWidgets('renders total dives, total time, max depth, and sites', (tester) async {
      final fixture = DiveStatistics(
        totalDives: 42,
        totalTimeSeconds: 108000, // 30h 0m
        maxDepth: 38.5,
        avgMaxDepth: 18.2,
        avgTemperature: 24.0,
        totalSites: 7,
        firstDiveDate: DateTime.now().subtract(const Duration(days: 730)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => fixture),
          ],
          child: const MaterialApp(home: StatisticsOverviewPage(embedded: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget);        // total dives
      expect(find.textContaining('30h'), findsOneWidget); // total time
      expect(find.textContaining('7'), findsWidgets); // sites (may appear elsewhere)
    });
  });
}
```

- [ ] **Step 2: Run the test — expect failure**

Run: `flutter test test/features/statistics/presentation/pages/statistics_overview_page_test.dart`
Expected: FAIL — `StatisticsOverviewPage` does not exist.

- [ ] **Step 3: Create the page skeleton with the aggregate grid**

Create `lib/features/statistics/presentation/pages/statistics_overview_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class StatisticsOverviewPage extends ConsumerWidget {
  final bool embedded;
  const StatisticsOverviewPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(diveStatisticsProvider);

    final body = statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorCard(onRetry: () => ref.invalidate(diveStatisticsProvider)),
      data: (stats) => _OverviewBody(stats: stats),
    );

    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.statistics_category_overview_title)),
      body: body,
    );
  }
}

class _OverviewBody extends ConsumerWidget {
  final DiveStatistics stats;
  const _OverviewBody({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final fmt = UnitFormatter(settings);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AggregateGrid(stats: stats, fmt: fmt),
        ],
      ),
    );
  }
}

class _AggregateGrid extends StatelessWidget {
  final DiveStatistics stats;
  final UnitFormatter fmt;
  const _AggregateGrid({required this.stats, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 600;
    final crossAxis = wide ? 4 : 2;
    final cards = <_StatCard>[
      _StatCard(label: 'Total Dives', value: '${stats.totalDives}'),
      _StatCard(label: 'Total Time', value: _formatDuration(stats.totalTimeSeconds)),
      _StatCard(label: 'Max Depth', value: fmt.formatDepth(stats.maxDepth)),
      _StatCard(label: 'Avg Depth', value: fmt.formatDepth(stats.avgMaxDepth)),
      if (stats.divesPerMonth != null)
        _StatCard(label: 'Dives / Month', value: stats.divesPerMonth!.toStringAsFixed(1)),
      if (stats.divesPerYear != null)
        _StatCard(label: 'Dives / Year', value: stats.divesPerYear!.toStringAsFixed(1)),
      _StatCard(label: 'Sites Visited', value: '${stats.totalSites}'),
      if (stats.avgTemperature != null)
        _StatCard(label: 'Avg Water Temp', value: fmt.formatTemperature(stats.avgTemperature!)),
    ];

    return GridView.count(
      crossAxisCount: crossAxis,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: cards,
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            )),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            const Text("Couldn't load statistics"),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test — expect pass**

Run: `flutter test test/features/statistics/presentation/pages/statistics_overview_page_test.dart`
Expected: PASS. Labels `Total Dives`, `Total Time`, `Sites Visited` are literal strings in Task 3 (localized in Task 8). Don't localize yet.

- [ ] **Step 5: Run `dart format`**

Run: `dart format lib/features/statistics/presentation/pages/statistics_overview_page.dart test/features/statistics/presentation/pages/statistics_overview_page_test.dart`

- [ ] **Step 6: Run `flutter analyze` for the statistics feature**

Run: `flutter analyze lib/features/statistics/ test/features/statistics/`
Expected: no analysis issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/statistics/presentation/pages/statistics_overview_page.dart \
        test/features/statistics/presentation/pages/statistics_overview_page_test.dart
git commit -m "feat(statistics): add StatisticsOverviewPage with aggregate grid (#167)"
```

---

## Task 4: Add Personal Records section

**Files:**
- Modify: `lib/features/statistics/presentation/pages/statistics_overview_page.dart`
- Modify: `test/features/statistics/presentation/pages/statistics_overview_page_test.dart`

- [ ] **Step 1: Add a failing test for the records section**

Append to the existing test file inside the existing `main()` function (add a new `group`):

```dart
  group('StatisticsOverviewPage Personal Records', () {
    testWidgets('renders deepest and longest records', (tester) async {
      final stats = DiveStatistics(
        totalDives: 10,
        totalTimeSeconds: 18000,
        maxDepth: 35.0,
        avgMaxDepth: 20.0,
        totalSites: 3,
        firstDiveDate: DateTime.now().subtract(const Duration(days: 365)),
      );
      // Deepest dive fixture: depth=35, date=2025-01-10
      final deepest = Dive(
        id: 'd1',
        diveNumber: 5,
        diveDateTime: DateTime(2025, 1, 10),
        maxDepth: 35.0,
        bottomTime: 2400, // 40 min
      );
      final records = DiveRecords(deepest: deepest, longest: deepest);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            diveRecordsProvider.overrideWith((ref) async => records),
          ],
          child: const MaterialApp(home: StatisticsOverviewPage(embedded: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Personal Records'), findsOneWidget);
      expect(find.text('Deepest Dive'), findsOneWidget);
      expect(find.text('Longest Dive'), findsOneWidget);
    });
  });
```

At the top of the test file, add the missing import for `Dive`:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
```

- [ ] **Step 2: Run the test — expect failure**

Run: `flutter test test/features/statistics/presentation/pages/statistics_overview_page_test.dart`
Expected: FAIL — "Personal Records" text not found.

- [ ] **Step 3: Add the records section widget**

In `lib/features/statistics/presentation/pages/statistics_overview_page.dart`:

1. Add imports at the top:

```dart
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
```

2. Extend `_OverviewBody` to watch records and render the section. Replace the existing `_OverviewBody` class body with:

```dart
class _OverviewBody extends ConsumerWidget {
  final DiveStatistics stats;
  const _OverviewBody({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final fmt = UnitFormatter(settings);
    final recordsAsync = ref.watch(diveRecordsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AggregateGrid(stats: stats, fmt: fmt),
          const SizedBox(height: 16),
          recordsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const _InlineError(message: 'Records unavailable'),
            data: (records) => _RecordsSection(records: records, fmt: fmt),
          ),
        ],
      ),
    );
  }
}
```

3. Add the `_RecordsSection` widget and supporting helpers at the bottom of the file:

```dart
class _RecordsSection extends StatelessWidget {
  final DiveRecords records;
  final UnitFormatter fmt;
  const _RecordsSection({required this.records, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (records.deepest != null) {
      rows.add(_RecordTile(
        label: 'Deepest Dive',
        value: fmt.formatDepth(records.deepest!.maxDepth),
        subtitle: _dateLabel(records.deepest!.diveDateTime),
        onTap: () => context.go('/dives/${records.deepest!.id}'),
      ));
    }
    if (records.longest != null) {
      rows.add(_RecordTile(
        label: 'Longest Dive',
        value: _formatMinutes(records.longest!.bottomTime ?? 0),
        subtitle: _dateLabel(records.longest!.diveDateTime),
        onTap: () => context.go('/dives/${records.longest!.id}'),
      ));
    }
    if (records.coldest != null) {
      rows.add(_RecordTile(
        label: 'Coldest Dive',
        value: fmt.formatTemperature(records.coldest!.waterTemp ?? 0),
        subtitle: _dateLabel(records.coldest!.diveDateTime),
        onTap: () => context.go('/dives/${records.coldest!.id}'),
      ));
    }
    if (records.warmest != null) {
      rows.add(_RecordTile(
        label: 'Warmest Dive',
        value: fmt.formatTemperature(records.warmest!.waterTemp ?? 0),
        subtitle: _dateLabel(records.warmest!.diveDateTime),
        onTap: () => context.go('/dives/${records.warmest!.id}'),
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text('Personal Records',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            ...rows,
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatMinutes(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

class _RecordTile extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final VoidCallback onTap;
  const _RecordTile({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(subtitle),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    );
  }
}
```

- [ ] **Step 4: Run the test — expect pass**

Run: `flutter test test/features/statistics/presentation/pages/statistics_overview_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Add a tap-navigation test**

Append another test inside the "Personal Records" group:

```dart
    testWidgets('tapping a record navigates to dive detail', (tester) async {
      final stats = DiveStatistics(
        totalDives: 1, totalTimeSeconds: 3000, maxDepth: 20, avgMaxDepth: 20, totalSites: 1,
      );
      final deepest = Dive(
        id: 'dive-xyz', diveNumber: 1,
        diveDateTime: DateTime(2025, 3, 1),
        maxDepth: 20, bottomTime: 3000,
      );
      final records = DiveRecords(deepest: deepest);

      String? navigatedTo;
      final router = GoRouter(
        initialLocation: '/statistics/overview',
        routes: [
          GoRoute(path: '/statistics/overview', builder: (_, __) => const StatisticsOverviewPage(embedded: true)),
          GoRoute(path: '/dives/:id', builder: (ctx, state) {
            navigatedTo = '/dives/${state.pathParameters['id']}';
            return const Scaffold(body: Text('Dive Detail'));
          }),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            diveRecordsProvider.overrideWith((ref) async => records),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deepest Dive'));
      await tester.pumpAndSettle();

      expect(navigatedTo, equals('/dives/dive-xyz'));
    });
```

Add the import for `GoRouter` at the top of the test file:

```dart
import 'package:go_router/go_router.dart';
```

- [ ] **Step 6: Run the test — expect pass**

Run: `flutter test test/features/statistics/presentation/pages/statistics_overview_page_test.dart`
Expected: PASS for all tests.

- [ ] **Step 7: Format and analyze**

Run: `dart format lib/features/statistics/ test/features/statistics/ && flutter analyze lib/features/statistics/ test/features/statistics/`
Expected: no changes needed; no analyzer issues.

- [ ] **Step 8: Commit**

```bash
git add lib/features/statistics/presentation/pages/statistics_overview_page.dart \
        test/features/statistics/presentation/pages/statistics_overview_page_test.dart
git commit -m "feat(statistics): add Personal Records section to overview (#167)"
```

---

## Task 5: Add Most Visited Sites section

**Files:**
- Modify: `lib/features/statistics/presentation/pages/statistics_overview_page.dart`
- Modify: `test/features/statistics/presentation/pages/statistics_overview_page_test.dart`

- [ ] **Step 1: Write failing test**

Add a new `group` at the bottom of the existing test `main()`:

```dart
  group('StatisticsOverviewPage Most Visited Sites', () {
    testWidgets('renders top sites from stats.topSites', (tester) async {
      final stats = DiveStatistics(
        totalDives: 20, totalTimeSeconds: 72000, maxDepth: 30, avgMaxDepth: 20, totalSites: 3,
        topSites: [
          TopSiteStat(siteId: 's1', siteName: 'Blue Hole', diveCount: 10),
          TopSiteStat(siteId: 's2', siteName: 'Shark Point', diveCount: 6),
          TopSiteStat(siteId: 's3', siteName: 'Reef 3', diveCount: 4),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [diveStatisticsProvider.overrideWith((ref) async => stats)],
          child: const MaterialApp(home: StatisticsOverviewPage(embedded: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Most Visited Sites'), findsOneWidget);
      expect(find.text('Blue Hole'), findsOneWidget);
      expect(find.text('Shark Point'), findsOneWidget);
      expect(find.text('Reef 3'), findsOneWidget);
    });

    testWidgets('hides section when topSites is empty', (tester) async {
      final stats = DiveStatistics(
        totalDives: 5, totalTimeSeconds: 18000, maxDepth: 15, avgMaxDepth: 10, totalSites: 0,
        topSites: [],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [diveStatisticsProvider.overrideWith((ref) async => stats)],
          child: const MaterialApp(home: StatisticsOverviewPage(embedded: true)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Most Visited Sites'), findsNothing);
    });
  });
```

- [ ] **Step 2: Run the test — expect failure**

Run: `flutter test test/features/statistics/presentation/pages/statistics_overview_page_test.dart`
Expected: FAIL — section not rendered.

- [ ] **Step 3: Add the `_TopSitesSection` widget**

In `statistics_overview_page.dart`, extend `_OverviewBody.build` to add the section after `_RecordsSection`:

```dart
          _RecordsSection returns... // (existing)
          const SizedBox(height: 16),
          _TopSitesSection(sites: stats.topSites),
```

Append a new widget class at the bottom of the file:

```dart
class _TopSitesSection extends StatelessWidget {
  final List<TopSiteStat> sites;
  const _TopSitesSection({required this.sites});

  @override
  Widget build(BuildContext context) {
    if (sites.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text('Most Visited Sites',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            for (final site in sites.take(5))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(site.siteName),
                subtitle: Text('${site.diveCount} dives'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/sites/${site.siteId}'),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test — expect pass**

Run: `flutter test test/features/statistics/presentation/pages/statistics_overview_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and analyze**

Run: `dart format lib/features/statistics/ test/features/statistics/ && flutter analyze lib/features/statistics/ test/features/statistics/`
Expected: no changes; no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/statistics/presentation/pages/statistics_overview_page.dart \
        test/features/statistics/presentation/pages/statistics_overview_page_test.dart
git commit -m "feat(statistics): add Most Visited Sites section to overview (#167)"
```

---

## Task 6: Add Distributions section (reuses existing providers)

**Files:**
- Modify: `lib/features/statistics/presentation/pages/statistics_overview_page.dart`
- Modify: `test/features/statistics/presentation/pages/statistics_overview_page_test.dart`

**Note:** Reuses the existing `diveTypeDistributionProvider` from `statistics_providers.dart:83` (returns `List<DistributionSegment>`). Also consumes `stats.depthDistribution` for the depth pie.

- [ ] **Step 1: Look up how `StatisticsSummaryWidget` renders its two pies**

Read `lib/features/statistics/presentation/widgets/statistics_summary_widget.dart` around the lines that render `depthDistribution` and `diveType` pies (approximately lines 450 and 532 per the exploration). Identify which pie widget it uses (e.g., `DistributionPieChart` or similar). Copy the exact widget used so the new page matches.

(Agent: confirm the pie widget class name before writing code — examples below assume `DistributionPieChart` and `DistributionSegment`; adjust if the codebase uses different names.)

- [ ] **Step 2: Write failing test for the Distributions section**

Append to the test file:

```dart
  group('StatisticsOverviewPage Distributions', () {
    testWidgets('renders depth and type pies when data is present', (tester) async {
      final stats = DiveStatistics(
        totalDives: 20, totalTimeSeconds: 72000, maxDepth: 30, avgMaxDepth: 18, totalSites: 2,
        depthDistribution: [
          DepthRangeStat(label: '0-10m', minDepth: 0, maxDepth: 10, count: 4),
          DepthRangeStat(label: '10-20m', minDepth: 10, maxDepth: 20, count: 10),
          DepthRangeStat(label: '20-30m', minDepth: 20, maxDepth: 30, count: 6),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [diveStatisticsProvider.overrideWith((ref) async => stats)],
          child: const MaterialApp(home: StatisticsOverviewPage(embedded: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Distributions'), findsOneWidget);
    });

    testWidgets('hides Distributions when totalDives is 0', (tester) async {
      final stats = DiveStatistics(
        totalDives: 0, totalTimeSeconds: 0, maxDepth: 0, avgMaxDepth: 0, totalSites: 0,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [diveStatisticsProvider.overrideWith((ref) async => stats)],
          child: const MaterialApp(home: StatisticsOverviewPage(embedded: true)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Distributions'), findsNothing);
    });
  });
```

- [ ] **Step 3: Run the test — expect failure**

Run: `flutter test test/features/statistics/presentation/pages/statistics_overview_page_test.dart`
Expected: FAIL — "Distributions" text not found.

- [ ] **Step 4: Add the Distributions section**

In `statistics_overview_page.dart`, add imports:

```dart
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart'; // for DistributionSegment
```

Extend `_OverviewBody` to render Distributions only when `stats.totalDives > 0`, after `_TopSitesSection`:

```dart
          if (stats.totalDives > 0) ...[
            const SizedBox(height: 16),
            _DistributionsSection(depthDistribution: stats.depthDistribution),
          ],
```

Add the `_DistributionsSection` widget at the bottom of the file. This uses the existing `diveTypeDistributionProvider`:

```dart
class _DistributionsSection extends ConsumerWidget {
  final List<DepthRangeStat> depthDistribution;
  const _DistributionsSection({required this.depthDistribution});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(diveTypeDistributionProvider);
    final wide = MediaQuery.of(context).size.width >= 600;

    final depthPie = _DepthPie(depthDistribution: depthDistribution);
    final typesPie = typesAsync.when(
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const _InlineError(message: 'Dive types unavailable'),
      data: (segments) => _TypesPie(segments: segments),
    );

    final children = wide
        ? Row(children: [Expanded(child: depthPie), const SizedBox(width: 12), Expanded(child: typesPie)])
        : Column(children: [depthPie, const SizedBox(height: 12), typesPie]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text('Distributions',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            children,
          ],
        ),
      ),
    );
  }
}
```

For `_DepthPie` and `_TypesPie`: agent must open `statistics_summary_widget.dart` and extract or reference the exact pie-chart construction used there for the depth pie (using `DepthRangeStat`) and the type pie (using `DistributionSegment`). Copy the construction verbatim into these two small wrapper widgets so the rendering looks identical to today's desktop summary. Do not invent a new chart library — reuse what the codebase already ships.

- [ ] **Step 5: Run the test — expect pass**

Run: `flutter test test/features/statistics/presentation/pages/statistics_overview_page_test.dart`
Expected: PASS.

- [ ] **Step 6: Format and analyze**

Run: `dart format lib/features/statistics/ test/features/statistics/ && flutter analyze lib/features/statistics/ test/features/statistics/`

- [ ] **Step 7: Commit**

```bash
git add lib/features/statistics/presentation/pages/statistics_overview_page.dart \
        test/features/statistics/presentation/pages/statistics_overview_page_test.dart
git commit -m "feat(statistics): add Distributions section to overview (#167)"
```

---

## Task 7: Empty state and tenure edge cases

**Files:**
- Modify: `lib/features/statistics/presentation/pages/statistics_overview_page.dart`
- Modify: `test/features/statistics/presentation/pages/statistics_overview_page_test.dart`

- [ ] **Step 1: Write failing tests for edge cases**

Append to the test file:

```dart
  group('StatisticsOverviewPage edge cases', () {
    testWidgets('zero dives shows empty state with action buttons', (tester) async {
      final stats = DiveStatistics(
        totalDives: 0, totalTimeSeconds: 0, maxDepth: 0, avgMaxDepth: 0, totalSites: 0,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [diveStatisticsProvider.overrideWith((ref) async => stats)],
          child: const MaterialApp(home: StatisticsOverviewPage(embedded: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No dives logged yet'), findsOneWidget);
      expect(find.text('Log a Dive'), findsOneWidget);
      expect(find.text('Import Dives'), findsOneWidget);
      expect(find.text('Total Dives'), findsNothing);
    });

    testWidgets('tenure under 1 month hides Dives/Month and Dives/Year cards', (tester) async {
      final recent = DateTime.now().subtract(const Duration(days: 10));
      final stats = DiveStatistics(
        totalDives: 3, totalTimeSeconds: 9000, maxDepth: 20, avgMaxDepth: 15, totalSites: 1,
        firstDiveDate: recent,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [diveStatisticsProvider.overrideWith((ref) async => stats)],
          child: const MaterialApp(home: StatisticsOverviewPage(embedded: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Dives'), findsOneWidget);
      expect(find.text('Dives / Month'), findsNothing);
      expect(find.text('Dives / Year'), findsNothing);
    });
  });
```

- [ ] **Step 2: Run the tests — expect failure**

Run: `flutter test test/features/statistics/presentation/pages/statistics_overview_page_test.dart`
Expected: FAIL on empty-state assertions; the tenure-gate test may already pass due to Task 3 card conditionals. Fix empty-state first.

- [ ] **Step 3: Add the empty state branch**

In `_OverviewBody.build`, guard the entire content on `stats.totalDives > 0`:

```dart
    if (stats.totalDives == 0) {
      return const _EmptyState();
    }
```

Add `_EmptyState` widget at the bottom of the file:

```dart
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.water_drop_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('No dives logged yet'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => context.go('/dives/new'),
                  child: const Text('Log a Dive'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => context.go('/import'),
                  child: const Text('Import Dives'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

Note: the exact import route is whatever path is registered for the unified-import entry in `app_router.dart`. Agent should grep for `/import` registration and adjust the path if different.

- [ ] **Step 4: Run tests — expect pass**

Run: `flutter test test/features/statistics/presentation/pages/statistics_overview_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/statistics/ test/features/statistics/
flutter analyze lib/features/statistics/ test/features/statistics/
git add lib/features/statistics/presentation/pages/statistics_overview_page.dart \
        test/features/statistics/presentation/pages/statistics_overview_page_test.dart
git commit -m "feat(statistics): handle empty-state and tenure-gate in overview (#167)"
```

---

## Task 8: Register `overview` category tile and add l10n strings

**Files:**
- Modify: `lib/features/statistics/presentation/widgets/statistics_list_content.dart`
- Modify: `lib/features/statistics/presentation/pages/statistics_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` (and any other ARB files the project ships)

- [ ] **Step 1: Add l10n keys to `app_en.arb`**

Open `lib/l10n/arb/app_en.arb` and find the existing `statistics_category_gas_title` entry. Above it, add:

```json
    "statistics_category_overview_title": "Overview",
    "@statistics_category_overview_title": {
      "description": "Title for the Overview entry in the Statistics category list"
    },
    "statistics_category_overview_subtitle": "Totals, records, and breakdowns at a glance",
    "@statistics_category_overview_subtitle": {
      "description": "Subtitle for the Overview entry in the Statistics category list"
    },
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: l10n generated files updated. If the project uses `build_runner`, run: `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 3: Add the `overview` category as the first entry**

Edit `lib/features/statistics/presentation/widgets/statistics_list_content.dart`. Change `statisticsCategoriesOf(context)` to:

```dart
List<StatisticsCategory> statisticsCategoriesOf(BuildContext context) => [
  StatisticsCategory(
    id: 'overview',
    icon: Icons.dashboard_outlined,
    title: context.l10n.statistics_category_overview_title,
    subtitle: context.l10n.statistics_category_overview_subtitle,
    color: Colors.blueGrey,
  ),
  StatisticsCategory(
    id: 'gas',
    icon: Icons.air,
    // ...existing entries unchanged...
```

Leave every other entry unchanged.

- [ ] **Step 4: Update the mobile list separator to show a divider below Overview**

In `lib/features/statistics/presentation/pages/statistics_page.dart`, inside `StatisticsMobileContent.build`, replace the existing `separatorBuilder` on `ListView.separated`:

```dart
        separatorBuilder: (context, index) {
          // Emphasize divider between Overview (index 0) and the rest.
          if (index == 0) {
            return const Divider(height: 16, thickness: 1);
          }
          return const Divider(height: 1);
        },
```

- [ ] **Step 5: Add `overview` branch to `_buildCategoryPage`**

In the same `statistics_page.dart`, add an import at the top:

```dart
import 'package:submersion/features/statistics/presentation/pages/statistics_overview_page.dart';
```

Extend the `switch` in `_buildCategoryPage`:

```dart
      case 'overview':
        return const StatisticsOverviewPage(embedded: true);
```

- [ ] **Step 6: Run the app briefly on macOS to confirm nothing crashes**

Run: `flutter run -d macos` in a detached window. Navigate to Statistics. Confirm "Overview" appears as the top list entry with a prominent divider below it. Tap it — the Overview page should render in the detail pane (desktop) or push full-page (phone sizes).

Quit with `q` in the Flutter terminal.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/statistics/ lib/l10n/
git add lib/features/statistics/presentation/widgets/statistics_list_content.dart \
        lib/features/statistics/presentation/pages/statistics_page.dart \
        lib/l10n/arb/
git commit -m "feat(statistics): register Overview category tile with divider (#167)"
```

---

## Task 9: Add `/statistics/overview` route to the app router

**Files:**
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: Find the `/statistics` sub-route block**

Open `lib/core/router/app_router.dart` and scroll to line ~639 where `GoRoute(path: '/statistics', ...)` is declared. Locate the `routes: [ ... ]` list containing sub-routes like `'gas'`, `'progression'`, etc.

- [ ] **Step 2: Add import and sub-route**

Add near the other statistics imports:

```dart
import 'package:submersion/features/statistics/presentation/pages/statistics_overview_page.dart';
```

Inside the `routes: [ ... ]` sub-route list, add as the FIRST entry:

```dart
              GoRoute(
                path: 'overview',
                name: 'statisticsOverview',
                builder: (context, state) => const StatisticsOverviewPage(),
              ),
```

- [ ] **Step 3: Run the app again to confirm route works**

Run: `flutter run -d macos`
- Navigate to Statistics → tap Overview → Overview page renders.
- Resize the window below 1100px → in mobile mode, tap Overview tile → full-page Overview renders.

Quit with `q`.

- [ ] **Step 4: Format and analyze**

Run: `dart format lib/core/router/ && flutter analyze lib/core/router/`

- [ ] **Step 5: Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat(statistics): add /statistics/overview route (#167)"
```

---

## Task 10: Replace desktop `summaryBuilder` with `StatisticsOverviewPage`

**Files:**
- Modify: `lib/features/statistics/presentation/pages/statistics_page.dart`

- [ ] **Step 1: Replace the `summaryBuilder`**

In `statistics_page.dart`, change:

```dart
        summaryBuilder: (context) => const StatisticsSummaryWidget(),
```

to:

```dart
        summaryBuilder: (context) => const StatisticsOverviewPage(embedded: true),
```

Remove the now-unused import at the top:

```dart
import 'package:submersion/features/statistics/presentation/widgets/statistics_summary_widget.dart';
```

- [ ] **Step 2: Run the app to confirm desktop default state shows the overview**

Run: `flutter run -d macos`
- Resize window to ≥1100px wide. Navigate to Statistics. The detail pane (right side, with nothing selected) should show the new Overview content (aggregate grid, records, top sites, distributions) instead of the old summary.

Quit with `q`.

- [ ] **Step 3: Format, analyze**

```bash
dart format lib/features/statistics/presentation/pages/statistics_page.dart
flutter analyze lib/features/statistics/
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/statistics/presentation/pages/statistics_page.dart
git commit -m "feat(statistics): use StatisticsOverviewPage as master-detail summary (#167)"
```

---

## Task 11: Delete `StatisticsSummaryWidget` and its test

**Files:**
- Delete: `lib/features/statistics/presentation/widgets/statistics_summary_widget.dart`
- Delete: `test/features/statistics/presentation/widgets/statistics_summary_widget_test.dart` (if it exists)

- [ ] **Step 1: Confirm no references remain**

Run: `grep -r "StatisticsSummaryWidget\|statistics_summary_widget" lib/ test/`
Expected: empty output. If any references remain, remove them before deleting the file.

- [ ] **Step 2: Delete the widget file**

```bash
rm lib/features/statistics/presentation/widgets/statistics_summary_widget.dart
```

- [ ] **Step 3: Delete its test file if one exists**

```bash
ls test/features/statistics/presentation/widgets/statistics_summary_widget_test.dart 2>/dev/null \
  && rm test/features/statistics/presentation/widgets/statistics_summary_widget_test.dart \
  || echo "no test file to delete"
```

- [ ] **Step 4: Run the full test suite**

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 5: Run `flutter analyze` project-wide**

Run: `flutter analyze`
Expected: zero analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor(statistics): remove obsolete StatisticsSummaryWidget (#167)"
```

---

## Task 12: Integration test — end-to-end navigation and rendering

**Files:**
- Create: `integration_test/statistics_overview_flow_test.dart`

- [ ] **Step 1: Write the integration test**

Create `integration_test/statistics_overview_flow_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:submersion/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Statistics -> Overview renders on phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Navigate to Statistics tab (exact selector depends on bottom-nav label).
    await tester.tap(find.text('Stats').last);
    await tester.pumpAndSettle();

    // Tap Overview (first category tile).
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();

    // Confirm the page header renders.
    expect(find.text('Overview'), findsWidgets);
  });

  testWidgets('Statistics shows Overview as default on desktop width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.tap(find.text('Stats').last);
    await tester.pumpAndSettle();

    // Without tapping any category, the detail pane should already show Overview content.
    expect(find.text('Overview'), findsWidgets);
  });
}
```

Note: exact tab label ('Stats' vs 'Statistics') depends on bottom-nav l10n — agent should confirm by grepping `context.l10n.*statistics*` in `lib/shared/widgets/` and adjust.

- [ ] **Step 2: Run the integration test**

Run: `flutter test integration_test/statistics_overview_flow_test.dart -d macos`
Expected: both tests PASS.

- [ ] **Step 3: Commit**

```bash
git add integration_test/statistics_overview_flow_test.dart
git commit -m "test(statistics): add integration flow test for Overview (#167)"
```

---

## Task 13: Final verification and PR prep

- [ ] **Step 1: Run all pre-push hooks manually**

Run: `dart format --set-exit-if-changed lib/ test/ && flutter analyze && flutter test`
Expected: all three pass.

- [ ] **Step 2: Smoke test on macOS one more time**

Run: `flutter run -d macos`
Verify:
- Overview tile appears first with divider below it.
- Aggregate cards render with correct unit-formatted values.
- Personal Records tap navigates to the correct dive detail page.
- Most Visited Sites tap navigates to the correct site detail page.
- Distributions renders two pies.
- Empty state with Log a Dive / Import buttons appears when there are 0 dives (can test by switching to a diver profile with no dives, or by temporarily providing a mock override).
- Desktop resize (≥1100px) shows Overview as default, and the overview tile is highlighted when selected.
- Phone resize (<1100px) pushes a full-page overview.

- [ ] **Step 3: Push and open a PR**

Follow the existing project PR process. Suggested PR title: `feat(statistics): add Overview page for phone + desktop (#167)`
Suggested PR body: summarize the four sections, note that `StatisticsSummaryWidget` was removed in favor of the unified page, and mention that the dives-by-month and tag-usage charts from the old summary remain available in the progression category and dive-list tag filter.

---

## Self-Review Notes (from plan author)

- **Spec coverage:** Every section and edge case in the design spec is covered — aggregate grid (Task 3), personal records (Task 4), most visited sites (Task 5), distributions (Task 6), edge cases including empty state and tenure gate (Task 7), navigation wiring (Tasks 8–10), deletion of the obsolete widget (Task 11), integration testing (Task 12).
- **Spec deviation documented:** The spec mentioned creating a new `diveTypeDistributionProvider`. The plan detects that one already exists and reuses it. The deviation is called out in the "Spec correction note" at the top.
- **Placeholder scan:** Three intentional places flag "agent must confirm against codebase" — the exact pie-chart widget name in Task 6 Step 4, the import-route path in Task 7 Step 3, and the bottom-nav label in Task 12. These are explicit verification directives, not placeholders. All code steps have complete code.
- **Type consistency:** `DiveStatistics`, `DiveRecords`, `TopSiteStat`, `DepthRangeStat`, and `DistributionSegment` are used with their established signatures throughout. The new getters `monthsSinceFirstDive`, `divesPerMonth`, `divesPerYear` are defined once (Task 2) and referenced consistently.
- **TDD:** Every implementation step is preceded by a failing test; every task ends with a commit after the test passes.
