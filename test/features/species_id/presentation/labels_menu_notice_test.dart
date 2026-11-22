import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/domain/entities/label_mode.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/presentation/providers/label_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/labels_menu.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';
import '../../media/presentation/support/media_widget_harness.dart';
import '../data/identification_fixtures.dart';
import 'species_id_fakes.dart';

/// What the store holds for the item: [before] as the Analyse starts,
/// [run] and [rows] once it has finished.
class _StoredRepository extends MediaIdentificationRepository {
  _StoredRepository({required this.run, required this.rows});

  MediaIdentificationRun? before;
  MediaIdentificationRun? run;
  List<MediaIdentification> rows;
  var _reads = 0;

  @override
  Future<MediaIdentificationRun?> runFor(String mediaId) async =>
      _reads++ == 0 ? before : run;

  @override
  Future<List<MediaIdentification>> forMedia(String mediaId) async => rows;

  /// The run and rows in one snapshot, as the readers take them since the
  /// rows shown follow their run (issue #4876).
  @override
  Future<(MediaIdentificationRun?, List<MediaIdentification>)> forMediaWithRun(
    String mediaId,
  ) async => (run, rows);
}

MediaIdentificationRun _run(String mediaId, {int? scannedMs, int? lengthMs}) =>
    MediaIdentificationRun(
      mediaId: mediaId,
      packVersion: '2026.11.1',
      detectorId: 'det-a',
      classifierId: 'clf-a',
      analysedAt: DateTime.utc(2026, 11, 22),
      imageWidth: 100,
      imageHeight: 100,
      detectionCount: 0,
      scannedMs: scannedMs,
      videoDurationMs: lengthMs,
    );

/// A find the app could not name: Names draws nothing for it.
MediaIdentification _unnamed(String id, {String mediaId = 'm1'}) =>
    identification(
      id,
      mediaId: mediaId,
    ).copyWith(suggestable: false, confident: false, specific: false);

/// The notice the labels menu gives once an Analyse the diver asked for
/// has finished and what it found would draw no name (issue #4872).
void main() {
  late RecordingIdentificationService service;
  late _StoredRepository stored;
  late bool showing;

  setUp(() {
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
    service = RecordingIdentificationService();
    stored = _StoredRepository(run: _run('m1'), rows: [_unnamed('a')]);
    showing = true;
  });

  Future<void> analyse(
    WidgetTester tester, {
    MediaItem? item,
    LabelMode mode = LabelMode.names,
    MediaAnalysisState state = MediaAnalysisState.partial,
  }) async {
    final shown = item ?? testMediaItem(id: 'm1');
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          mediaIdentificationServiceProvider.overrideWithValue(service),
          mediaIdentificationRepositoryProvider.overrideWithValue(stored),
          levelInForceProvider.overrideWithValue(null),
          labelModeNotifierProvider.overrideWith(
            (ref) => LabelModeNotifier.unstored(mode),
          ),
          mediaAnalysisStatusProvider(
            AnalysisTarget(shown, null),
          ).overrideWith((ref) async => (state: state, found: 1)),
          mediaIdentificationBusyProvider(
            shown.id,
          ).overrideWith((ref) => Stream.value(false)),
          mediaIdentificationProgressProvider(
            shown.id,
          ).overrideWith((ref) => Stream.value(null)),
        ],
        child: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              ref.watch(
                mediaAnalysisStatusProvider(AnalysisTarget(shown, null)),
              );
              return Center(
                child: Builder(
                  builder: (anchor) => TextButton(
                    onPressed: () => showMarineLifeLabelsMenu(
                      anchor,
                      ref,
                      item: shown,
                      location: null,
                      showing: () => showing,
                    ),
                    child: const Text('labels'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('labels'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('labels_menu_analyse')));
    await tester.pumpAndSettle();
  }

  Finder notice() => find.byKey(const ValueKey('labels_analysed_notice'));

  testWidgets('finds with no name say how many, and offer All life', (
    tester,
  ) async {
    stored.rows = [_unnamed('a'), _unnamed('b')];
    await analyse(tester);
    expect(service.byHand, [true]);
    expect(find.text('2 found, none named'), findsOneWidget);
    await tester.tap(find.text('Show all life'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('labels')),
    );
    expect(container.read(labelModeNotifierProvider), LabelMode.allLife);
  });

  testWidgets('nothing found says so, with nothing to switch to', (
    tester,
  ) async {
    stored.rows = [];
    await analyse(tester);
    expect(find.text('Nothing found'), findsOneWidget);
    expect(find.text('Show all life'), findsNothing);
  });

  testWidgets('a find with a name says nothing: its pill shows', (
    tester,
  ) async {
    stored.rows = [
      _unnamed('a'),
      identification('b').copyWith(suggestable: true, confident: false),
    ];
    await analyse(tester);
    expect(notice(), findsNothing);
  });

  testWidgets('in All life the notice offers no switch', (tester) async {
    await analyse(tester, mode: LabelMode.allLife);
    expect(find.text('1 found, none named'), findsOneWidget);
    expect(find.text('Show all life'), findsNothing);
  });

  testWidgets('Analyse again says what it found too', (tester) async {
    await analyse(tester, state: MediaAnalysisState.analysed);
    expect(service.fresh, [true]);
    expect(find.text('1 found, none named'), findsOneWidget);
  });

  testWidgets('a video left part way says nothing', (tester) async {
    stored
      ..run = _run('v1', scannedMs: 2000, lengthMs: 30000)
      ..rows = [_unnamed('a', mediaId: 'v1')];
    await analyse(
      tester,
      item: testMediaItem(id: 'v1', mediaType: MediaType.video),
    );
    expect(notice(), findsNothing);
  });

  testWidgets('an item never analysed (dropped, or unreadable) says '
      'nothing', (tester) async {
    stored.run = null;
    await analyse(tester);
    expect(notice(), findsNothing);
  });

  testWidgets('an Analyse that stored nothing new (it failed, or was '
      'skipped) says nothing of the earlier analysis', (tester) async {
    stored.before = stored.run;
    await analyse(tester, state: MediaAnalysisState.analysed);
    expect(notice(), findsNothing);
  });

  testWidgets('an item analysed before says what this Analyse found', (
    tester,
  ) async {
    stored
      ..before = _run('m1')
      ..run = _run('m1').copyWith(packVersion: '2026.12.1');
    await analyse(tester, state: MediaAnalysisState.analysed);
    expect(find.text('1 found, none named'), findsOneWidget);
  });

  testWidgets('an item no longer on screen says nothing', (tester) async {
    showing = false;
    await analyse(tester);
    expect(notice(), findsNothing);
  });
}
