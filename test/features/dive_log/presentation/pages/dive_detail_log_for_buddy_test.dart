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

void main() {
  testWidgets('leaving the page mid-mirror does not throw', (tester) async {
    final dive = createTestDiveWithBottomTime();
    final chris = Diver(
      id: 'chris',
      name: 'Chris',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final candidate = (
      buddy: Buddy(
        id: 'b1',
        name: 'Chris',
        linkedDiverId: 'chris',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      diver: chris,
    );
    final service = _SlowMirrorService();
    final navigatorKey = GlobalKey<NavigatorState>();
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
          // Synchronous, so the value is there when the overflow menu
          // builds its items: a pending read would hide the entry.
          mirrorCandidatesProvider(dive.id).overrideWith((ref) => [candidate]),
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
                          DiveDetailPage(diveId: dive.id, embedded: true),
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

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text("Log for a buddy's profile"));
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
