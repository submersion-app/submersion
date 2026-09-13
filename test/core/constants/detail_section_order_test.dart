import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/detail_section_order.dart';

enum _Id { a, b, c, d, e }

class _Cfg {
  const _Cfg(this.id, {this.visible = true});

  final _Id id;
  final bool visible;
}

_Id _idOf(_Cfg c) => c.id;

List<_Id> _ids(List<_Cfg> list) => [for (final c in list) c.id];

List<_Cfg> _all() => [for (final id in _Id.values) _Cfg(id)];

_Cfg _create(_Id id) => _Cfg(id);

void main() {
  group('moveRenderedSection', () {
    test('moves within a fully rendered list like a plain reorder', () {
      final result = moveRenderedSection(_all(), _idOf, _Id.values, 0, 2);
      expect(_ids(result), [_Id.b, _Id.c, _Id.a, _Id.d, _Id.e]);
    });

    test('hidden sections keep their place when one moves to the end', () {
      // b and d are not rendered; a is dropped after e.
      final result = moveRenderedSection(
        _all(),
        _idOf,
        const [_Id.a, _Id.c, _Id.e],
        0,
        2,
      );
      expect(_ids(result), [_Id.b, _Id.c, _Id.d, _Id.e, _Id.a]);
    });

    test('a drop lands immediately before the rendered section after it', () {
      // e is dropped between a and c.
      final result = moveRenderedSection(
        _all(),
        _idOf,
        const [_Id.a, _Id.c, _Id.e],
        2,
        1,
      );
      expect(_ids(result), [_Id.a, _Id.b, _Id.e, _Id.c, _Id.d]);
    });

    test('a drop at the top anchors on the new second section', () {
      final result = moveRenderedSection(
        _all(),
        _idOf,
        const [_Id.b, _Id.c, _Id.d],
        2,
        0,
      );
      expect(_ids(result), [_Id.a, _Id.d, _Id.b, _Id.c, _Id.e]);
    });

    test('equal or out-of-range indices return the same list', () {
      final sections = _all();
      expect(
        identical(
          moveRenderedSection(sections, _idOf, _Id.values, 1, 1),
          sections,
        ),
        isTrue,
      );
      expect(
        identical(
          moveRenderedSection(sections, _idOf, _Id.values, -1, 2),
          sections,
        ),
        isTrue,
      );
      expect(
        identical(
          moveRenderedSection(sections, _idOf, _Id.values, 0, 5),
          sections,
        ),
        isTrue,
      );
      expect(
        identical(
          moveRenderedSection(sections, _idOf, const [_Id.a], 0, 0),
          sections,
        ),
        isTrue,
      );
    });

    test('a rendered id missing from the saved list changes nothing', () {
      final sections = [const _Cfg(_Id.a), const _Cfg(_Id.b)];
      final result = moveRenderedSection(
        sections,
        _idOf,
        const [_Id.c, _Id.a],
        0,
        1,
      );
      expect(identical(result, sections), isTrue);
    });

    test('with no rendered neighbour saved, the moved one goes on top', () {
      // c is rendered but not in the saved list, so a has nothing to anchor
      // on and falls back to the top.
      final result = moveRenderedSection(
        [const _Cfg(_Id.b), const _Cfg(_Id.a)],
        _idOf,
        const [_Id.a, _Id.c],
        0,
        1,
      );
      expect(_ids(result), [_Id.a, _Id.b]);
    });

    test('the moved config is carried over, not recreated', () {
      final sections = [const _Cfg(_Id.a, visible: false), const _Cfg(_Id.b)];
      final result = moveRenderedSection(
        sections,
        _idOf,
        const [_Id.a, _Id.b],
        0,
        1,
      );
      expect(_ids(result), [_Id.b, _Id.a]);
      expect(result.last.visible, isFalse);
    });
  });

  group('ensureAllSections', () {
    test('a complete list comes back as the same instance', () {
      final sections = _all();
      expect(
        identical(
          ensureAllSections(sections, _idOf, _Id.values, _create),
          sections,
        ),
        isTrue,
      );
    });

    test('a missing id lands after its nearest default-order sibling', () {
      final sections = [
        const _Cfg(_Id.e),
        const _Cfg(_Id.b),
        const _Cfg(_Id.a),
        const _Cfg(_Id.d),
      ];
      final result = ensureAllSections(sections, _idOf, _Id.values, _create);
      // c's nearest present predecessor in default order is b.
      expect(_ids(result), [_Id.e, _Id.b, _Id.c, _Id.a, _Id.d]);
    });

    test('a missing first id goes to the top', () {
      final sections = [
        const _Cfg(_Id.c),
        const _Cfg(_Id.b),
        const _Cfg(_Id.d),
        const _Cfg(_Id.e),
      ];
      final result = ensureAllSections(sections, _idOf, _Id.values, _create);
      expect(_ids(result), [_Id.a, _Id.c, _Id.b, _Id.d, _Id.e]);
    });

    test('several missing ids chain behind one another', () {
      final sections = [const _Cfg(_Id.a), const _Cfg(_Id.e)];
      final result = ensureAllSections(sections, _idOf, _Id.values, _create);
      expect(_ids(result), [_Id.a, _Id.b, _Id.c, _Id.d, _Id.e]);
    });

    test('inserted sections come from create', () {
      final result = ensureAllSections(
        [const _Cfg(_Id.a)],
        _idOf,
        _Id.values,
        (id) => _Cfg(id, visible: false),
      );
      expect(result.first.visible, isTrue);
      expect(result.skip(1).every((c) => !c.visible), isTrue);
    });
  });
}
