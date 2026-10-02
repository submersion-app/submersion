import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_computer/data/services/raw_dive_data_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/raw_dive_data_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/raw_dive_data_discard.dart';

import '../../../../helpers/fake_raw_dive_data_service.dart';
import '../../../../helpers/test_app.dart';

void main() {
  late FakeRawDiveDataService service;

  setUp(() => service = FakeRawDiveDataService());

  Widget build(RawDiveDataUsage usage) => testApp(
    locale: const Locale('en'),
    overrides: [
      rawDiveDataServiceProvider.overrideWithValue(service),
      rawDiveDataUsageProvider.overrideWith((ref) async => usage),
    ],
    child: const RawDiveDataTile(),
  );

  const tile = ValueKey('raw_dive_data_tile');
  const discardAll = ValueKey('raw_dive_data_discard_all');

  testWidgets('is hidden when no source keeps raw data', (tester) async {
    await tester.pumpWidget(build((diveCount: 0, storedBytes: 0)));
    await tester.pumpAndSettle();

    expect(find.byKey(tile), findsNothing);
  });

  testWidgets('shows how many dives keep raw data and its size', (
    tester,
  ) async {
    await tester.pumpWidget(build((diveCount: 3, storedBytes: 4096)));
    await tester.pumpAndSettle();

    expect(find.byKey(tile), findsOneWidget);
    expect(find.text('Raw dive computer data'), findsOneWidget);
    expect(
      find.text(
        '3 dives, 4.0 KB. Kept so these dives can be re-parsed when the '
        'parser improves.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('cancelling the confirmation discards nothing', (tester) async {
    await tester.pumpWidget(build((diveCount: 3, storedBytes: 4096)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(discardAll));
    await tester.pumpAndSettle();
    expect(find.text('Discard raw data?'), findsOneWidget);
    expect(find.textContaining('from every dive computer (4.0 KB)'), findsOne);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(service.calls, isEmpty);
    expect(find.text('Discard raw data?'), findsNothing);
  });

  testWidgets('confirming discards every computer\'s raw data and reports '
      'how many dives it cleared', (tester) async {
    await tester.pumpWidget(build((diveCount: 3, storedBytes: 4096)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(discardAll));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Discard'),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.calls, [null]);
    expect(find.text('Discarded raw data for 3 dives'), findsOneWidget);
  });

  testWidgets('a failed discard says so instead of claiming success', (
    tester,
  ) async {
    service.failure = StateError('database is locked');
    await tester.pumpWidget(build((diveCount: 3, storedBytes: 4096)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(discardAll));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Discard'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not discard raw data'), findsOneWidget);
    expect(find.textContaining('Discarded raw data'), findsNothing);
  });
}
