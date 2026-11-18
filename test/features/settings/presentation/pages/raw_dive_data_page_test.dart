import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_computer/data/services/raw_dive_data_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/raw_dive_data_providers.dart';
import 'package:submersion/features/settings/presentation/pages/raw_dive_data_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_raw_dive_data_service.dart';

/// Settings > Data > Data tools > Raw dive computer data (issue #4590): the
/// raw download data kept for re-parsing, in total and per computer, with
/// the discards that used to sit on the dive computer pages (issue #1376).
void main() {
  late FakeRawDiveDataService service;

  setUp(() => service = FakeRawDiveDataService());

  const perdix = (
    computerId: 'c1',
    name: 'Perdix',
    diveCount: 3,
    storedBytes: 3072,
  );
  const unknown = (
    computerId: null,
    name: null,
    diveCount: 1,
    storedBytes: 1024,
  );

  Future<void> pump(
    WidgetTester tester, {
    RawDiveDataUsage total = (diveCount: 4, storedBytes: 4096),
    List<ComputerRawDiveDataUsage> byComputer = const [perdix, unknown],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rawDiveDataServiceProvider.overrideWithValue(service),
          rawDiveDataUsageProvider.overrideWith((ref) async => total),
          rawDiveDataByComputerProvider.overrideWith((ref) async => byComputer),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RawDiveDataPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const discardAll = ValueKey('raw_dive_data_discard_all');
  const discardPerdix = ValueKey('raw_dive_data_discard_c1');
  final dialogDiscard = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('Discard'),
  );

  testWidgets('shows the total and each computer, the unknown one without '
      'a Discard', (tester) async {
    await pump(tester);

    expect(find.text('Raw dive computer data'), findsOneWidget);
    expect(
      find.text(
        '4 dives, 4.0 KB. Kept so these dives can be re-parsed when the '
        'parser improves.',
      ),
      findsOneWidget,
    );
    expect(find.text('By dive computer'), findsOneWidget);
    expect(find.text('Perdix'), findsOneWidget);
    expect(find.text('3 dives, 3.0 KB'), findsOneWidget);
    expect(find.text('Unknown computer'), findsOneWidget);
    expect(find.text('1 dive, 1.0 KB'), findsOneWidget);
    expect(find.byKey(discardAll), findsOneWidget);
    expect(find.byKey(discardPerdix), findsOneWidget);
    // Discard all, and Perdix's: the unknown row has none.
    expect(find.text('Discard all'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
  });

  testWidgets('a computer\'s Discard tells a screen reader which computer', (
    tester,
  ) async {
    // Disposed in the body: the end-of-test check runs before tear-downs,
    // and finally covers a failing expect.
    final semantics = tester.ensureSemantics();
    try {
      await pump(tester);

      expect(
        find.bySemanticsLabel('Discard raw data from Perdix'),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('a computer with no name is labelled unknown but can still be '
      'discarded', (tester) async {
    await pump(
      tester,
      byComputer: const [
        (computerId: 'c9', name: '', diveCount: 2, storedBytes: 2048),
      ],
    );

    expect(find.text('Unknown computer'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('raw_dive_data_discard_c9')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('for 2 dives from Unknown computer?'),
      findsOneWidget,
    );
    await tester.tap(dialogDiscard);
    await tester.pumpAndSettle();
    expect(service.calls, ['c9']);
  });

  testWidgets('Discard all confirms with the every-computer message and '
      'discards everything', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(discardAll));
    await tester.pumpAndSettle();
    expect(find.text('Discard raw data?'), findsOneWidget);
    expect(find.textContaining('from every dive computer (4.0 KB)'), findsOne);

    await tester.tap(dialogDiscard);
    await tester.pumpAndSettle();

    expect(service.calls, [null]);
    expect(find.text('Discarded raw data for 3 dives'), findsOneWidget);
  });

  testWidgets('a computer\'s Discard names it and discards only its data', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(discardPerdix));
    await tester.pumpAndSettle();
    expect(find.textContaining('for 3 dives from Perdix?'), findsOneWidget);

    await tester.tap(dialogDiscard);
    await tester.pumpAndSettle();

    expect(service.calls, ['c1']);
  });

  testWidgets('cancelling discards nothing', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(discardPerdix));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(service.calls, isEmpty);
    expect(find.text('Discard raw data?'), findsNothing);
  });

  testWidgets('a failed discard says so', (tester) async {
    service.failure = StateError('database is locked');
    await pump(tester);

    await tester.tap(find.byKey(discardAll));
    await tester.pumpAndSettle();
    await tester.tap(dialogDiscard);
    await tester.pumpAndSettle();

    expect(find.text('Could not discard raw data'), findsOneWidget);
  });

  testWidgets('with no raw data says so and offers no action', (tester) async {
    await pump(
      tester,
      total: (diveCount: 0, storedBytes: 0),
      byComputer: const [],
    );

    expect(find.text('No dives keep raw dive computer data.'), findsOneWidget);
    expect(find.byKey(discardAll), findsNothing);
    expect(find.textContaining('Discard'), findsNothing);
  });

  testWidgets('a failed count says so instead of showing numbers', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rawDiveDataServiceProvider.overrideWithValue(service),
          rawDiveDataUsageProvider.overrideWith(
            (ref) async => throw StateError('database is locked'),
          ),
          rawDiveDataByComputerProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RawDiveDataPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Please try again.'), findsOne);
    expect(find.byKey(discardAll), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
