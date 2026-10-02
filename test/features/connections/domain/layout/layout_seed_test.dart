import 'dart:math' as math;

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

  test('each kind starts in one contiguous sector', () {
    // Swept over sizes: once the spacing between neighbours drops below a
    // fixed angular jitter, kinds interleave at their boundaries.
    for (var n = 20; n <= 300; n += 20) {
      final refs = [
        for (var i = 0; i < n; i++) NodeRef(ConnectionKind.buddy, 'b$i'),
        for (var i = 0; i < n; i++) NodeRef(ConnectionKind.site, 's$i'),
        for (var i = 0; i < n; i++) NodeRef(ConnectionKind.trip, 't$i'),
      ];
      final p = LayoutSeed.circle(refs);
      double angle(NodeRef r) {
        final a = math.atan2(p[r]!.y, p[r]!.x);
        return a < 0 ? a + 2 * math.pi : a;
      }

      final sorted = [...refs]..sort((x, y) => angle(x).compareTo(angle(y)));
      final kinds = sorted.map((r) => r.kind).toList();
      var switches = 0;
      for (var i = 1; i < kinds.length; i++) {
        if (kinds[i] != kinds[i - 1]) switches++;
      }
      expect(
        switches,
        lessThanOrEqualTo(3),
        reason: 'three sectors, at most three boundaries (n = $n)',
      );
    }
  });
}
