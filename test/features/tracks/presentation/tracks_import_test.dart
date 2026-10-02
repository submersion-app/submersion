import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/gps_log/data/services/track_import/csv_track_parser.dart';
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';
import 'package:submersion/features/gps_log/data/services/track_import/track_import_service.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/track_parse_error_text.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_segmenter.dart';
import 'package:submersion/features/nav_track/domain/nav_track_stats.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_import_review_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_import_flow_providers.dart';
import 'package:submersion/features/tracks/presentation/tracks_import.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_file_picker_platform.dart';
import '../../../helpers/mock_providers.dart';

Uint8List _fixture(String name) =>
    File(p.join('test', 'fixtures', 'nav_tracks', name)).readAsBytesSync();

/// Hands back a fixed preview so the flow can be followed past the picker.
class _PreparedNavImport implements NavTrackImportService {
  int prepareCount = 0;

  @override
  Future<NavTrackImportPreview> prepare(
    Uint8List bytes, {
    String? fileName,
  }) async {
    prepareCount++;
    const points = [
      NavTrackPoint(
        timestamp: 1755856800,
        north: 0,
        east: 0,
        depth: 5,
        distance: 0,
        speed: 0.3,
      ),
      NavTrackPoint(
        timestamp: 1755857400,
        north: 40,
        east: 0,
        depth: 5,
        distance: 40,
        speed: 0.3,
      ),
    ];
    return NavTrackImportPreview(
      parsed: const ParsedNavTrack(points: points),
      stats: NavTrackStats.of(points),
      segmentation: NavTrackSegmenter.classify(points),
      candidateDives: const [],
      nearbyDives: const [],
      duplicateOfRouteId: null,
      sourceRef: fileName ?? '',
    );
  }

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
  }) async => throw UnimplementedError();
}

/// Rejects every file, so the GPS branch's error path is reachable.
class _RejectingTrackImport extends TrackImportService {
  @override
  Future<TrackImportCandidate> prepare({
    required String fileName,
    required Uint8List bytes,
    CsvColumnMapping? csvMapping,
  }) async => throw const TrackParseException(
    'no fixes',
    reason: TrackParseReason.noPositions,
  );
}

Future<void> _pumpImporter(
  WidgetTester tester,
  List<Override> overrides,
) async {
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...base, ...overrides],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => importTrackFile(context, ref),
              child: const Text('import'),
            ),
          ),
        ),
      ),
    ),
  );
}

void _pick(String name, Uint8List bytes) {
  final original = FilePickerPlatform.instance;
  addTearDown(() => FilePickerPlatform.instance = original);
  FilePickerPlatform.instance = MockFilePickerPlatform()
    ..pickFilesResult = [
      FakePlatformFile.contentUri(
        Uri.parse('content://picked/$name'),
        name: name,
        bytes: bytes,
      ),
    ];
}

void main() {
  group('isSeacraftEncFile', () {
    final enc = _fixture('seacraft_enc3_short.csv');

    test('an ENC CSV is recognised', () {
      expect(isSeacraftEncFile('005.DAT.csv', enc), isTrue);
    });

    test(
      'the extension is read case-insensitively, and a BOM is tolerated',
      () {
        final withBom = Uint8List.fromList([
          ...utf8.encode('\u{FEFF}'),
          ...enc,
        ]);
        expect(isSeacraftEncFile('005.DAT.CSV', withBom), isTrue);
      },
    );

    test('an ordinary GPS CSV and a GPX file are not ENC', () {
      expect(
        isSeacraftEncFile('track.csv', utf8.encode('time,lat,lon\n1,2,3\n')),
        isFalse,
      );
      expect(isSeacraftEncFile('track.gpx', enc), isFalse);
    });

    test('unreadable bytes are not ENC', () {
      expect(
        isSeacraftEncFile('x.csv', Uint8List.fromList([0xff, 0xfe, 0x00])),
        isFalse,
      );
    });
  });

  testWidgets('an ENC file opens the underwater review with its preview', (
    tester,
  ) async {
    _pick('005.DAT.csv', _fixture('seacraft_enc3_short.csv'));
    final service = _PreparedNavImport();
    await _pumpImporter(tester, [
      navTrackImportServiceProvider.overrideWithValue(service),
    ]);

    await tester.tap(find.text('import'));
    await tester.pumpAndSettle();

    final review = tester.widget<NavTrackImportReviewPage>(
      find.byType(NavTrackImportReviewPage),
    );
    expect(review.fileName, '005.DAT.csv');
    expect(review.preview, isNotNull);
    expect(service.prepareCount, 1);
  });

  testWidgets('a GPS file the parser rejects shows the localized reason', (
    tester,
  ) async {
    _pick('track.gpx', Uint8List.fromList(utf8.encode('<gpx/>')));
    await _pumpImporter(tester, [
      trackImportServiceProvider.overrideWithValue(_RejectingTrackImport()),
    ]);

    await tester.tap(find.text('import'));
    await tester.pumpAndSettle();

    final expected = trackParseErrorText(
      lookupAppLocalizations(const Locale('en')),
      const TrackParseException(
        'no fixes',
        reason: TrackParseReason.noPositions,
      ),
    );
    expect(find.text(expected), findsOneWidget);
  });
}
