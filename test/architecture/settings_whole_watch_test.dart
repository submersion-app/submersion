import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'settings_watch_scanner.dart';

/// Pages that edit the settings show most of what they watch, so a `select`
/// would list dozens of fields to skip almost no rebuilds. One entry per file.
final _allowed = <String, String>{
  _page('settings_page.dart'): 'the settings hub, with a row for each setting',
  _page('decompression_settings_page.dart'): 'edits the deco settings',
  _page('default_visible_metrics_page.dart'): 'a toggle for each metric',
  _page('safety_hub_page.dart'): 'summarises each safety settings page',
  _page('section_appearance_page.dart'): 'edits the profile display settings',
  p.join(
    'lib',
    'features',
    'settings',
    'presentation',
    'widgets',
    'planner_gas_defaults_section.dart',
  ): 'edits the planner gas defaults',
};

String _page(String file) =>
    p.join('lib', 'features', 'settings', 'presentation', 'pages', file);

/// Guards the rule that nothing watches the whole of `AppSettings` (issue
/// #3818).
///
/// `settingsProvider` is one object, so a whole-object watch rebuilds on every
/// settings edit whatever it reads. With hundreds of them, one toggle rebuilt
/// list rows, the dive table and the widgets behind every open route.
///
/// Watch `unitFormatterProvider` for a `UnitFormatter`, and
/// `settingsProvider.select` for anything else. Several fields can be selected
/// together as a record, which compares field by field.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();

  final result = scanForSettingsWatches(
    files: dartFiles,
    relativize: p.relative,
  );

  test('the scan found the select calls, so it cannot pass vacuously', () {
    expect(dartFiles.length, greaterThan(1000));
    expect(result.selected, greaterThanOrEqualTo(200));
  });

  test('nothing watches the whole of AppSettings', () {
    final flagged = result.whole
        .where((watch) => !_allowed.containsKey(watch.file))
        .toList();
    expect(
      flagged,
      isEmpty,
      reason:
          'Whole-object watches of settingsProvider. Each one below rebuilds '
          'on every settings edit, whatever it reads.\n\n'
          'Use ref.watch(unitFormatterProvider) for a UnitFormatter, and '
          'ref.watch(settingsProvider.select((s) => ...)) for anything else. '
          'A page that edits the settings and shows most of them can be added '
          'to the allowed list with a reason.\n\n'
          '${flagged.join('\n')}',
    );
  });

  test('every allowed file still has a whole-object watch', () {
    final watching = result.whole.map((watch) => watch.file).toSet();
    expect(_allowed.keys.toSet().difference(watching), isEmpty);
  });
}
