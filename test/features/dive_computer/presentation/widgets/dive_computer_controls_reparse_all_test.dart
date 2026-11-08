import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_controls.dart';
import 'package:submersion/features/dive_computer/presentation/providers/raw_dive_data_providers.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_batch_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_batch_provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_raw_dive_data_service.dart';
import '../../../../helpers/mock_providers.dart';

class _MockDiveComputerNotifier
    extends StateNotifier<AsyncValue<List<DiveComputer>>>
    implements DiveComputerNotifier {
  _MockDiveComputerNotifier() : super(const AsyncValue.data(<DiveComputer>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Records the re-parse the button asks for, returning [failing] dives as
/// failed and the rest as re-parsed.
class _RecordingBatch implements ReparseBatchService {
  _RecordingBatch({this.failing = const {}, this.listingFails = false});

  final Set<String> failing;
  final bool listingFails;
  final reparsed = <(List<String>, String?)>[];

  @override
  Future<List<String>> diveIdsForComputer(String computerId) async => [
    if (listingFails) throw StateError('database is closed'),
    '$computerId-d1',
    '$computerId-d2',
    '$computerId-d3',
  ];

  @override
  Future<ReparseBatchResult> run(
    List<String> diveIds, {
    required RawDiveParseFn parseFn,
    String? computerId,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    reparsed.add((diveIds, computerId));
    final failures = [
      for (final id in diveIds)
        if (failing.contains(id))
          ReparseDiveFailure(diveId: id, error: 'Exception: bad bytes'),
    ];
    return ReparseBatchResult(
      total: diveIds.length,
      succeeded: diveIds.length - failures.length,
      skipped: 0,
      notProcessed: 0,
      profilesPreserved: 0,
      failures: failures,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// "Re-parse all dives" on a computer's Equipment page (issue #3676 moved
/// it there from the old computer page).
void main() {
  final computer = DiveComputer(
    id: 'comp-1',
    name: 'My Perdix',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pump(
    WidgetTester tester, {
    required ({int withRawData, int withoutRawData}) counts,
    required _RecordingBatch batch,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(
      initialLocation: '/dive-computers/comp-1',
      routes: [
        GoRoute(
          path: '/dive-computers/:id',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: DiveComputerControls(
                computerId: state.pathParameters['id']!,
              ),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          diveComputerNotifierProvider.overrideWith(
            (ref) => _MockDiveComputerNotifier(),
          ),
          diveComputerByIdProvider(
            'comp-1',
          ).overrideWith((ref) async => computer),
          rawDataCountProvider('comp-1').overrideWith((ref) async => counts),
          rawDiveDataServiceProvider.overrideWithValue(
            FakeRawDiveDataService(),
          ),
          reparseBatchServiceProvider.overrideWithValue(batch),
          reparseParseFnProvider.overrideWithValue(
            (vendor, product, model, raw) => throw UnimplementedError(),
          ),
          reparseDiveLookupProvider.overrideWithValue((ids) async => []),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('counts the dives without raw data beside the button', (
    tester,
  ) async {
    await pump(
      tester,
      counts: (withRawData: 3, withoutRawData: 2),
      batch: _RecordingBatch(),
    );

    expect(find.text('Re-parse all dives'), findsOneWidget);
    expect(find.text('3 dives with raw data (2 without)'), findsOneWidget);
  });

  testWidgets('confirming re-parses only this computer and shows the results', (
    tester,
  ) async {
    final batch = _RecordingBatch();
    await pump(
      tester,
      counts: (withRawData: 3, withoutRawData: 0),
      batch: batch,
    );

    await tester.tap(find.text('Re-parse all dives'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Re-parse'));
    await tester.pumpAndSettle();

    expect(batch.reparsed.single.$1, ['comp-1-d1', 'comp-1-d2', 'comp-1-d3']);
    expect(batch.reparsed.single.$2, 'comp-1');
    expect(find.text('Re-parse finished'), findsOneWidget);
    expect(find.text('Re-parsed 3 of 3 dives.'), findsOneWidget);
  });

  testWidgets('a partial re-parse lists the failed dives', (tester) async {
    final batch = _RecordingBatch(failing: {'comp-1-d2'});
    await pump(
      tester,
      counts: (withRawData: 3, withoutRawData: 0),
      batch: batch,
    );

    await tester.tap(find.text('Re-parse all dives'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Re-parse'));
    await tester.pumpAndSettle();

    expect(find.text('Re-parsed 2 of 3 dives.'), findsOneWidget);
    expect(find.text('Failed: 1'), findsOneWidget);
    expect(find.textContaining('bad bytes'), findsOneWidget);
  });

  testWidgets('cancelling re-parses nothing', (tester) async {
    final batch = _RecordingBatch();
    await pump(
      tester,
      counts: (withRawData: 3, withoutRawData: 0),
      batch: batch,
    );

    await tester.tap(find.text('Re-parse all dives'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(batch.reparsed, isEmpty);
  });

  testWidgets('a failed listing after confirming reports an error', (
    tester,
  ) async {
    final batch = _RecordingBatch(listingFails: true);
    await pump(
      tester,
      counts: (withRawData: 3, withoutRawData: 0),
      batch: batch,
    );

    await tester.tap(find.text('Re-parse all dives'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Re-parse'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Re-parsing dives'), findsNothing);
    expect(batch.reparsed, isEmpty);
  });
}
