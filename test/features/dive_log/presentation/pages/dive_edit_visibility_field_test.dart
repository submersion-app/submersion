import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart' as enums;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Dive buildDive({double? visibilityMeters, enums.Visibility? visibility}) =>
      Dive(
        id: 'dive-vis',
        diveNumber: 1,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        entryTime: DateTime(2026, 3, 28, 10, 5),
        bottomTime: const Duration(minutes: 40),
        maxDepth: 20.0,
        visibilityMeters: visibilityMeters,
        visibility: visibility,
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

  Future<void> expandConditions(WidgetTester tester) async {
    final header = find.text('Conditions');
    await tester.ensureVisible(header.first);
    await tester.pumpAndSettle();
    await tester.tap(header.first);
    await tester.pumpAndSettle();
  }

  testWidgets('a measured dive shows the distance and its adjective', (
    tester,
  ) async {
    final created = await repository.createDive(
      buildDive(visibilityMeters: 6.0),
    );
    await pumpEditPage(tester, created.id);
    await expandConditions(tester);

    // Collapsed FormRow.text renders "<value> <unit symbol>".
    expect(find.text('6 m'), findsOneWidget);
    // Default calibration is tropical, under which 6 m is Moderate. That is
    // exactly the complaint this feature exists to let divers fix.
    expect(find.text('Moderate'), findsOneWidget);
  });

  testWidgets('a 20 m dive reads Good under the default calibration', (
    tester,
  ) async {
    final created = await repository.createDive(
      buildDive(visibilityMeters: 20.0),
    );
    await pumpEditPage(tester, created.id);
    await expandConditions(tester);

    expect(find.text('20 m'), findsOneWidget);
    expect(find.text('Good'), findsOneWidget);
  });

  testWidgets('a legacy dive shows its band, not an adjective', (tester) async {
    final created = await repository.createDive(
      buildDive(visibility: enums.Visibility.moderate),
    );
    await pumpEditPage(tester, created.id);
    await expandConditions(tester);

    // The bucket only says the dive fell somewhere in 5-15 m, so the caption
    // states the range rather than asserting a calibrated adjective.
    expect(find.text('5-15 m'), findsOneWidget);
  });

  testWidgets('a dive with no visibility shows no caption', (tester) async {
    final created = await repository.createDive(buildDive());
    await pumpEditPage(tester, created.id);
    await expandConditions(tester);

    expect(find.text('Moderate'), findsNothing);
    expect(find.text('Good'), findsNothing);
    expect(find.text('Excellent'), findsNothing);
  });
}
