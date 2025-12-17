import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/pages/records_page.dart';

void main() {
  group('RecordsPage', () {
    late SharedPreferences prefs;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('should display Dive Records title in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveRecordsProvider.overrideWith((ref) async => DiveRecords()),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: RecordsPage(),
          ),
        ),
      );

      expect(find.text('Dive Records'), findsOneWidget);
    });

    testWidgets('should display empty state when no records exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveRecordsProvider.overrideWith((ref) async => DiveRecords()),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: RecordsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Records Yet'), findsOneWidget);
      expect(find.text('Start logging dives to see your records here'), findsOneWidget);
    });

    testWidgets('should display refresh button in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveRecordsProvider.overrideWith((ref) async => DiveRecords()),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: RecordsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('should display record cards when records exist', (tester) async {
      final records = DiveRecords(
        deepestDive: DiveRecord(
          diveId: '1',
          diveNumber: 1,
          dateTime: DateTime(2024, 6, 15),
          maxDepth: 35.0,
          duration: const Duration(minutes: 45),
        ),
        longestDive: DiveRecord(
          diveId: '2',
          diveNumber: 2,
          dateTime: DateTime(2024, 7, 20),
          maxDepth: 20.0,
          duration: const Duration(minutes: 90),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveRecordsProvider.overrideWith((ref) async => records),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: RecordsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show record sections
      expect(find.text('Deepest Dive'), findsOneWidget);
      expect(find.text('Longest Dive'), findsOneWidget);
    });

    testWidgets('should display error state with retry button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveRecordsProvider.overrideWith((ref) async {
              throw Exception('Failed to load records');
            }),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: RecordsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Error loading records'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
