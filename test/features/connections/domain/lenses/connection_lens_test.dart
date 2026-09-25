import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/lenses/connection_lens.dart';

void main() {
  test('built-in lenses resolve by id', () {
    expect(ConnectionLens.byId('circle'), ConnectionLens.circle);
    expect(ConnectionLens.byId('where'), ConnectionLens.where);
    expect(ConnectionLens.byId('nope'), isNull);
    expect(ConnectionLens.byId(null), isNull);
  });

  test('a lens selection persists as its id', () {
    const sel = LensSelection.lens(ConnectionLens.where);
    expect(sel.persisted, 'where');
    expect(LensSelection.parse('where'), sel);
    expect(sel.kindA, ConnectionKind.buddy);
    expect(sel.kindB, ConnectionKind.site);
  });

  test('a custom pair persists as custom:a:b and parses back', () {
    const sel = LensSelection.custom(
      kindA: ConnectionKind.equipment,
      kindB: ConnectionKind.trip,
    );
    expect(sel.persisted, 'custom:equipment:trip');
    expect(LensSelection.parse(sel.persisted), sel);
    expect(sel.lensId, isNull);
  });

  test('parse falls back to null on garbage', () {
    expect(LensSelection.parse(null), isNull);
    expect(LensSelection.parse('custom:equipment'), isNull);
    expect(LensSelection.parse('custom:unicorn:trip'), isNull);
    expect(
      LensSelection.fallback,
      const LensSelection.lens(ConnectionLens.circle),
    );
  });
}
