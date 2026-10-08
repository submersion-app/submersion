import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

void main() {
  test('wire form round-trips through parse', () {
    const ref = NodeRef(ConnectionKind.diveCenter, 'abc:with:colons');
    expect(ref.wire, 'diveCenter:abc:with:colons');
    expect(NodeRef.parse(ref.wire), ref);
  });

  test('parse rejects malformed values', () {
    expect(NodeRef.parse(null), isNull);
    expect(NodeRef.parse(''), isNull);
    expect(NodeRef.parse('buddy'), isNull);
    expect(NodeRef.parse('buddy:'), isNull);
    expect(NodeRef.parse(':abc'), isNull);
    expect(NodeRef.parse('unicorn:abc'), isNull);
  });

  test('kinds without a detail page return null routes', () {
    expect(ConnectionKind.buddy.detailRoute('b1'), '/buddies/b1');
    expect(ConnectionKind.site.detailRoute('s1'), '/sites/s1');
    expect(ConnectionKind.tag.detailRoute('t1'), isNull);
    expect(ConnectionKind.diveComputer.detailRoute('c1'), isNull);
  });

  test('every kind but tag borrows a destination accent', () {
    for (final kind in ConnectionKind.values) {
      expect(
        kind.accentFeatureId,
        kind == ConnectionKind.tag ? isNull : isNotNull,
      );
    }
  });

  test('copyWith replaces only what it is given', () {
    const r = NodeRef(ConnectionKind.buddy, 'jane');
    expect(r.copyWith(id: 'ken'), const NodeRef(ConnectionKind.buddy, 'ken'));
    expect(
      r.copyWith(kind: ConnectionKind.site),
      const NodeRef(ConnectionKind.site, 'jane'),
    );
    expect(r.copyWith(), r);
  });
}
