import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

/// Schema v241 (issue #2440) gave tank pressure series a real foreign key to
/// their data source. Sync must guard it like the profile series' own, or a
/// series whose source was deleted on a peer keeps pointing at nothing.
void main() {
  test('tank pressure series guard their source like profile series do', () {
    final refs = SyncService.parentRefs['tankPressureSeries']!;
    final source = refs.singleWhere((r) => r.field == 'sourceId');
    expect(source.parent, 'diveDataSources');
    expect(source.nullable, isTrue);

    final profileSource = SyncService.parentRefs['diveProfileSeries']!
        .singleWhere((r) => r.field == 'sourceId');
    expect(source.parent, profileSource.parent);
    expect(source.nullable, profileSource.nullable);
  });
}
