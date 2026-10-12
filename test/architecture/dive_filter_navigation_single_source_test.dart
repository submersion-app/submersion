import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// "Show these dives" goes through `openDiveList`, which pushes the dive list
/// so the diver can come back (#2784, #3292). Writing the global dive filter
/// and then `go('/dives')` erases the page the link was on, and its back
/// arrow with it.
///
/// The dive list's own filter controls live in lib/features/dive_log/ and
/// change the filter in place; they are not links, so that folder is exempt.
void main() {
  /// Files outside the dive list permitted to write the filter, with the
  /// reason.
  const allowed = <String, String>{
    'lib/features/import_wizard/presentation/pages/unified_import_wizard.dart':
        'ends a flow; there is nothing to return to',
  };

  final write = RegExp(r'diveFilterProvider\.notifier');

  test(
    'only openDiveList writes the dive filter from outside the dive list',
    () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (path.startsWith('lib/features/dive_log/')) continue;
        if (allowed.containsKey(path)) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].trimLeft().startsWith('//')) continue;
          if (write.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'open the dive list with openDiveList (lib/features/dive_log/'
            'presentation/navigation/open_dive_list.dart) so it is pushed with '
            'a back arrow and the previous filter comes back',
      );
    },
  );

  test('every allowlisted file exists and still writes the filter', () {
    // An allowlist entry that no longer applies is a stale exemption, and a
    // stale exemption is how a guard quietly stops guarding.
    for (final entry in allowed.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} is missing');
      expect(
        write.hasMatch(file.readAsStringSync()),
        isTrue,
        reason:
            '${entry.key} is allowlisted as "${entry.value}" but no longer '
            'writes the filter; remove it from the allowlist',
      );
    }
  });
}
