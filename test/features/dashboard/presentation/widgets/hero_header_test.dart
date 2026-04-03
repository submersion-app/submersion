import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/widgets/hero_header.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('HeroHeader', () {
    testWidgets('shows diver full name and career stats', (tester) async {
      final dives = [
        createTestDiveWithBottomTime(
          id: 'd1',
          bottomTime: const Duration(minutes: 60),
          maxDepth: 30.0,
        ),
        createTestDiveWithBottomTime(
          id: 'd2',
          bottomTime: const Duration(minutes: 45),
          maxDepth: 25.0,
        ),
      ];
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            divesProvider.overrideWith((ref) async => dives),
            diveStatisticsProvider.overrideWith(
              (ref) async => DiveStatistics(
                totalDives: 2,
                totalTimeSeconds: 6300,
                maxDepth: 30.0,
                avgMaxDepth: 27.5,
                totalSites: 1,
              ),
            ),
            currentDiverProvider.overrideWith(
              (ref) async => Diver(
                id: '1',
                name: 'Eric Griffin',
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 1),
              ),
            ),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SingleChildScrollView(child: HeroHeader())),
          ),
        ),
      );
      // Pump several frames to let async providers resolve.
      // Cannot use pumpAndSettle because the repeating animation never settles.
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Greeting includes first name
      expect(find.textContaining('Eric'), findsOneWidget);
      // Stats subtitle includes dive count
      expect(find.textContaining('2 dives logged'), findsOneWidget);
    });

    testWidgets('shows fallback name when no diver set', (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            divesProvider.overrideWith((ref) async => <Dive>[]),
            diveStatisticsProvider.overrideWith(
              (ref) async => DiveStatistics(
                totalDives: 0,
                totalTimeSeconds: 0,
                maxDepth: 0,
                avgMaxDepth: 0,
                totalSites: 0,
              ),
            ),
            currentDiverProvider.overrideWith((ref) async => null),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SingleChildScrollView(child: HeroHeader())),
          ),
        ),
      );
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.textContaining('Diver'), findsOneWidget);
    });

    testWidgets('displays time-of-day greeting', (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            divesProvider.overrideWith((ref) async => <Dive>[]),
            diveStatisticsProvider.overrideWith(
              (ref) async => DiveStatistics(
                totalDives: 0,
                totalTimeSeconds: 0,
                maxDepth: 0,
                avgMaxDepth: 0,
                totalSites: 0,
              ),
            ),
            currentDiverProvider.overrideWith((ref) async => null),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SingleChildScrollView(child: HeroHeader())),
          ),
        ),
      );
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // One of the time-of-day greetings should be present
      final hasGreeting =
          find.textContaining('Good morning').evaluate().isNotEmpty ||
          find.textContaining('Good afternoon').evaluate().isNotEmpty ||
          find.textContaining('Good evening').evaluate().isNotEmpty;
      expect(hasGreeting, isTrue);
    });
  });
}
