import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/data/services/dive_mirror_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #2002: "Log for a buddy's profile" runs a database transaction and
/// then refreshes the lists. The diver can leave the page while it runs, so
/// the refresh must not go through this page's `ref`.
class _SlowMirrorService extends DiveMirrorService {
  final Completer<void> gate = Completer<void>();

  @override
  Future<MirrorOutcome> mirror({
    required String sourceDiveId,
    required List<String> targetDiverIds,
  }) async {
    await gate.future;
    return MirrorOutcome(
      sourceDiveId: sourceDiveId,
      outingId: 'outing-1',
      mintedOutingId: true,
      createdDiveIds: const ['mirrored-1'],
    );
  }
}

const _menuLabel = "Log for a buddy's profile";

MirrorCandidate _chrisCandidate() {
  final chris = Diver(
    id: 'chris',
    name: 'Chris',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  return (
    buddy: Buddy(
      id: 'b1',
      name: 'Chris',
      linkedDiverId: 'chris',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    diver: chris,
  );
}

/// Opens the detail page for [dive] from a launcher route. The candidates
/// override is asynchronous, like the real provider, so the page must have
/// loaded them before the overflow menu builds its items (issue #2367).
Future<void> _openDetail(
  WidgetTester tester, {
  required Dive dive,
  required List<MirrorCandidate> candidates,
  required bool embedded,
  DiveMirrorService? service,
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  final overrides = await getBaseOverrides();

  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        diveProvider(dive.id).overrideWith((ref) async => dive),
        diveDataSourcesProvider(
          dive.id,
        ).overrideWith((ref) async => <DiveDataSource>[]),
        buddiesForDiveProvider(
          dive.id,
        ).overrideWith((ref) async => <BuddyWithRole>[]),
        siblingDivesProvider(dive.id).overrideWith((ref) async => <Dive>[]),
        mirrorCandidatesProvider(
          dive.id,
        ).overrideWith((ref) async => candidates),
        if (service != null)
          diveMirrorServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        DiveDetailPage(diveId: dive.id, embedded: embedded),
                  ),
                ),
                child: const Text('open dive'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open dive'));
  await tester.pumpAndSettle();
}

Future<void> _openOverflowMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert).first);
  await tester.pumpAndSettle();
}

void main() {
  for (final embedded in [true, false]) {
    final menu = embedded ? 'header' : 'app bar';

    testWidgets('the $menu menu offers the mirror once candidates load', (
      tester,
    ) async {
      await _openDetail(
        tester,
        dive: createTestDiveWithBottomTime(),
        candidates: [_chrisCandidate()],
        embedded: embedded,
      );

      await _openOverflowMenu(tester);

      expect(find.text(_menuLabel), findsOneWidget);
    });

    testWidgets('the $menu menu hides the mirror without candidates', (
      tester,
    ) async {
      await _openDetail(
        tester,
        dive: createTestDiveWithBottomTime(),
        candidates: const [],
        embedded: embedded,
      );

      await _openOverflowMenu(tester);

      expect(find.text(_menuLabel), findsNothing);
    });
  }

  testWidgets('leaving the page mid-mirror does not throw', (tester) async {
    final service = _SlowMirrorService();
    final navigatorKey = GlobalKey<NavigatorState>();
    await _openDetail(
      tester,
      dive: createTestDiveWithBottomTime(),
      candidates: [_chrisCandidate()],
      embedded: true,
      service: service,
      navigatorKey: navigatorKey,
    );

    await _openOverflowMenu(tester);
    await tester.tap(find.text(_menuLabel));
    await tester.pumpAndSettle();
    expect(find.text('Also log this dive in another profile?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Log'));
    await tester.pumpAndSettle();

    // The diver goes back while the mirror transaction is still running.
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    service.gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(tester.takeException(), isNull);
  });
}
