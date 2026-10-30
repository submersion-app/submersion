import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The dive edit page hands the dive's own GPS to the dive center picker,
/// so a dive with no site still lists the centers near it first (#3379).
void main() {
  late DiveRepository repository;

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repository = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  DiveCenter center(String name, {double? lat, double? lon}) {
    final now = DateTime(2026);
    return DiveCenter(
      id: '',
      name: name,
      latitude: lat,
      longitude: lon,
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('a dive with entry GPS lists the centers near it first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final centers = DiveCenterRepository();
    await centers.createDiveCenter(
      center('Aardvark Divers', lat: 20.42, lon: -86.92),
    );
    await centers.createDiveCenter(
      center('Zed Reef Divers', lat: 12.15, lon: -68.28),
    );
    final dive = await repository.createDive(
      Dive(
        id: 'dive-1',
        diveNumber: 1,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        notes: '',
        entryLocation: const GeoPoint(12.0864, -68.2779),
      ),
    );

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
          home: Scaffold(body: DiveEditPage(diveId: dive.id, embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The Trip group starts collapsed on a dive with no trip or center.
    final group = find.text('Trip');
    await tester.ensureVisible(group.first);
    await tester.pumpAndSettle();
    await tester.tap(group.first);
    await tester.pumpAndSettle();

    final row = find.text('Dive center');
    await tester.ensureVisible(row.first);
    await tester.pumpAndSettle();
    await tester.tap(row.first);
    await tester.pumpAndSettle();

    expect(find.text('Near this dive'), findsOneWidget);
    expect(find.text('All dive centers'), findsOneWidget);
    // The Bonaire center is near the dive, so it comes before Aardvark
    // although it sorts after it alphabetically.
    expect(
      tester.getTopLeft(find.text('Zed Reef Divers')).dy,
      lessThan(tester.getTopLeft(find.text('Aardvark Divers')).dy),
    );
  });
}
