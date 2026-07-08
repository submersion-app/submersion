import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
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

  testWidgets('site picker is anchored on the dive GPS', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dive = Dive(
      id: 'dive-gps',
      diveNumber: 1,
      dateTime: DateTime(2026, 3, 28, 10, 0),
      entryTime: DateTime(2026, 3, 28, 10, 5),
      bottomTime: const Duration(minutes: 40),
      maxDepth: 20.0,
      entryLocation: const GeoPoint(34.0182, -118.4965),
      tanks: const [],
      profile: const [],
      equipment: const [],
      notes: '',
      photoIds: const [],
      sightings: const [],
      weights: const [],
      tags: const [],
    );
    final created = await repository.createDive(dive);
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(diveId: created.id, embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open the site picker via the "Add site" FormRow.picker placeholder.
    await tester.ensureVisible(find.text('Add site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add site'));
    await tester.pumpAndSettle();

    // Dive has entry GPS -> the picker is anchored on it.
    expect(find.text('Sorted by distance from this dive'), findsOneWidget);
  });
}
