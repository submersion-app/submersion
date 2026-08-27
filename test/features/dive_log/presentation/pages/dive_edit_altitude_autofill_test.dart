import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  Dive buildDive({double? altitude}) => Dive(
    id: 'dive-alt',
    diveNumber: 1,
    dateTime: DateTime(2026, 3, 28, 10, 0),
    entryTime: DateTime(2026, 3, 28, 10, 5),
    bottomTime: const Duration(minutes: 40),
    maxDepth: 20.0,
    altitude: altitude,
    entryLocation: const GeoPoint(46.4, 8.0),
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

    final base = await getBaseOverrides(
      weatherHttpClient: MockClient((request) async {
        expect(request.url.host, 'api.open-meteo.com');
        return http.Response(
          jsonEncode({
            'elevation': [740.2],
          }),
          200,
        );
      }),
    );

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

  testWidgets('fills empty altitude from logged GPS on load', (tester) async {
    final created = await repository.createDive(buildDive());
    await pumpEditPage(tester, created.id);
    await expandConditions(tester);

    // Collapsed FormRow.text renders "<value> <unit symbol>".
    expect(find.text('740 m'), findsOneWidget);
  });

  testWidgets('never overwrites an existing altitude', (tester) async {
    final created = await repository.createDive(buildDive(altitude: 500.0));
    await pumpEditPage(tester, created.id);
    await expandConditions(tester);

    expect(find.text('500 m'), findsOneWidget);
    expect(find.text('740 m'), findsNothing);
  });
}
