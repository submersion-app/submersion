import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The feature is a "shared site library" (issue #2567): the earlier
/// organisation word never appears in its code, tests, routes, strings or
/// design docs. Unrelated older uses elsewhere in the app are not scanned.
void main() {
  // Split so this file never spells the word itself.
  final banned = RegExp(
    'cl'
    'ub',
    caseSensitive: false,
  );
  final roots = [
    p.join('lib', 'core', 'services', 'shared_library'),
    p.join('lib', 'features', 'shared_library'),
    p.join('test', 'core', 'services', 'shared_library'),
    p.join('test', 'features', 'shared_library'),
  ];
  final docs = [
    p.join(
      'docs',
      'design',
      'specs',
      '2026-10-12-shared-dive-site-library-design.md',
    ),
    p.join('docs', 'design', 'plans', '2026-10-12-shared-dive-site-library.md'),
    p.join(
      'docs',
      'design',
      'specs',
      '2026-10-12-shared-site-library-security-and-backup-design.md',
    ),
    p.join(
      'docs',
      'design',
      'plans',
      '2026-10-12-shared-site-library-security-and-backup.md',
    ),
  ];

  List<String> hitsIn(File f) {
    final lines = f.readAsLinesSync();
    return [
      for (var i = 0; i < lines.length; i++)
        if (banned.hasMatch(lines[i])) '${f.path}:${i + 1}',
    ];
  }

  test('feature files never use the earlier name', () {
    final hits = <String>[
      for (final root in roots)
        for (final f in Directory(root).listSync(recursive: true))
          if (f is File && f.path.endsWith('.dart')) ...hitsIn(f),
      for (final d in docs) ...hitsIn(File(d)),
    ];
    expect(hits, isEmpty);
  });

  test('shared library strings never use the earlier name', () {
    final hits = <String>[];
    for (final f in Directory(p.join('lib', 'l10n', 'arb')).listSync()) {
      if (f is! File || !f.path.endsWith('.arb')) continue;
      final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      for (final e in json.entries) {
        if (!e.key.startsWith('sharedLibrary_')) continue;
        if (banned.hasMatch('${e.value}')) hits.add('${f.path}:${e.key}');
      }
    }
    expect(hits, isEmpty);
  });

  test('routes use shared-libraries', () {
    final router = File(
      p.join('lib', 'core', 'router', 'app_router.dart'),
    ).readAsStringSync();
    final code = router.replaceAll(RegExp(r'//.*'), '');
    expect(banned.hasMatch(code), isFalse);
  });
}
