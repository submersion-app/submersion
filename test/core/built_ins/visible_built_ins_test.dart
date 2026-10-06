import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/built_ins/visible_built_ins.dart';

class _Entry {
  const _Entry(this.id, {this.builtIn = true});
  final String id;
  final bool builtIn;
}

List<_Entry> _visible(
  List<_Entry> all,
  Set<String> hidden, {
  Iterable<String?> keep = const [],
}) => visibleBuiltIns(
  all,
  hidden,
  isBuiltIn: (e) => e.builtIn,
  idOf: (e) => e.id,
  keep: keep,
);

void main() {
  const a = _Entry('a');
  const b = _Entry('b');
  const c = _Entry('c');
  const customB = _Entry('b', builtIn: false);

  test('returns the same list when nothing is hidden', () {
    final all = [a, b];
    expect(identical(_visible(all, const {}), all), isTrue);
  });

  test('drops hidden built-ins and keeps the order of the rest', () {
    expect(_visible([a, b, c], {'b'}), [a, c]);
  });

  test('never drops a custom entry, even one sharing a built-in id', () {
    expect(_visible([a, customB], {'b'}), [a, customB]);
  });

  test('keeps a hidden entry that is currently selected', () {
    expect(_visible([a, b, c], {'b', 'c'}, keep: ['c', null]), [a, c]);
  });

  test('ignores hidden ids that match nothing', () {
    final all = [a, b];
    expect(identical(_visible(all, {'gone'}), all), isTrue);
  });
}
