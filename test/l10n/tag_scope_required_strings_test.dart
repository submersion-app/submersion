import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Manage Tags scope editor shows `tags_manage_scopeRequired` when every
/// scope checkbox is cleared (issue #1942). The message must name every scope
/// the editor offers, in the words its checkboxes use, so adding equipment as
/// a third scope cannot leave a message that still says "dives, sites, or
/// both".
void main() {
  const scopeLabelKeys = [
    'tags_manage_scope_dives',
    'tags_manage_scope_sites',
    'tags_manage_scope_equipment',
  ];

  final arbFiles = Directory(
    'lib/l10n/arb',
  ).listSync().whereType<File>().where((f) => f.path.endsWith('.arb')).toList();

  test('there are ARB files to check', () {
    expect(arbFiles, hasLength(greaterThanOrEqualTo(11)));
  });

  for (final file in arbFiles) {
    final locale = file.uri.pathSegments.last;
    test('$locale: the scope-required message names every scope', () {
      final arb = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      final message = (arb['tags_manage_scopeRequired'] as String)
          .toLowerCase();
      for (final key in scopeLabelKeys) {
        final label = (arb[key] as String).toLowerCase();
        expect(message, contains(label), reason: '$key "$label"');
      }
    });
  }
}
