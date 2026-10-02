import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/canvas/label_collision.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

void main() {
  test('a lower-ranked overlapping label is hidden, disjoint ones survive', () {
    final visible = LabelCollision.visible([
      (ref: _b('first'), rect: const Rect.fromLTWH(0, 0, 50, 10)),
      (ref: _b('overlaps'), rect: const Rect.fromLTWH(40, 5, 50, 10)),
      (ref: _b('clear'), rect: const Rect.fromLTWH(200, 0, 50, 10)),
    ]);
    expect(visible, {_b('first'), _b('clear')});
  });

  test('touching edges do not count as overlap', () {
    final visible = LabelCollision.visible([
      (ref: _b('a'), rect: const Rect.fromLTWH(0, 0, 50, 10)),
      (ref: _b('b'), rect: const Rect.fromLTWH(50, 0, 50, 10)),
    ]);
    expect(visible.length, 2);
  });

  test('a label over another node is hidden', () {
    final visible = LabelCollision.visible(
      [(ref: _b('a'), rect: const Rect.fromLTWH(0, 0, 60, 12))],
      obstacles: [Rect.fromCircle(center: const Offset(30, 6), radius: 10)],
    );
    expect(visible, isEmpty);
  });

  test('an exempt label shows over a disc', () {
    final visible = LabelCollision.visible(
      [(ref: _b('a'), rect: const Rect.fromLTWH(0, 0, 60, 12))],
      obstacles: [Rect.fromCircle(center: const Offset(30, 6), radius: 10)],
      exempt: {_b('a')},
    );
    expect(visible, {_b('a')});
  });
}
