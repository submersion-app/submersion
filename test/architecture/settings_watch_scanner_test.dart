import 'package:flutter_test/flutter_test.dart';

import 'settings_watch_scanner.dart';

void main() {
  SettingsWatchScan scan(String source) =>
      scanSourceForSettingsWatches(source, 'a.dart');

  test('flags a whole-object watch, wherever it sits in an expression', () {
    final result = scan('''
void build(ref) {
  final a = ref.watch(settingsProvider);
  final b = wrap(ref.watch(settingsProvider));
  final c = ref.watch(settingsProvider).depthUnit;
}
''');

    expect(result.whole.map((w) => w.line), [2, 3, 4]);
  });

  test('flags a watch the formatter split across lines', () {
    final result = scan('''
void build(ref) {
  final a = ref.watch(
    settingsProvider,
  );
}
''');

    expect(result.whole, hasLength(1));
  });

  test('passes a select and counts it', () {
    final result = scan('''
void build(ref) {
  final a = ref.watch(settingsProvider.select((s) => s.depthUnit));
}
''');

    expect(result.whole, isEmpty);
    expect(result.selected, 1);
  });

  test('passes a read, a notifier watch and another provider', () {
    final result = scan('''
void build(ref) {
  final a = ref.read(settingsProvider);
  final b = ref.watch(settingsProvider.notifier);
  final c = ref.watch(otherSettingsProvider);
}
''');

    expect(result.whole, isEmpty);
  });

  test('ignores comments and strings', () {
    final result = scan('''
// ref.watch(settingsProvider)
const a = 'ref.watch(settingsProvider)';
''');

    expect(result.whole, isEmpty);
  });
}
