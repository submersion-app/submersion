import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/settings/presentation/pages/safety_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Widget _buildTestWidget(MockSettingsNotifier notifier) {
  return ProviderScope(
    overrides: [settingsProvider.overrideWith((ref) => notifier)],
    child: const MaterialApp(
      // Pin English so text-based finders stay deterministic regardless of the
      // host platform locale.
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SafetySettingsPage(),
    ),
  );
}

void main() {
  testWidgets('renders master toggle on and five rule switches', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notifier = MockSettingsNotifier();
    await tester.pumpWidget(_buildTestWidget(notifier));
    await tester.pumpAndSettle();

    expect(find.text('Post-dive safety review'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(6));

    final master = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile).first,
    );
    expect(master.value, isTrue);
  });

  testWidgets('selecting the strict no-fly preset persists it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notifier = MockSettingsNotifier();
    await tester.pumpWidget(_buildTestWidget(notifier));
    await tester.pumpAndSettle();

    expect(notifier.state.noFlyPreset, NoFlyPreset.standard);
    await tester.tap(find.text('Strict (18/24/48 h)'));
    await tester.pumpAndSettle();
    expect(notifier.state.noFlyPreset, NoFlyPreset.strict);
  });

  testWidgets('toggling master off disables rule switches', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notifier = MockSettingsNotifier();
    await tester.pumpWidget(_buildTestWidget(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    final ruleSwitches = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .skip(1);
    for (final s in ruleSwitches) {
      expect(s.onChanged, isNull);
    }
  });

  Widget backfillApp(List<Override> extra) => ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      // The sweep now scopes to the active diver; override the provider so it
      // does not build the real notifier (which hits SharedPreferences/DB).
      currentDiverIdProvider.overrideWith(
        (ref) => MockCurrentDiverIdNotifier(),
      ),
      ...extra,
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SafetySettingsPage(),
    ),
  );

  testWidgets('tapping an enabled rule switch toggles it off', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notifier = MockSettingsNotifier();
    await tester.pumpWidget(_buildTestWidget(notifier));
    await tester.pumpAndSettle();

    // Index 0 is the master toggle; index 1 is the first per-rule switch, on by
    // default (its rule is not in the disabled set).
    final firstRule = find.byType(SwitchListTile).at(1);
    expect(tester.widget<SwitchListTile>(firstRule).value, isTrue);

    await tester.tap(firstRule);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(firstRule).value, isFalse);
  });

  testWidgets('backfill shows progress while analyzing, then completes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final gate = Completer<void>();
    await tester.pumpWidget(
      backfillApp([
        diveRepositoryProvider.overrideWithValue(_FakeDiveRepository(['d1'])),
        safetyReviewProvider('d1').overrideWith((ref) async {
          await gate.future;
          return null;
        }),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Analyze all dives'));
    await tester.pump(); // enter the analyzing state
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('Analyzed 0 of 1'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Analysis complete'), findsOneWidget);
  });

  testWidgets('dismiss all does nothing when the confirmation is cancelled', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = _RecordingBulkRepo();
    await tester.pumpWidget(
      backfillApp([
        diveRepositoryProvider.overrideWithValue(_FakeDiveRepository(['d1'])),
        safetyFindingsRepositoryProvider.overrideWithValue(repo),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dismiss all observations'));
    await tester.pumpAndSettle();
    expect(find.text('Dismiss all observations?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
  });

  testWidgets('confirming dismiss all writes through and reports the count', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = _RecordingBulkRepo(changedPerCall: 3);
    await tester.pumpWidget(
      backfillApp([
        diveRepositoryProvider.overrideWithValue(
          _FakeDiveRepository(['d1', 'd2']),
        ),
        safetyFindingsRepositoryProvider.overrideWithValue(repo),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dismiss all observations'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Dismiss all'));
    await tester.pumpAndSettle();

    expect(repo.calls.single, ['d1', 'd2']);
    expect(repo.dismissed.single, isTrue);
    expect(find.text('3 observations dismissed'), findsOneWidget);
  });

  testWidgets('dismiss all scopes the write to the enabled rules', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = _RecordingBulkRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(
              const AppSettings(safetyReviewDisabledRules: {'sawtoothProfile'}),
            ),
          ),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          diveRepositoryProvider.overrideWithValue(_FakeDiveRepository(['d1'])),
          safetyFindingsRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SafetySettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dismiss all observations'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Dismiss all'));
    await tester.pumpAndSettle();

    expect(
      repo.ruleIds.single,
      isNot(contains(SafetyRuleId.sawtoothProfile.dbValue)),
      reason: 'a rule hidden in settings must not be dismissed unseen',
    );
    expect(repo.ruleIds.single, contains(SafetyRuleId.rapidAscent.dbValue));
  });

  testWidgets('dismiss all reports when there was nothing to dismiss', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      backfillApp([
        diveRepositoryProvider.overrideWithValue(_FakeDiveRepository(['d1'])),
        safetyFindingsRepositoryProvider.overrideWithValue(
          _RecordingBulkRepo(changedPerCall: 0),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dismiss all observations'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Dismiss all'));
    await tester.pumpAndSettle();

    expect(find.text('No observations to dismiss'), findsOneWidget);
  });

  testWidgets('dismiss all shows progress and locks the analyze sweep', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final gate = Completer<void>();
    await tester.pumpWidget(
      backfillApp([
        diveRepositoryProvider.overrideWithValue(_FakeDiveRepository(['d1'])),
        safetyFindingsRepositoryProvider.overrideWithValue(
          _RecordingBulkRepo(gate: gate),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dismiss all observations'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Dismiss all'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('Checked 0 of 1 dives'), findsOneWidget);
    final analyzeTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Analyze all dives'),
    );
    expect(
      analyzeTile.onTap,
      isNull,
      reason: 'the two long-running actions must not overlap',
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('a failed chunk is reported alongside the partial count', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // 60 dives spans two write chunks; the second throws, so the run has both
    // a real partial result and a real failure to report.
    final diveIds = [for (var i = 0; i < 60; i++) 'd$i'];
    final repo = _RecordingBulkRepo(changedPerCall: 3, throwOnCall: 2);
    await tester.pumpWidget(
      backfillApp([
        diveRepositoryProvider.overrideWithValue(_FakeDiveRepository(diveIds)),
        safetyFindingsRepositoryProvider.overrideWithValue(repo),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dismiss all observations'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Dismiss all'));
    await tester.pumpAndSettle();

    expect(
      find.text('3 observations dismissed, 10 dives could not be updated'),
      findsOneWidget,
      reason: 'a partial write must be reported, not silently dropped',
    );
    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Dismiss all observations'),
    );
    expect(tile.onTap, isNotNull, reason: 'the page must not stay locked');
  });

  testWidgets('a failure to list dives says nothing was changed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = _RecordingBulkRepo();
    await tester.pumpWidget(
      backfillApp([
        diveRepositoryProvider.overrideWithValue(_ThrowingDiveRepository()),
        safetyFindingsRepositoryProvider.overrideWithValue(repo),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dismiss all observations'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Dismiss all'));
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
    expect(
      find.text('Could not read your dive list. No dives were changed.'),
      findsOneWidget,
    );
    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Dismiss all observations'),
    );
    expect(tile.onTap, isNotNull);
  });

  testWidgets('a failed analyze sweep does not leave the page locked', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      backfillApp([
        diveRepositoryProvider.overrideWithValue(_ThrowingDiveRepository()),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Analyze all dives'));
    await tester.pumpAndSettle();

    expect(find.text('Could not analyze your dives.'), findsOneWidget);
    // Without a finally the sweep leaves _analyzing true forever, which now
    // also disables the master toggle, every rule, and bulk dismiss.
    for (final title in ['Analyze all dives', 'Dismiss all observations']) {
      expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, title)).onTap,
        isNotNull,
        reason: '$title must recover after a failed sweep',
      );
    }
  });
}

/// A [DiveRepository] whose id query always fails.
class _ThrowingDiveRepository implements DiveRepository {
  @override
  Future<List<String>> getOrderedDiveIds({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    SortState<DiveSortField>? sort,
  }) async => throw StateError('dive list unavailable');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records bulk dismiss calls without touching a database.
class _RecordingBulkRepo extends SafetyFindingsRepository {
  _RecordingBulkRepo({this.gate, this.changedPerCall = 1, this.throwOnCall});

  final Completer<void>? gate;
  final int changedPerCall;

  /// 1-based index of the call that should throw, or null for none.
  final int? throwOnCall;
  final List<List<String>> calls = [];
  final List<bool> dismissed = [];
  final List<Set<String>> ruleIds = [];

  @override
  Future<int> setDismissedForDives({
    required List<String> diveIds,
    required bool dismissed,
    required Set<String> enabledRuleIds,
    required DateTime now,
    int chunkSize = SafetyFindingsRepository.dismissChunkSize,
  }) async {
    calls.add(diveIds);
    this.dismissed.add(dismissed);
    ruleIds.add(enabledRuleIds);
    if (gate != null) await gate!.future;
    if (calls.length == throwOnCall) {
      throw StateError('bulk dismiss failed');
    }
    return changedPerCall;
  }
}

/// Minimal [DiveRepository] fake returning a fixed ordered id list.
class _FakeDiveRepository implements DiveRepository {
  _FakeDiveRepository(this.ids);

  final List<String> ids;

  @override
  Future<List<String>> getOrderedDiveIds({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    SortState<DiveSortField>? sort,
  }) async => ids;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
