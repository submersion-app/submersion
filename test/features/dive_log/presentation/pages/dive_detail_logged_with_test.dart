import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Future<void> pumpDetail(
    WidgetTester tester, {
    required Dive dive,
    required List<Dive> siblings,
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
          siblingDivesProvider(dive.id).overrideWith((ref) async => siblings),
          mirrorCandidatesProvider(dive.id).overrideWith((ref) async => []),
          diverByIdProvider('chris').overrideWith(
            (ref) async => Diver(
              id: 'chris',
              name: 'Chris',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiveDetailPage(diveId: dive.id, embedded: true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows each sibling with its owner name', (tester) async {
    final dive = createTestDiveWithBottomTime().copyWith(outingId: 'o');
    final sibling = Dive(
      id: 'd2',
      diverId: 'chris',
      dateTime: DateTime(2026, 3, 28, 10),
      outingId: 'o',
      isPlanned: true,
    );
    await pumpDetail(tester, dive: dive, siblings: [sibling]);

    await tester.scrollUntilVisible(
      find.text('Logged with'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // The owner's name arrives from diverByIdProvider once the tile is built.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Logged with'), findsOneWidget);
    expect(find.text('Chris'), findsOneWidget);
    expect(find.text('awaiting their dive computer'), findsOneWidget);
    expect(find.byKey(const Key('logged_with_d2')), findsOneWidget);
  });

  testWidgets('no siblings, no row', (tester) async {
    final dive = createTestDiveWithBottomTime();
    await pumpDetail(tester, dive: dive, siblings: const []);
    expect(find.text('Logged with'), findsNothing);
  });
}
