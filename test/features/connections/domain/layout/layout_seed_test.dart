import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/layout_seed.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

void main() {
  test('the seed ignores input order', () {
    expect(
      LayoutSeed.seedFor([_b('a'), _b('b'), _b('c')]),
      LayoutSeed.seedFor([_b('c'), _b('a'), _b('b')]),
    );
    expect(
      LayoutSeed.seedFor([_b('a'), _b('b')]),
      isNot(LayoutSeed.seedFor([_b('a'), _b('x')])),
    );
  });

  test('circle positions are deterministic, finite and distinct', () {
    final refs = [for (var i = 0; i < 12; i++) _b('n$i')];
    final p1 = LayoutSeed.circle(refs);
    final p2 = LayoutSeed.circle(refs.reversed.toList());
    expect(p1, p2);
    expect(p1.length, 12);
    expect(p1.values.every((p) => p.isFinite), isTrue);
    expect(p1.values.toSet().length, 12);
  });

  test('an empty ref list yields no positions', () {
    expect(LayoutSeed.circle(const []), isEmpty);
  });
}
