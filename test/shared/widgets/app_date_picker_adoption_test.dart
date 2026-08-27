import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The bare Material pickers take their manual-entry format from the ambient
/// locale, so any call site that skips the wrapper silently reverts to
/// MM/DD/YYYY for a diver who chose something else (#964). Guard the whole
/// tree rather than the two call sites that regressed, because the next one
/// will be somewhere new.
void main() {
  // The wrapper is the one place allowed to call the Material pickers.
  final wrapper = p.join('lib', 'shared', 'widgets', 'app_date_picker.dart');

  // The leading guard keeps `showAppDatePicker` and privately named helpers
  // such as `_showDatePicker` out; a bare call inside such a helper still
  // matches on its own line.
  final bareCall = RegExp(r'(?<![A-Za-z_])show(Date|DateRange)Picker\s*\(');

  test('every date picker call site goes through the shared wrapper', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (p.equals(entity.path, wrapper)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Comments name the Material functions when explaining their
        // assertions; only real calls matter.
        if (line.trimLeft().startsWith('//')) continue;
        if (bareCall.hasMatch(line)) {
          offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use showAppDatePicker / showAppDateRangePicker from '
          'lib/shared/widgets/app_date_picker.dart so manual date entry '
          'honors the diver\'s date format setting.',
    );
  });
}
