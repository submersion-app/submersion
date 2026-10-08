import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/saved_connection_map.dart';

void main() {
  test('parses a known spec and rejects an unknown kind', () {
    final t = DateTime.utc(2026);
    final ok = SavedConnectionMap.tryParse(
      id: 'm1',
      diverId: 'me',
      name: 'Trip',
      specJson: '{"kinds":["buddy","trip"],"links":["buddy-trip"],"min":2}',
      sortOrder: 0,
      createdAt: t,
      updatedAt: t,
    );
    expect(ok!.spec.minSharedDives, 2);
    expect(
      SavedConnectionMap.tryParse(
        id: 'm2',
        diverId: 'me',
        name: 'Future',
        specJson: '{"kinds":["hologram"],"links":[],"min":1}',
        sortOrder: 0,
        createdAt: t,
        updatedAt: t,
      ),
      isNull,
    );
    expect(
      SavedConnectionMap.tryParse(
        id: 'm3',
        diverId: 'me',
        name: 'Broken',
        specJson: 'not json',
        sortOrder: 0,
        createdAt: t,
        updatedAt: t,
      ),
      isNull,
    );
  });
}
