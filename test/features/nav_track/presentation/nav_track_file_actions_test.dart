import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_file_actions.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_import_flow_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeRepository extends NavTrackRepository {
  _FakeRepository(this.file);

  final Uint8List? file;

  @override
  Future<Uint8List?> getSourceFile(String routeId) async => file;
}

class _FakeImportService implements NavTrackImportService {
  _FakeImportService({this.error, this.updated = true, this.recordedAt = 0});

  /// Thrown by `parseFile` when it is a [NavTrackParseException], else by
  /// `updateFromFile`.
  final Object? error;
  final bool updated;

  /// When the picked file's recording starts, in epoch seconds. The test
  /// route records from 0 to 1 s, so 0 is its own recording read again.
  final int recordedAt;
  final updates = <({String routeId, Uint8List bytes, String? fileName})>[];

  @override
  ParsedNavTrack parseFile(Uint8List bytes) {
    if (error is NavTrackParseException) throw error!;
    return ParsedNavTrack(
      points: [
        NavTrackPoint(timestamp: recordedAt, north: 0, east: 0, depth: 2),
        NavTrackPoint(timestamp: recordedAt + 1, north: 1, east: 0, depth: 2),
      ],
    );
  }

  @override
  Future<bool> updateFromFile({
    required String routeId,
    required ParsedNavTrack parsed,
    required Uint8List sourceFile,
    String? sourceRef,
  }) async {
    if (error != null) throw error!;
    updates.add((routeId: routeId, bytes: sourceFile, fileName: sourceRef));
    return updated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _file = Uint8List.fromList(utf8.encode('Date,Time\n1.11.2026,11:46:14'));

NavTrack _route({String? sourceRef = '023.DAT.csv'}) => NavTrack(
  id: 'r1',
  source: NavTrackSource.seacraftEnc,
  sourceRef: sourceRef,
  startTime: 0,
  endTime: 1000,
  pointCount: 2,
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
);

/// A page with one button that runs [action] the way the detail page's menu
/// does.
Future<void> _pump(
  WidgetTester tester, {
  required Future<void> Function(BuildContext, WidgetRef) action,
  NavTrackRepository? repository,
  NavTrackImportService? service,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (repository != null)
          navTrackRepositoryProvider.overrideWithValue(repository),
        if (service != null)
          navTrackImportServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => action(context, ref),
              child: const Text('RUN'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('RUN'));
  await tester.pumpAndSettle();
}

void main() {
  group('exportCsv (issue #4231)', () {
    testWidgets('hands the stored file out under the name it was imported '
        'with', (tester) async {
      final saved = <(Uint8List, String)>[];
      await _pump(
        tester,
        repository: _FakeRepository(_file),
        action: (context, ref) => NavTrackFileActions(
          saveFile: (bytes, name, _) async => saved.add((bytes, name)),
        ).exportCsv(context, ref, _route()),
      );

      expect(saved, hasLength(1));
      expect(saved.single.$1, _file);
      expect(saved.single.$2, '023.DAT.csv');
    });

    testWidgets('anchors the share sheet where the caller asks', (
      tester,
    ) async {
      const origin = Rect.fromLTWH(10, 20, 30, 40);
      final origins = <Rect?>[];
      await _pump(
        tester,
        repository: _FakeRepository(_file),
        action: (context, ref) => NavTrackFileActions(
          saveFile: (bytes, name, shareOrigin) async =>
              origins.add(shareOrigin),
        ).exportCsv(context, ref, _route(), shareOrigin: origin),
      );

      expect(origins, [origin]);
    });

    testWidgets('says the track has no stored file instead of exporting '
        'nothing', (tester) async {
      final saved = <(Uint8List, String)>[];
      await _pump(
        tester,
        repository: _FakeRepository(null),
        action: (context, ref) => NavTrackFileActions(
          saveFile: (bytes, name, _) async => saved.add((bytes, name)),
        ).exportCsv(context, ref, _route()),
      );

      expect(saved, isEmpty);
      expect(find.textContaining('no stored original file'), findsOneWidget);
    });

    testWidgets('reports a failed export', (tester) async {
      await _pump(
        tester,
        repository: _FakeRepository(_file),
        action: (context, ref) => NavTrackFileActions(
          saveFile: (bytes, name, _) async => throw StateError('disk full'),
        ).exportCsv(context, ref, _route()),
      );

      expect(find.textContaining('disk full'), findsOneWidget);
    });
  });

  group('updateFromFile (issue #4231)', () {
    testWidgets('updates the track from a file of the same name without '
        'asking', (tester) async {
      final service = _FakeImportService();
      await _pump(
        tester,
        service: service,
        action: (context, ref) => NavTrackFileActions(
          pickFile: () async => (bytes: _file, name: '023.DAT.csv'),
        ).updateFromFile(context, ref, _route()),
      );

      expect(find.byType(AlertDialog), findsNothing);
      expect(service.updates.single.routeId, 'r1');
      expect(service.updates.single.bytes, _file);
      expect(service.updates.single.fileName, '023.DAT.csv');
      expect(
        find.textContaining('Track updated from the file'),
        findsOneWidget,
      );
    });

    testWidgets('asks before updating from a file of another name, and '
        'leaves the track alone when the diver cancels', (tester) async {
      final service = _FakeImportService();
      await _pump(
        tester,
        service: service,
        action: (context, ref) => NavTrackFileActions(
          pickFile: () async => (bytes: _file, name: '024.DAT.csv'),
        ).updateFromFile(context, ref, _route()),
      );

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('"023.DAT.csv"'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('nav-track-update-mismatch-cancel')),
      );
      await tester.pumpAndSettle();

      expect(service.updates, isEmpty);
    });

    testWidgets('asks before updating from a recording made at another '
        'time, even under the same name', (tester) async {
      // A console numbers its files from 001 again, so the same name can be
      // a different dive months later.
      final service = _FakeImportService(
        recordedAt: const Duration(days: 180).inSeconds,
      );
      await _pump(
        tester,
        service: service,
        action: (context, ref) => NavTrackFileActions(
          pickFile: () async => (bytes: _file, name: '023.DAT.csv'),
        ).updateFromFile(context, ref, _route()),
      );

      expect(find.text('Different recording'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('nav-track-update-mismatch-cancel')),
      );
      await tester.pumpAndSettle();

      expect(service.updates, isEmpty);
    });

    testWidgets('updates from a file of another name once confirmed', (
      tester,
    ) async {
      final service = _FakeImportService();
      await _pump(
        tester,
        service: service,
        action: (context, ref) => NavTrackFileActions(
          pickFile: () async => (bytes: _file, name: '024.DAT.csv'),
        ).updateFromFile(context, ref, _route()),
      );

      await tester.tap(
        find.byKey(const ValueKey('nav-track-update-mismatch-confirm')),
      );
      await tester.pumpAndSettle();

      expect(service.updates.single.fileName, '024.DAT.csv');
    });

    testWidgets('says the track is gone when it was deleted meanwhile', (
      tester,
    ) async {
      await _pump(
        tester,
        service: _FakeImportService(updated: false),
        action: (context, ref) => NavTrackFileActions(
          pickFile: () async => (bytes: _file, name: '023.DAT.csv'),
        ).updateFromFile(context, ref, _route()),
      );

      expect(find.text('Track not found.'), findsOneWidget);
      expect(find.textContaining('Track updated'), findsNothing);
    });

    testWidgets('does nothing when no file is picked', (tester) async {
      final service = _FakeImportService();
      await _pump(
        tester,
        service: service,
        action: (context, ref) => NavTrackFileActions(
          pickFile: () async => null,
        ).updateFromFile(context, ref, _route()),
      );

      expect(service.updates, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('reports a file picker that fails instead of dropping the '
        'error', (tester) async {
      final service = _FakeImportService();
      await _pump(
        tester,
        service: service,
        action: (context, ref) => NavTrackFileActions(
          pickFile: () async => throw StateError('picker unavailable'),
        ).updateFromFile(context, ref, _route()),
      );

      expect(service.updates, isEmpty);
      expect(find.textContaining('picker unavailable'), findsOneWidget);
    });

    testWidgets('reports a file it cannot read', (tester) async {
      await _pump(
        tester,
        service: _FakeImportService(
          error: const NavTrackParseException(
            'bad',
            reason: NavTrackParseReason.unreadable,
          ),
        ),
        action: (context, ref) => NavTrackFileActions(
          pickFile: () async => (bytes: _file, name: '023.DAT.csv'),
        ).updateFromFile(context, ref, _route()),
      );

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Track updated'), findsNothing);
    });
  });
}
