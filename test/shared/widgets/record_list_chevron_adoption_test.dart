// pre-push: scans lib/
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Every record list drew its own ">" with a bare `Icons.chevron_right`, at
/// its own size, padding and place in the row, so no two lists put it in the
/// same spot (#4639). [RecordListChevron] fixes the place once; this keeps a
/// new or edited record row from going back to a bare icon.
void main() {
  // Record cards whose file name does not end in `_list_tile.dart`.
  final namedFiles = {
    for (final (feature, folder, file) in [
      ('dive_log', 'pages', 'dive_list_page.dart'),
      ('trips', 'widgets', 'trip_list_content.dart'),
      ('dive_centers', 'widgets', 'dive_center_list_content.dart'),
      ('certifications', 'widgets', 'certification_list_content.dart'),
      ('equipment', 'widgets', 'equipment_list_content.dart'),
      ('courses', 'widgets', 'course_card.dart'),
    ])
      p.join('lib', 'features', feature, 'presentation', folder, file),
  };

  final bareChevron = RegExp(r'Icons\.chevron_right\b');

  test('record list rows draw their chevron with RecordListChevron', () {
    final offenders = <String>[];
    var scanned = 0;

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = p.normalize(entity.path);
      final isRecordRow =
          path.endsWith('_list_tile.dart') || namedFiles.contains(path);
      if (!isRecordRow) continue;
      scanned++;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (bareChevron.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
      }
    }

    // Every named file still exists, so a rename cannot hollow the guard.
    for (final file in namedFiles) {
      expect(File(file).existsSync(), isTrue, reason: '$file was moved');
    }
    expect(scanned, greaterThan(namedFiles.length));
    expect(
      offenders,
      isEmpty,
      reason:
          'Use RecordListChevron (or RecordListChevronRow / '
          'RecordListChevronOverlay) from '
          'lib/shared/widgets/record_list_chevron.dart, so the chevron sits '
          'one row padding from the edge like every other list.',
    );
  });
}
