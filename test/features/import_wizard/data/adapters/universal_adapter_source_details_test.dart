import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart'
    as ui;
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

class _SettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _SettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImportNotifier extends UniversalImportNotifier {
  _ImportNotifier(
    super.ref,
    List<PickedImportFile> files,
    ImportOptions? opts,
  ) {
    state = state.copyWith(
      files: files,
      options: opts,
      payload: ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {
              'dateTime': DateTime(2026, 3, 15, 10, 32),
              'maxDepth': 20.0,
              'runtime': const Duration(minutes: 40),
            },
          ],
        },
      ),
    );
  }
}

PickedImportFile _file(
  String name,
  ui.ImportFormat format, {
  ui.SourceApp? app,
  int bytes = 0,
  String? path,
  ImportFileStatus status = ImportFileStatus.parsed,
}) => PickedImportFile(
  name: name,
  path: path,
  bytes: path == null ? Uint8List(bytes) : null,
  detection: DetectionResult(format: format, sourceApp: app, confidence: 1),
  status: status,
);

Future<ImportSourceDetails> _details(
  WidgetTester tester,
  List<PickedImportFile> files, {
  ImportOptions? options,
}) async {
  late UniversalAdapter adapter;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        universalImportNotifierProvider.overrideWith(
          (ref) => _ImportNotifier(ref, files, options),
        ),
        settingsProvider.overrideWith((ref) => _SettingsNotifier()),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            adapter = UniversalAdapter(ref: ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Reading a path-backed file's size is real I/O.
  final bundle = await tester.runAsync(adapter.buildBundle);
  return bundle!.source.details;
}

void main() {
  group('UniversalAdapter source details (#161)', () {
    testWidgets('single file: name, detected format and app, size', (
      tester,
    ) async {
      final details = await _details(tester, [
        _file(
          'logbook.uddf',
          ui.ImportFormat.uddf,
          app: ui.SourceApp.subsurface,
          bytes: 2048,
        ),
      ]);

      expect(details.title, 'logbook.uddf');
      expect(details.formats, ['UDDF']);
      expect(details.sourceApp, 'Subsurface');
      expect(details.sizeBytes, 2048);
      expect(details.fileCount, 1);
    });

    testWidgets('single file: the confirmed format and app win', (
      tester,
    ) async {
      final details = await _details(
        tester,
        [_file('dives.xml', ui.ImportFormat.unknown)],
        options: const ImportOptions(
          sourceApp: ui.SourceApp.macdive,
          format: ui.ImportFormat.macdiveXml,
        ),
      );

      expect(details.formats, ['MacDive XML']);
      expect(details.sourceApp, 'MacDive');
    });

    testWidgets('an unidentified app is left out', (tester) async {
      final details = await _details(tester, [
        _file('dives.csv', ui.ImportFormat.csv, app: ui.SourceApp.generic),
      ]);

      expect(details.sourceApp, isNull);
    });

    testWidgets('batch: count, distinct formats, shared app, total size', (
      tester,
    ) async {
      final details = await _details(tester, [
        _file('a.uddf', ui.ImportFormat.uddf, bytes: 1000),
        _file('b.fit', ui.ImportFormat.fit, bytes: 500),
        _file('c.uddf', ui.ImportFormat.uddf, bytes: 250),
      ]);

      expect(details.title, isNull);
      expect(details.fileCount, 3);
      expect(details.formats, ['UDDF', 'Garmin FIT']);
      expect(details.sourceApp, isNull);
      expect(details.sizeBytes, 1750);
    });

    testWidgets('batch: files the batch did not import are left out', (
      tester,
    ) async {
      final details = await _details(tester, [
        _file('a.uddf', ui.ImportFormat.uddf, bytes: 1000),
        _file('b.uddf', ui.ImportFormat.uddf, bytes: 500),
        _file(
          'c.csv',
          ui.ImportFormat.csv,
          bytes: 70,
          status: ImportFileStatus.excludedCsv,
        ),
        _file(
          'd.fit',
          ui.ImportFormat.fit,
          bytes: 80,
          status: ImportFileStatus.failed,
        ),
        _file(
          'e.bin',
          ui.ImportFormat.unknown,
          bytes: 90,
          status: ImportFileStatus.unsupported,
        ),
      ]);

      expect(details.fileCount, 2);
      expect(details.formats, ['UDDF']);
      expect(details.sizeBytes, 1500);
    });

    testWidgets('batch: one imported file reads as a single file', (
      tester,
    ) async {
      final details = await _details(tester, [
        _file('a.uddf', ui.ImportFormat.uddf, bytes: 10),
        _file(
          'b.bin',
          ui.ImportFormat.unknown,
          status: ImportFileStatus.unsupported,
        ),
      ]);

      expect(details.title, 'a.uddf');
      expect(details.fileCount, 1);
    });

    testWidgets('reads the size of a path-backed file from disk', (
      tester,
    ) async {
      final dir = Directory.systemTemp.createTempSync('source_details');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File(p.join(dir.path, 'big.uddf'))
        ..writeAsBytesSync(List.filled(4096, 0));

      final details = await _details(tester, [
        _file('big.uddf', ui.ImportFormat.uddf, path: file.path),
        _file('small.uddf', ui.ImportFormat.uddf, bytes: 4),
      ]);

      expect(details.sizeBytes, 4100);
    });

    testWidgets('a file that cannot be read leaves the size out', (
      tester,
    ) async {
      final details = await _details(tester, [
        _file(
          'gone.uddf',
          ui.ImportFormat.uddf,
          path: p.join(Directory.systemTemp.path, 'no-such-dir', 'gone.uddf'),
        ),
      ]);

      expect(details.title, 'gone.uddf');
      expect(details.sizeBytes, isNull);
    });
  });
}
