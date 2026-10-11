import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v278: no data change. It exists to carry the sync floor past every
/// build that cannot parse AccountKind.webdav (issue #2361).
void main() {
  test('v278 is in the ladder and is the current schema', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(278));
    expect(AppDatabase.migrationVersions, contains(278));
    expect(
      AppDatabase.migrationStepCount(277),
      AppDatabase.migrationStepCount(278) + 1,
    );
  });

  test('the floor holds every pre-WebDAV build', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 278);
  });
}
