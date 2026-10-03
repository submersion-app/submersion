import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/route_link_sheet.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_segmenter.dart';
import 'package:submersion/features/nav_track/domain/nav_track_stats.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_import_flow_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_file_picker_platform.dart';
import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/nav_track_fixtures.dart';

/// Hands back routes by id, as the sheet reads a freshly imported one.
class _FakeRouteRepository extends NavTrackRepository {
  _FakeRouteRepository([this.byId = const {}]);

  final Map<String, NavTrack> byId;

  @override
  Future<NavTrack?> getById(String id, {bool includePoints = true}) async =>
      byId[id];
}

/// A fixed preview, and a commit that "saves" as `new-route`.
class _FakeImportService implements NavTrackImportService {
  _FakeImportService({this.duplicateOfRouteId, this.prepareError});

  final String? duplicateOfRouteId;

  /// Thrown by `prepare` instead of returning a preview, when set.
  final Object? prepareError;

  /// The site the last `commit` stored on the route.
  String? lastSiteId;

  @override
  Future<NavTrackImportPreview> prepare(
    Uint8List bytes, {
    String? fileName,
  }) async => prepareError != null
      ? throw prepareError!
      : NavTrackImportPreview(
          parsed: const ParsedNavTrack(points: kTestNavTrackPoints),
          stats: NavTrackStats.of(kTestNavTrackPoints),
          segmentation: NavTrackSegmenter.classify(kTestNavTrackPoints),
          candidateDives: const [],
          nearbyDives: const [],
          duplicateOfRouteId: duplicateOfRouteId,
          sourceRef: fileName ?? '',
        );

  @override
  Future<String> commit({
    required ParsedNavTrack parsed,
    required String sourceRef,
    required String? diverId,
    Dive? dive,
    String? siteId,
    String? name,
    String? deviceName,
    String? equipmentId,
    String? replacingRouteId,
  }) async {
    lastSiteId = siteId;
    return 'new-route';
  }
}

Future<List<DiveRouteLinkDraft>> _openSheet(
  WidgetTester tester, {
  required DiveRouteLinkDraft draft,
  List<NavTrack> unlinked = const [],
  DateTime? entryTime,
  NavTrackRepository? repository,
  NavTrackImportService? service,
}) async {
  tester.platformDispatcher.localesTestValue = const [
    Locale('de'),
    Locale('en'),
  ];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final changes = <DiveRouteLinkDraft>[];
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        unlinkedNavTracksProvider.overrideWith((ref) async => unlinked),
        navTrackRepositoryProvider.overrideWithValue(
          repository ?? _FakeRouteRepository(),
        ),
        if (service != null)
          navTrackImportServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showRouteLinkSheet(
                context,
                draft: draft,
                entryTime:
                    entryTime ??
                    DateTime.fromMillisecondsSinceEpoch(
                      kTestRouteStartMs,
                      isUtc: true,
                    ),
                onChanged: changes.add,
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
  return changes;
}

void _mockPickedFile() {
  final original = FilePickerPlatform.instance;
  addTearDown(() => FilePickerPlatform.instance = original);
  FilePickerPlatform.instance = MockFilePickerPlatform()
    ..pickFilesResult = [
      FakePlatformFile.contentUri(
        Uri.parse('content://picked/005.DAT.csv'),
        name: '005.DAT.csv',
        bytes: Uint8List.fromList([1]),
      ),
    ];
}

Future<void> _saveReviewPage(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).last, const Offset(0, -400));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('nav-track-import-save')));
  await tester.pumpAndSettle();
}

