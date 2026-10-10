import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';

void main() {
  test('defaults: graph view, web and radial, auto labels, spacing 1', () {
    const d = ConnectionsDisplay.initial;
    expect(d.view, ConnectionsViewKind.graph);
    expect(d.layoutFor(around: false), ConnectionsLayout.web);
    expect(d.layoutFor(around: true), ConnectionsLayout.radial);
    expect(d.labels, LabelMode.auto);
    expect(d.nodeSize, NodeSizeMode.byDives);
    expect(d.edges, EdgeMode.weighted);
    expect(d.hideUnconnected, isFalse);
    expect(d.spacing, 1.0);
  });

  test('each mode offers its own layouts, default first', () {
    expect(ConnectionsLayout.forMap.first, ConnectionsLayout.web);
    expect(ConnectionsLayout.forAround.first, ConnectionsLayout.radial);
    expect(ConnectionsLayout.forMap, isNot(contains(ConnectionsLayout.radial)));
    expect(ConnectionsLayout.forAround, isNot(contains(ConnectionsLayout.web)));
  });

  test('withLayout sets one mode and ignores a layout it does not offer', () {
    final d = ConnectionsDisplay.initial
        .withLayout(ConnectionsLayout.columns, around: false)
        .withLayout(ConnectionsLayout.timeline, around: true);
    expect(d.mapLayout, ConnectionsLayout.columns);
    expect(d.aroundLayout, ConnectionsLayout.timeline);
    expect(d.withLayout(ConnectionsLayout.web, around: true), d);
    expect(d.withLayout(ConnectionsLayout.radial, around: false), d);
  });

  test('copyWith clamps spacing', () {
    expect(ConnectionsDisplay.initial.copyWith(spacing: 9).spacing, 2.0);
    expect(ConnectionsDisplay.initial.copyWith(spacing: 0.1).spacing, 0.6);
  });

  test('JSON round trip keeps every field', () {
    final d = ConnectionsDisplay.initial
        .copyWith(
          view: ConnectionsViewKind.matrix,
          labels: LabelMode.off,
          nodeSize: NodeSizeMode.uniform,
          edges: EdgeMode.selectedOnly,
          hideUnconnected: true,
          spacing: 1.4,
        )
        .withLayout(ConnectionsLayout.clusters, around: false)
        .withLayout(ConnectionsLayout.circle, around: true);
    expect(ConnectionsDisplay.fromJson(d.toJson()), d);
  });

  test('anything but a map restores the defaults', () {
    expect(ConnectionsDisplay.fromJson(null), ConnectionsDisplay.initial);
    expect(ConnectionsDisplay.fromJson('x'), ConnectionsDisplay.initial);
    expect(ConnectionsDisplay.fromJson(const [1]), ConnectionsDisplay.initial);
  });

  test('each field falls back on its own', () {
    final d = ConnectionsDisplay.fromJson({
      'view': 'bogus',
      'labels': 7,
      'edges': 'thin',
      'mapLayout': 'radial',
      'aroundLayout': 'web',
      'hideUnconnected': 'yes',
      'spacing': 'wide',
    });
    expect(d.view, ConnectionsViewKind.graph);
    expect(d.labels, LabelMode.auto);
    expect(d.edges, EdgeMode.thin);
    expect(d.mapLayout, ConnectionsLayout.web);
    expect(d.aroundLayout, ConnectionsLayout.radial);
    expect(d.hideUnconnected, isFalse);
    expect(d.spacing, 1.0);
    expect(ConnectionsDisplay.fromJson({'spacing': 5}).spacing, 2.0);
  });
}
