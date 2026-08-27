import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/data/services/batch_parse_service.dart';

// The two Subsurface fixtures already in the repo.
const _fixtureDir = 'test/features/universal_import/data/parsers/fixtures';

PickedImportFile ssrfFile(String fixture) {
  return PickedImportFile(
    name: fixture,
    path: '$_fixtureDir/$fixture',
    detection: const DetectionResult(
      format: ImportFormat.subsurfaceXml,
      confidence: 1,
    ),
    status: ImportFileStatus.pending,
  );
}

/// The dual-cylinder fixture is a bare `<dive>` fragment; wrap it in a
/// divelog root so it parses as a standalone file. Bytes-backed on purpose:
/// exercises the no-path branch of the service.
PickedImportFile wrappedDualCylinder() {
  final fragment = File('$_fixtureDir/dual-cylinder.ssrf').readAsStringSync();
  final xml =
      "<divelog program='subsurface' version='3'><dives>"
      '$fragment'
      '</dives></divelog>';
  return PickedImportFile(
    name: 'dual-cylinder.ssrf',
    bytes: Uint8List.fromList(utf8.encode(xml)),
    detection: const DetectionResult(
      format: ImportFormat.subsurfaceXml,
      confidence: 1,
    ),
    status: ImportFileStatus.pending,
  );
}

void main() {
  const service = BatchParseService();

  test('parses all pending files and reports per-file dive counts', () async {
    final result = await service.parseAll([
      wrappedDualCylinder(),
      ssrfFile('profile-events-variety.ssrf'),
    ]);

    expect(result.cancelled, isFalse);
    expect(result.parsed, hasLength(2));
    expect(result.files[0].status, ImportFileStatus.parsed);
    expect(result.files[1].status, ImportFileStatus.parsed);
    expect(result.files[0].diveCount, greaterThan(0));
  });

  test('a corrupt file is marked failed and the batch continues', () async {
    final corrupt = PickedImportFile(
      name: 'corrupt.uddf',
      bytes: Uint8List.fromList(utf8.encode('<uddf><broken')),
      detection: const DetectionResult(
        format: ImportFormat.uddf,
        confidence: 1,
      ),
      status: ImportFileStatus.pending,
    );

    final result = await service.parseAll([
      corrupt,
      ssrfFile('profile-events-variety.ssrf'),
    ]);

    expect(result.files[0].status, ImportFileStatus.failed);
    expect(result.files[0].error, isNotNull);
    expect(result.files[1].status, ImportFileStatus.parsed);
    expect(result.parsed, hasLength(1));
  });

  test('a file that parses to an empty payload is marked failed', () async {
    // Valid UDDF root but no dives -> parser returns an empty payload
    // (not an exception). The service must still flag it as failed.
    final empty = PickedImportFile(
      name: 'empty.uddf',
      bytes: Uint8List.fromList(
        utf8.encode('<uddf version="3.2.1"><profiledata></profiledata></uddf>'),
      ),
      detection: const DetectionResult(
        format: ImportFormat.uddf,
        confidence: 1,
      ),
      status: ImportFileStatus.pending,
    );

    final result = await service.parseAll([empty]);
    expect(result.files.single.status, ImportFileStatus.failed);
    expect(result.parsed, isEmpty);
  });

  test('excluded and unsupported files are skipped untouched', () async {
    final csv = PickedImportFile(
      name: 'log.csv',
      bytes: Uint8List(0),
      detection: const DetectionResult(format: ImportFormat.csv, confidence: 1),
      status: ImportFileStatus.excludedCsv,
    );
    final result = await service.parseAll([
      csv,
      ssrfFile('profile-events-variety.ssrf'),
    ]);
    expect(result.files[0].status, ImportFileStatus.excludedCsv);
    expect(result.parsed, hasLength(1));
  });

  test('cancellation stops at the next file boundary', () async {
    var calls = 0;
    final result = await service.parseAll([
      wrappedDualCylinder(),
      ssrfFile('profile-events-variety.ssrf'),
    ], isCancelled: () => ++calls >= 2);
    expect(result.cancelled, isTrue);
    expect(result.parsed.length, lessThan(2));
  });

  test('reports progress per file', () async {
    final seen = <(int, int)>[];
    await service.parseAll([
      wrappedDualCylinder(),
      ssrfFile('profile-events-variety.ssrf'),
    ], onProgress: (c, t) => seen.add((c, t)));
    expect(seen, contains((1, 2)));
    expect(seen, contains((2, 2)));
  });

  test(
    'scanFolderForImportableFiles filters by extension recursively',
    () async {
      final dir = await Directory.systemTemp.createTemp('bulk_scan_test');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/a.fit').writeAsBytes([0]);
      await Directory('${dir.path}/sub').create();
      await File('${dir.path}/sub/b.uddf').writeAsBytes([0]);
      await File('${dir.path}/notes.txt').writeAsBytes([0]);
      await Directory('${dir.path}/.hidden').create();
      await File('${dir.path}/.hidden/c.fit').writeAsBytes([0]);

      final paths = await scanFolderForImportableFiles(dir.path);
      expect(paths, hasLength(2));
      expect(paths.any((p) => p.endsWith('a.fit')), isTrue);
      expect(paths.any((p) => p.endsWith('b.uddf')), isTrue);
    },
  );
}
