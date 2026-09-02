import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/statistics_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The statistics-exclusion toggles live in their own collapsible group at the
/// bottom of the dive form rather than inside The Dive. What this covers is
/// the part a widget test of the section alone cannot: where the group sits,
/// when it opens itself, and that it does not shut under the diver's finger.
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Dive buildDive({
    bool excludedFromStats = false,
    bool excludedFromGasStats = false,
  }) => Dive(
    id: 'dive-stats',
    diveNumber: 1,
    // Dives round-trip through the repository as UTC-flagged wall clocks
    // (`fromMillisecondsSinceEpoch(..., isUtc: true)`), so a local DateTime
    // would come back shifted by the machine's offset.
    dateTime: DateTime.utc(2026, 3, 28, 10, 0),
    entryTime: DateTime.utc(2026, 3, 28, 10, 5),
    bottomTime: const Duration(minutes: 40),
    maxDepth: 20.0,
    excludedFromStats: excludedFromStats,
    excludedFromGasStats: excludedFromGasStats,
    tanks: const [],
    profile: const [],
    equipment: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );

  Future<void> pumpEditPage(WidgetTester tester, String diveId) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveEditPage(diveId: diveId, embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder masterToggle() =>
      find.byKey(const Key('dive-edit-exclude-from-stats'));

  testWidgets('the toggles are no longer part of The Dive', (tester) async {
    final created = await repository.createDive(buildDive());
    await pumpEditPage(tester, created.id);

    expect(find.byType(StatisticsSection), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TheDiveSection),
        matching: masterToggle(),
      ),
      findsNothing,
      reason:
          'The Dive is always expanded, so a flag about how the dive is '
          'counted would sit permanently among the core facts',
    );
  });

  testWidgets('an ordinary dive keeps the group shut until asked', (
    tester,
  ) async {
    final created = await repository.createDive(buildDive());
    await pumpEditPage(tester, created.id);

    expect(masterToggle(), findsNothing);
    expect(find.text('Counted in every statistic'), findsOneWidget);

    final header = find.text('Statistics');
    await tester.ensureVisible(header.first);
    await tester.pumpAndSettle();
    await tester.tap(header.first);
    await tester.pumpAndSettle();

    expect(masterToggle(), findsOneWidget);
  });

  testWidgets('an already-excluded dive opens the group on load', (
    tester,
  ) async {
    // Otherwise the one setting the diver came back to change is the one
    // hidden behind a closed section.
    final created = await repository.createDive(
      buildDive(excludedFromStats: true),
    );
    await pumpEditPage(tester, created.id);

    expect(masterToggle(), findsOneWidget);
  });

  testWidgets('the gas flag reaches page state on its own', (tester) async {
    // The narrower flag has its own handler on the page, and it is the one a
    // diver reaches for when only the gas reading is unrepresentative.
    final created = await repository.createDive(buildDive());
    await pumpEditPage(tester, created.id);

    final header = find.text('Statistics');
    await tester.ensureVisible(header.first);
    await tester.pumpAndSettle();
    await tester.tap(header.first);
    await tester.pumpAndSettle();

    final gas = find.byKey(const Key('dive-edit-exclude-from-gas-stats'));
    final gasSwitch = find.descendant(of: gas, matching: find.byType(Switch));
    await tester.ensureVisible(gasSwitch);
    await tester.pumpAndSettle();
    await tester.tap(gasSwitch);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(gasSwitch).value, isTrue);
    expect(
      tester
          .widget<Switch>(
            find.descendant(of: masterToggle(), matching: find.byType(Switch)),
          )
          .value,
      isFalse,
      reason: 'the gas flag must not imply the master one',
    );
  });

  testWidgets('clearing the last flag does not shut the group', (tester) async {
    // The default expansion follows the flags, so without pinning, switching
    // the exclusion off would collapse the group under the diver's finger.
    final created = await repository.createDive(
      buildDive(excludedFromStats: true),
    );
    await pumpEditPage(tester, created.id);

    final toggle = find.descendant(
      of: masterToggle(),
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(masterToggle(), findsOneWidget);
    expect(
      tester
          .widget<Switch>(
            find.descendant(of: masterToggle(), matching: find.byType(Switch)),
          )
          .value,
      isFalse,
    );
  });
}
