import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
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
