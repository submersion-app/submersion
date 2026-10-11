import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v280: no data change. It exists to carry the sync floor past every
/// build that cannot parse AccountKind.webdav (issue #2361).
void main() {
  test('v280 is in the ladder and is the current schema', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(280));
    expect(AppDatabase.migrationVersions, contains(280));
    expect(
      AppDatabase.migrationStepCount(279),
      AppDatabase.migrationStepCount(280) + 1,
    );
  });

  test('the floor holds every pre-WebDAV build', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 280);
  });
}
