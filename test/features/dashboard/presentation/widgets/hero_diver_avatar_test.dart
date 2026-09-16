import 'dart:async';

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/widgets/hero_header.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _StubDiverListNotifier extends StateNotifier<AsyncValue<List<Diver>>>
    implements DiverListNotifier {
  _StubDiverListNotifier(List<Diver> divers) : super(AsyncValue.data(divers));

  @override
  Future<void> refresh() async {}
  @override
  Future<Diver> addDiver(Diver diver) async => diver;
  @override
  Future<void> updateDiver(Diver diver) async {}
  @override
  Future<DeleteDiverResult> deleteDiver(String id) async {
    return const DeleteDiverResult(
      reassignedTripsCount: 0,
      reassignedSitesCount: 0,
    );
  }

  @override
  Future<void> setAsDefault(String id) async {}
}

final _eric = Diver(
  id: '1',
  name: 'Eric Griffin',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final _sam = Diver(
  id: '2',
  name: 'Sam Lee',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    required Future<Diver?> Function() diver,
    List<Diver>? divers,
    Future<Diver?> Function(String? id)? diverForId,
  }) async {
    // Two profiles by default: that is the case the avatar exists for.
    final allDivers = divers ?? [_eric, _sam];
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
          currentDiverProvider.overrideWith(
            (ref) => diverForId == null
                ? diver()
                : diverForId(ref.watch(currentDiverIdProvider)),
          ),
          diverCountProvider.overrideWith((ref) async => allDivers.length),
          diverListNotifierProvider.overrideWith(
            (ref) => _StubDiverListNotifier(allDivers),
          ),
        ].cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: HeroHeader())),
        ),
      ),
    );
    // The ocean background animates forever, so pumpAndSettle never returns.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Every English greeting starts with "Good", with or without a name.
  Finder greeting() => find.textContaining(RegExp('^Good '));

  group('HeroHeader diver avatar', () {
    testWidgets('shows the active diver initials as a Switch Diver button', (
      tester,
    ) async {
      await pumpHeader(tester, diver: () async => _eric);

      expect(find.text('EG'), findsOneWidget);
      expect(find.byTooltip('Switch Diver'), findsOneWidget);
    });

    testWidgets('tapping the avatar opens the diver switcher sheet', (
      tester,
    ) async {
      await pumpHeader(tester, diver: () async => _eric);

      await tester.tap(find.byTooltip('Switch Diver'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Switch Diver'), findsOneWidget);
      expect(find.text('Eric Griffin'), findsOneWidget);
    });

    testWidgets('shows nothing while only one profile exists', (tester) async {
      await pumpHeader(tester, diver: () async => _eric, divers: [_eric]);

      expect(find.text('EG'), findsNothing);
      expect(find.byTooltip('Switch Diver'), findsNothing);
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
    });

    testWidgets('single-profile greeting keeps the pre-avatar 18px inset', (
      tester,
    ) async {
      await pumpHeader(tester, diver: () async => _eric, divers: [_eric]);

      final headerLeft = tester.getTopLeft(find.byType(HeroHeader)).dx;
      expect(tester.getTopLeft(greeting()).dx - headerLeft, 18);
    });

    testWidgets('shows the avatar with its swap badge for two profiles', (
      tester,
    ) async {
      await pumpHeader(tester, diver: () async => _eric);

      expect(find.text('EG'), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
      // 18px inset, 44px tap target, 8px gap.
      final headerLeft = tester.getTopLeft(find.byType(HeroHeader)).dx;
      expect(tester.getTopLeft(greeting()).dx - headerLeft, 70);
    });

    testWidgets('keeps the current avatar while the next diver loads', (
      tester,
    ) async {
      final samLoads = Completer<Diver?>();
      await pumpHeader(
        tester,
        diver: () async => _eric,
        divers: [_eric, _sam],
        diverForId: (id) => id == '2' ? samLoads.future : Future.value(_eric),
      );
      expect(find.text('EG'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HeroHeader)),
      );
      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver('2');
      await tester.pump();
      await tester.pump();

      // Reload in flight: the old avatar stays, the slot never goes blank.
      expect(find.text('EG'), findsOneWidget);
      expect(find.byTooltip('Switch Diver'), findsOneWidget);

      samLoads.complete(_sam);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('SL'), findsOneWidget);
      expect(find.text('EG'), findsNothing);
    });

    testWidgets('greeting does not shift when the diver finishes loading', (
      tester,
    ) async {
      final completer = Completer<Diver?>();
      await pumpHeader(tester, diver: () => completer.future);
      final loadingLeft = tester.getTopLeft(greeting()).dx;

      completer.complete(_eric);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.textContaining('Eric'), findsOneWidget);
      expect(tester.getTopLeft(greeting()).dx, loadingLeft);
    });
  });
}
