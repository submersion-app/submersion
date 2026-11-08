import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_computer/data/services/reparse_batch_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_batch_provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/reparse_dives_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Hands back [ids] for the whole log and records each run.
class _FakeBatch implements ReparseBatchService {
  _FakeBatch(this.ids);

  final List<String> ids;
  final askedForDiver = <String?>[];
  final runs = <List<String>>[];

  @override
  Future<List<String>> diveIdsWithRawData({required String? diverId}) async {
    askedForDiver.add(diverId);
    return ids;
  }

  @override
  Future<ReparseBatchResult> run(
    List<String> diveIds, {
    required RawDiveParseFn parseFn,
    String? computerId,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    runs.add(diveIds);
    return ReparseBatchResult(
      total: diveIds.length,
      succeeded: diveIds.length,
      skipped: 0,
      notProcessed: 0,
      profilesPreserved: 0,
      failures: const [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeBatch batch;

  Future<void> pumpPage(
    WidgetTester tester,
    ReparseDivesOverview overview,
  ) async {
    batch = _FakeBatch(['d1', 'd2', 'd3']);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          reparseDivesOverviewProvider.overrideWith((ref) async => overview),
          reparseBatchServiceProvider.overrideWithValue(batch),
          reparseParseFnProvider.overrideWithValue(
            (vendor, product, model, raw) => throw UnimplementedError(),
          ),
          reparseDiveLookupProvider.overrideWithValue((ids) async => []),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        ],
        child: const ReparseDivesPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  const overview = ReparseDivesOverview(
    total: 3,
    byComputer: [
      ComputerRawDataCount(computerId: 'a', computerName: 'Perdix', dives: 2),
      ComputerRawDataCount(computerId: null, computerName: '', dives: 1),
    ],
    withoutRawData: 4,
  );

  testWidgets('shows the per-computer counts and the dives without data', (
    tester,
  ) async {
    await pumpPage(tester, overview);

    expect(find.text('Dives with raw data: 3'), findsOneWidget);
    expect(find.text('By dive computer'), findsOneWidget);
    expect(find.text('Perdix'), findsOneWidget);
    expect(find.text('Unknown computer'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(
      find.text('Dives without raw data (not re-parsed): 4'),
      findsOneWidget,
    );
  });

  testWidgets('the button is disabled with a message when there is no data', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const ReparseDivesOverview(total: 0, byComputer: [], withoutRawData: 5),
    );

    expect(
      find.text('No dives have stored raw data to re-parse.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Re-parse all'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('confirming re-parses every dive with raw data for the diver', (
    tester,
  ) async {
    await pumpPage(tester, overview);

    await tester.tap(find.text('Re-parse all'));
    await tester.pumpAndSettle();
    expect(find.textContaining('on 3 dives'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Re-parse'));
    await tester.pumpAndSettle();

    expect(batch.askedForDiver, ['me']);
    expect(batch.runs, [
      ['d1', 'd2', 'd3'],
    ]);
    expect(find.text('Re-parsed 3 of 3 dives.'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation re-parses nothing', (tester) async {
    await pumpPage(tester, overview);

    await tester.tap(find.text('Re-parse all'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(batch.runs, isEmpty);
  });
}
