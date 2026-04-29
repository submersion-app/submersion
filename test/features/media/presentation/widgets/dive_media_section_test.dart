import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/widgets/dive_media_section.dart';

void main() {
  test('showInOsFileManagerLabel returns OS-appropriate label', () {
    final label = showInOsFileManagerLabel();
    if (Platform.isMacOS) {
      expect(label, 'Show in Finder');
    } else if (Platform.isWindows) {
      expect(label, 'Show in Explorer');
    } else {
      // Linux / iOS / Android fallback.
      expect(label, 'Show in Files');
    }
  });
}
