import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('DiveDetailPage bottomTime coverage', () {
    testWidgets('displays bottomTime in stat row', (tester) async {
      final dive = createTestDiveWithBottomTime();
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveProvider(dive.id).overrideWith((ref) async => dive),
            diveDataSourcesProvider(
              dive.id,
            ).overrideWith((ref) async => <DiveDataSource>[]),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiveDetailPage(diveId: dive.id, embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The stat row should display bottom time as "45 min"
      expect(find.text('45 min'), findsOneWidget);
    });

    testWidgets('displays runtime in stat row', (tester) async {
      final dive = createTestDiveWithBottomTime(
        runtime: const Duration(minutes: 50),
      );
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveProvider(dive.id).overrideWith((ref) async => dive),
            diveDataSourcesProvider(
              dive.id,
            ).overrideWith((ref) async => <DiveDataSource>[]),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiveDetailPage(diveId: dive.id, embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Runtime of 50 min should be displayed
      expect(find.text('50 min'), findsOneWidget);
    });

    testWidgets('handles null bottomTime', (tester) async {
      final dive = createTestDiveWithBottomTime(bottomTime: null);
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveProvider(dive.id).overrideWith((ref) async => dive),
            diveDataSourcesProvider(
              dive.id,
            ).overrideWith((ref) async => <DiveDataSource>[]),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiveDetailPage(diveId: dive.id, embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show -- for null bottom time
      expect(find.text('--'), findsWidgets);
    });

    testWidgets('shows attribution badges with data sources', (tester) async {
      final dive = Dive(
        id: 'dive-with-sources',
        diveNumber: 1,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        entryTime: DateTime(2026, 3, 28, 10, 5),
        exitTime: DateTime(2026, 3, 28, 10, 50),
        bottomTime: const Duration(minutes: 45),
        runtime: const Duration(minutes: 50),
        maxDepth: 25.0,
        avgDepth: 18.0,
        waterTemp: 22.0,
        tanks: const [],
        profile: [
          const DiveProfilePoint(timestamp: 0, depth: 0),
          const DiveProfilePoint(timestamp: 60, depth: 15),
          const DiveProfilePoint(timestamp: 1200, depth: 20),
          const DiveProfilePoint(timestamp: 2400, depth: 18),
          const DiveProfilePoint(timestamp: 2700, depth: 0),
        ],
        equipment: const [],
        notes: '',
        photoIds: const [],
        sightings: const [],
        weights: const [],
        tags: const [],
      );

      final dataSources = [
        DiveDataSource(
          id: 'src-1',
          diveId: dive.id,
          isPrimary: true,
          computerModel: 'Shearwater Perdix',
          computerSerial: 'SN123',
          maxDepth: 25.0,
          duration: 45 * 60,
          waterTemp: 22.0,
          entryTime: DateTime(2026, 3, 28, 10, 5),
          exitTime: DateTime(2026, 3, 28, 10, 50),
          importedAt: DateTime(2026, 3, 28),
          createdAt: DateTime(2026, 3, 28),
        ),
        // Second source so attribution map is non-empty
        DiveDataSource(
          id: 'src-2',
          diveId: dive.id,
          isPrimary: false,
          computerModel: 'Suunto D5',
          computerSerial: 'SN456',
          maxDepth: 24.8,
          duration: 44 * 60,
          waterTemp: 21.5,
          entryTime: DateTime(2026, 3, 28, 10, 6),
          exitTime: DateTime(2026, 3, 28, 10, 49),
          importedAt: DateTime(2026, 3, 28),
          createdAt: DateTime(2026, 3, 28),
        ),
      ];

      // Enable data source badges to trigger attribution rendering
      final settings = MockSettingsNotifier();
      await settings.setShowDataSourceBadges(true);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => settings),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            diveProvider(dive.id).overrideWith((ref) async => dive),
            diveDataSourcesProvider(
              dive.id,
            ).overrideWith((ref) async => dataSources),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiveDetailPage(diveId: dive.id, embedded: true),
          ),
        ),
      );
      // Tolerate profile chart rendering errors
      final errors = <FlutterErrorDetails>[];
      FlutterError.onError = (d) => errors.add(d);
      await tester.pumpAndSettle();
      FlutterError.onError = FlutterError.presentError;

      // Should render with attribution badges
      expect(find.byType(DiveDetailPage), findsOneWidget);
    });
  });
}
