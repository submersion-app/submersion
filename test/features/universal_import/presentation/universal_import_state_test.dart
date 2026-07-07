import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_state.dart';

PickedImportFile file(String name, {Uint8List? bytes, String? path}) {
  return PickedImportFile(
    name: name,
    path: path,
    bytes: bytes,
    detection: const DetectionResult(format: ImportFormat.uddf, confidence: 1),
    status: ImportFileStatus.pending,
  );
}

void main() {
  test('single file exposes fileBytes and fileName as before', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final state = UniversalImportState(files: [file('a.uddf', bytes: bytes)]);
    expect(state.fileName, 'a.uddf');
    expect(state.fileBytes, bytes);
    expect(state.isBatch, isFalse);
  });

  test('batch exposes a count label and null fileBytes', () {
    final state = UniversalImportState(
      files: [
        file('a.uddf', path: '/tmp/a'),
        file('b.fit', path: '/tmp/b'),
      ],
    );
    expect(state.fileName, '2 files');
    expect(state.fileBytes, isNull);
    expect(state.isBatch, isTrue);
  });

  test('empty files means no fileName and no batch', () {
    const state = UniversalImportState();
    expect(state.fileName, isNull);
    expect(state.fileBytes, isNull);
    expect(state.isBatch, isFalse);
    expect(state.pendingFiles, isEmpty);
  });

  test('copyWith replaces files and clearFiles empties them', () {
    final state = UniversalImportState(files: [file('a.uddf')]);
    final replaced = state.copyWith(files: [file('b.fit')]);
    expect(replaced.files.single.name, 'b.fit');
    expect(state.copyWith(clearFiles: true).files, isEmpty);
  });

  test('pendingFiles filters by status', () {
    final pending = file('a.uddf');
    const failed = PickedImportFile(
      name: 'b.fit',
      detection: DetectionResult(format: ImportFormat.fit, confidence: 1),
      status: ImportFileStatus.failed,
      error: 'boom',
    );
    final state = UniversalImportState(files: [pending, failed]);
    expect(state.pendingFiles.map((f) => f.name), ['a.uddf']);
  });

  test('clearDetectionResult clears a stale detection', () {
    const detection = DetectionResult(format: ImportFormat.fit, confidence: 1);
    const state = UniversalImportState(detectionResult: detection);
    expect(state.copyWith(clearDetectionResult: true).detectionResult, isNull);
    expect(state.copyWith().detectionResult, detection);
  });
}
