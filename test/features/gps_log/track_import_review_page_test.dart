import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';
import 'package:submersion/features/gps_log/data/services/track_import/track_import_service.dart';
import 'package:submersion/features/gps_log/presentation/pages/track_import_review_page.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/csv_column_mapping_form.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

Uint8List _bytes(String name) =>
    File('test/fixtures/gps_tracks/$name').readAsBytesSync();

ParsedTrack _parsed() => ParsedTrack(
  name: 'Cozumel Day 3',
  fixes: [
    (utc: DateTime.utc(2026, 5, 22, 13), lat: 20.5, lon: -87.25, accuracy: 5.0),
    (
      utc: DateTime.utc(2026, 5, 22, 13, 1),
      lat: 20.51,
      lon: -87.26,
      accuracy: null,
    ),
  ],
);

TrackImportCandidate _candidate({
  TrackFileFormat format = TrackFileFormat.gpx,
  String? duplicateOf,
  int tzOffsetMinutes = 0,
}) => TrackImportCandidate(
  parsed: _parsed(),
  format: format,
  sourceRef: 'sample.gpx',
  tzOffsetMinutes: tzOffsetMinutes,
  duplicateOfTrackId: duplicateOf,
);

/// Records the committed candidate without touching a database.
class _SpyImportService implements TrackImportService {
  TrackImportCandidate? committed;

  @override
  Future<String> commit(TrackImportCandidate candidate) async {
    committed = candidate;
    return 'new-track';
  }

  @override
  Future<TrackImportCandidate> prepare({
    required String fileName,
    required Uint8List bytes,
    dynamic csvMapping,
  }) async => throw UnimplementedError();
}

Future<_SpyImportService> _pump(
  WidgetTester tester, {
  required TrackImportCandidate candidate,
  Uint8List? bytes,
}) async {
  final base = await getBaseOverrides();
  final spy = _SpyImportService();
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [...base, trackImportServiceProvider.overrideWithValue(spy)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TrackImportReviewPage(
          candidate: candidate,
          bytes: bytes ?? Uint8List.fromList(utf8.encode('<gpx/>')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return spy;
}

void main() {
  testWidgets('shows the track name and fix count', (tester) async {
    await _pump(tester, candidate: _candidate());
    expect(find.text('Cozumel Day 3'), findsOneWidget);
    expect(find.text('2 fixes'), findsOneWidget);
  });

  testWidgets('shows no duplicate warning for a fresh import', (tester) async {
    await _pump(tester, candidate: _candidate());
    expect(
      find.byKey(const ValueKey('import-duplicate-warning')),
      findsNothing,
    );
  });

  testWidgets('warns when the candidate is flagged as a duplicate', (
    tester,
  ) async {
    await _pump(tester, candidate: _candidate(duplicateOf: 'existing'));
    expect(
      find.text('This looks like a duplicate of an existing track.'),
      findsOneWidget,
    );
  });

  // The offset dropdown lists every quarter-hour zone from -12:00 to +14:00,
  // so driving its menu in a test means scrolling a 105-item overlay. These
  // two cover the same code paths - the preview formatter and the commit
  // threading - by varying the initial offset instead. What they do not
  // cover is DropdownButtonFormField's own onChanged plumbing.
  testWidgets('renders the first fix in the resolved zone', (tester) async {
    await _pump(tester, candidate: _candidate());
    // DateFormat.add_jm() separates the meridiem with a NARROW NO-BREAK
    // SPACE (U+202F), so match the clock time rather than "1:00 PM".
    expect(find.textContaining('1:00'), findsOneWidget);
  });

  testWidgets('a different zone shifts the previewed first fix', (
    tester,
  ) async {
    // Same 13:00 UTC instant, now under UTC-5: it must read 8:00 local.
    // Showing this before the write is the entire point of the screen.
    await _pump(tester, candidate: _candidate(tzOffsetMinutes: -300));
    expect(find.textContaining('8:00'), findsOneWidget);
    expect(find.textContaining('1:00'), findsNothing);
  });

  testWidgets('commits with the resolved offset', (tester) async {
    final spy = await _pump(
      tester,
      candidate: _candidate(tzOffsetMinutes: -300),
    );

    await tester.tap(find.byKey(const ValueKey('import-confirm')));
    await tester.pumpAndSettle();

    expect(spy.committed, isNotNull);
    expect(spy.committed!.tzOffsetMinutes, -300);
  });

  testWidgets('shows the column mapping form for a CSV candidate', (
    tester,
  ) async {
    await _pump(
      tester,
      candidate: _candidate(format: TrackFileFormat.csv),
      bytes: _bytes('sample.csv'),
    );
    expect(find.byType(CsvColumnMappingForm), findsOneWidget);
    expect(find.text('Match the columns'), findsOneWidget);
  });

  testWidgets('does not show the mapping form for a GPX candidate', (
    tester,
  ) async {
    await _pump(tester, candidate: _candidate());
    expect(find.byType(CsvColumnMappingForm), findsNothing);
  });
}