void main() {
  const hour = 3600000;

  testWidgets('lists the draft routes with their distance', (tester) async {
    await _openSheet(
      tester,
      draft: DiveRouteLinkDraft.initial([
        testNavTrack('a', name: 'Wreck tour', totalDistance: 1050),
      ]),
    );
    expect(find.byKey(const ValueKey('route-sheet-row-a')), findsOneWidget);
    expect(find.text('Wreck tour'), findsOneWidget);
    expect(find.textContaining('1050'), findsOneWidget);
  });

  testWidgets('shows "No track linked" for an empty draft', (tester) async {
    await _openSheet(tester, draft: DiveRouteLinkDraft.initial(const []));
    expect(find.text('No track linked'), findsOneWidget);
  });

  testWidgets('removing a route reports a draft without it', (tester) async {
    final changes = await _openSheet(
      tester,
      draft: DiveRouteLinkDraft.initial([testNavTrack('a')]),
    );

    await tester.tap(find.byKey(const ValueKey('route-sheet-remove-a')));
    await tester.pumpAndSettle();

    expect(changes.last.current, isEmpty);
    expect(changes.last.toUnlink, ['a']);
    expect(find.byKey(const ValueKey('route-sheet-row-a')), findsNothing);
  });

  testWidgets('hides "Link track" when there is nothing to link', (
    tester,
  ) async {
    await _openSheet(tester, draft: DiveRouteLinkDraft.initial(const []));
    expect(find.byKey(const ValueKey('route-sheet-link-button')), findsNothing);
    expect(
      find.byKey(const ValueKey('route-sheet-import-button')),
      findsOneWidget,
    );
  });

  testWidgets('offers unlinked routes nearest the form\'s entry time first, '
      'and linking one reports it', (tester) async {
    final morning = testNavTrack('early', name: 'Early');
    final afternoon = testNavTrack(
      'late',
      name: 'Late',
      startTime: kTestRouteStartMs + 5 * hour,
    );
    final changes = await _openSheet(
      tester,
      draft: DiveRouteLinkDraft.initial(const []),
      unlinked: [morning, afternoon],
      // The diver moved the entry time to the afternoon on the form.
      entryTime: DateTime.fromMillisecondsSinceEpoch(
        kTestRouteStartMs + 5 * hour,
        isUtc: true,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('route-sheet-link-button')));
    await tester.pumpAndSettle();

    final lateTop = tester.getTopLeft(
      find.byKey(const ValueKey('route-sheet-candidate-late')),
    );
    final earlyTop = tester.getTopLeft(
      find.byKey(const ValueKey('route-sheet-candidate-early')),
    );
    expect(lateTop.dy, lessThan(earlyTop.dy));

    await tester.tap(find.byKey(const ValueKey('route-sheet-candidate-late')));
    await tester.pumpAndSettle();

    expect(changes.last.toLink, ['late']);
  });

  testWidgets('offers a removed original route again, but never one already '
      'in the draft', (tester) async {
    final a = testNavTrack('a', diveId: 'd1');
    final b = testNavTrack('b', diveId: 'd1');
    await _openSheet(tester, draft: DiveRouteLinkDraft.initial([a, b]));

    await tester.tap(find.byKey(const ValueKey('route-sheet-remove-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('route-sheet-link-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('route-sheet-candidate-a')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('route-sheet-candidate-b')), findsNothing);
  });

  testWidgets('importing a file adds the saved route to the draft', (
    tester,
  ) async {
    _mockPickedFile();
    final saved = testNavTrack('new-route', name: 'Imported');
    final changes = await _openSheet(
      tester,
      draft: DiveRouteLinkDraft.initial(const []),
      repository: _FakeRouteRepository({'new-route': saved}),
      service: _FakeImportService(),
    );

    await tester.tap(find.byKey(const ValueKey('route-sheet-import-button')));
    await tester.pumpAndSettle();
    // The review page opened in return mode: no dive picker.
    expect(find.text('Link to dive'), findsNothing);
    await _saveReviewPage(tester);

    expect(changes.last.toLink, ['new-route']);
    expect(
      find.byKey(const ValueKey('route-sheet-row-new-route')),
      findsOneWidget,
    );
  });

  testWidgets('importing a re-export that replaces this dive\'s route swaps '
      'it in the draft without unlinking the deleted one', (tester) async {
    _mockPickedFile();
    final old = testNavTrack('old', diveId: 'd1');
    final saved = testNavTrack('new-route');
    final changes = await _openSheet(
      tester,
      draft: DiveRouteLinkDraft.initial([old]),
      repository: _FakeRouteRepository({'new-route': saved}),
      service: _FakeImportService(duplicateOfRouteId: 'old'),
    );

    await tester.tap(find.byKey(const ValueKey('route-sheet-import-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await _saveReviewPage(tester);

    expect(changes.last.current.map((r) => r.id), ['new-route']);
    expect(changes.last.toUnlink, isEmpty);
    expect(changes.last.toLink, ['new-route']);
    expect(changes.last.replacements, {'old': 'new-route'});
  });

  testWidgets('an imported route is saved without a site, so it takes the '
      'dive\'s final site when it is linked on Save', (tester) async {
    _mockPickedFile();
    final service = _FakeImportService();
    await _openSheet(
      tester,
      draft: DiveRouteLinkDraft.initial(const []),
      repository: _FakeRouteRepository({
        'new-route': testNavTrack('new-route'),
      }),
      service: service,
    );

    await tester.tap(find.byKey(const ValueKey('route-sheet-import-button')));
    await tester.pumpAndSettle();
    await _saveReviewPage(tester);

    expect(service.lastSiteId, isNull);
  });

  testWidgets('a file that is not a usable route says why inside the sheet', (
    tester,
  ) async {
    _mockPickedFile();
    await _openSheet(
      tester,
      draft: DiveRouteLinkDraft.initial(const []),
      service: _FakeImportService(
        prepareError: const NavTrackParseException(
          'only one sample',
          reason: NavTrackParseReason.tooShort,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('route-sheet-import-button')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(
          'This recording has too few samples to be a usable underwater track.',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a file that cannot be imported says so inside the sheet', (
    tester,
  ) async {
    _mockPickedFile();
    await _openSheet(
      tester,
      draft: DiveRouteLinkDraft.initial(const []),
      service: _FakeImportService(prepareError: StateError('boom')),
    );

    await tester.tap(find.byKey(const ValueKey('route-sheet-import-button')));
    await tester.pumpAndSettle();

    // A snackbar would render behind the modal sheet, out of sight.
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.textContaining('Import failed'),
      ),
      findsOneWidget,
    );
  });
}
