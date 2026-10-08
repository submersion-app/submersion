import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/presentation/canvas/node_metrics.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';

void main() {
  test('radius grows with the square root and is clamped', () {
    expect(NodeMetrics.radiusFor(0, 100), NodeMetrics.minRadius);
    expect(NodeMetrics.radiusFor(100, 100), NodeMetrics.maxRadius);
    final quarter = NodeMetrics.radiusFor(25, 100);
    final half = NodeMetrics.radiusFor(50, 100);
    expect(quarter, lessThan(half));
    expect(
      quarter - NodeMetrics.minRadius,
      closeTo((NodeMetrics.maxRadius - NodeMetrics.minRadius) / 2, 1e-9),
    );
    expect(
      NodeMetrics.radiusFor(3, 0),
      NodeMetrics.maxRadius,
      reason: 'a zero max never divides',
    );
  });

  test('edge width and opacity scale with weight', () {
    expect(
      NodeMetrics.edgeWidthFor(1, 10),
      lessThan(NodeMetrics.edgeWidthFor(10, 10)),
    );
    expect(NodeMetrics.edgeOpacityFor(10, 10), lessThanOrEqualTo(1));
    expect(NodeMetrics.edgeOpacityFor(1, 10), greaterThan(0));
  });

  test('initials take the first letters of up to two words', () {
    expect(NodeMetrics.initialsFor('Jane Doe'), 'JD');
    expect(NodeMetrics.initialsFor('  cher '), 'C');
    expect(NodeMetrics.initialsFor('Salt Pier North'), 'SP');
    expect(NodeMetrics.initialsFor(''), '');
  });

  test('glyphFor picks photo, icon, initials or nothing', () {
    expect(
      NodeMetrics.glyphFor(
        kind: ConnectionKind.buddy,
        hasPhoto: true,
        radius: 20,
      ),
      NodeGlyph.photo,
    );
    expect(
      NodeMetrics.glyphFor(
        kind: ConnectionKind.buddy,
        hasPhoto: true,
        radius: 10,
      ),
      NodeGlyph.none,
    );
    expect(
      NodeMetrics.glyphFor(
        kind: ConnectionKind.buddy,
        hasPhoto: false,
        radius: 20,
      ),
      NodeGlyph.initials,
    );
    expect(
      NodeMetrics.glyphFor(
        kind: ConnectionKind.site,
        hasPhoto: false,
        radius: 18,
      ),
      NodeGlyph.icon,
    );
    expect(
      NodeMetrics.glyphFor(
        kind: ConnectionKind.site,
        hasPhoto: false,
        radius: 15,
      ),
      NodeGlyph.initials,
    );
    expect(
      NodeMetrics.glyphFor(
        kind: ConnectionKind.site,
        hasPhoto: false,
        radius: 8,
      ),
      NodeGlyph.none,
    );
  });
}
