import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/entities/saved_connection_map.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';

const _jane = NodeRef(ConnectionKind.buddy, 'jane');
const _ken = NodeRef(ConnectionKind.buddy, 'ken');
const _pier = NodeRef(ConnectionKind.site, 'pier');

void main() {
  group('ConnectionEdge', () {
    final edge = ConnectionEdge(
      source: _jane,
      target: _ken,
      weight: 3,
      firstDiveAt: DateTime.utc(2021),
      lastDiveAt: DateTime.utc(2024),
    );

    test('touches and otherEnd name the two ends', () {
      expect(edge.touches(_jane), isTrue);
      expect(edge.touches(_pier), isFalse);
      expect(edge.otherEnd(_jane), _ken);
      expect(edge.otherEnd(_ken), _jane);
      expect(edge.otherEnd(_pier), isNull);
    });

    test('copyWith replaces only what it is given', () {
      final moved = edge.copyWith(
        target: _pier,
        weight: 5,
        firstDiveAt: DateTime.utc(2020),
        lastDiveAt: DateTime.utc(2025),
      );
      expect(moved.source, _jane);
      expect(moved.target, _pier);
      expect(moved.weight, 5);
      expect(moved.firstDiveAt, DateTime.utc(2020));
      expect(moved.lastDiveAt, DateTime.utc(2025));
      expect(edge.copyWith(), edge);
      expect(edge.copyWith(source: _pier).source, _pier);
    });
  });

  group('ConnectionNode', () {
    const node = ConnectionNode(ref: _jane, label: 'Jane', diveCount: 4);

    test('copyWith replaces only what it is given', () {
      final changed = node.copyWith(
        ref: _ken,
        label: 'Ken',
        diveCount: 7,
        subtitle: const TextSubtitle('Buddy'),
        hop: 2,
      );
      expect(changed.ref, _ken);
      expect(changed.label, 'Ken');
      expect(changed.diveCount, 7);
      expect(changed.subtitle, const TextSubtitle('Buddy'));
      expect(changed.hop, 2);
      expect(node.copyWith(), node);
    });

    test('subtitles compare by value', () {
      expect(const TextSubtitle('a'), const TextSubtitle('a'));
      expect(
        DateRangeSubtitle(DateTime.utc(2021), DateTime.utc(2022)),
        DateRangeSubtitle(DateTime.utc(2021), DateTime.utc(2022)),
      );
      expect(
        const RoleSubtitle('instructor'),
        const RoleSubtitle('instructor'),
      );
      expect(const RoleSubtitle('a'), isNot(const RoleSubtitle('b')));
    });
  });

  group('SavedConnectionMap', () {
    final map = SavedConnectionMap(
      id: 'm1',
      diverId: 'me',
      name: 'Bonaire',
      spec: ConnectionPresets.byId('travel')!.spec,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    test('copyWith changes name, spec and order, and keeps the rest', () {
      final reef = ConnectionPresets.byId('reef')!.spec;
      final changed = map.copyWith(
        name: 'Bonaire 2025',
        spec: reef,
        sortOrder: 3,
      );
      expect(changed.name, 'Bonaire 2025');
      expect(changed.spec, reef);
      expect(changed.sortOrder, 3);
      expect(changed.id, 'm1');
      expect(changed.diverId, 'me');
      expect(changed.createdAt, map.createdAt);
      expect(changed.updatedAt, map.updatedAt);
      expect(map.copyWith(), map);
    });

    test('equality follows every field', () {
      expect(map, map.copyWith());
      expect(map, isNot(map.copyWith(sortOrder: 1)));
    });
  });
}
