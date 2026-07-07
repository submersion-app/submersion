import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';

void main() {
  const base = PickedImportFile(
    name: 'a.fit',
    path: '/tmp/a.fit',
    detection: DetectionResult(format: ImportFormat.fit, confidence: 1),
    status: ImportFileStatus.pending,
  );

  test('copyWith updates status/error/diveCount and preserves identity', () {
    final updated = base.copyWith(
      status: ImportFileStatus.parsed,
      diveCount: 3,
    );
    expect(updated.status, ImportFileStatus.parsed);
    expect(updated.diveCount, 3);
    expect(updated.name, 'a.fit');
    expect(updated.path, '/tmp/a.fit');
    expect(updated.detection.format, ImportFormat.fit);

    final failed = base.copyWith(
      status: ImportFileStatus.failed,
      error: 'boom',
    );
    expect(failed.status, ImportFileStatus.failed);
    expect(failed.error, 'boom');
  });

  test('copyWith with no args returns an equivalent instance', () {
    final same = base.copyWith();
    expect(same.name, base.name);
    expect(same.status, base.status);
    expect(same.diveCount, base.diveCount);
    expect(same.error, base.error);
  });

  test('bytes-backed file keeps its buffer', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final f = PickedImportFile(
      name: 'b.uddf',
      bytes: bytes,
      detection: const DetectionResult(
        format: ImportFormat.uddf,
        confidence: 1,
      ),
      status: ImportFileStatus.pending,
    );
    expect(f.copyWith(diveCount: 1).bytes, bytes);
  });
}
