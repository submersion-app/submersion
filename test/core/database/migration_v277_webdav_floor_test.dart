import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v277: no data change. It exists to carry the sync floor past every
/// build that cannot parse AccountKind.webdav (issue #2361).
void main() {
  test('v277 is in the ladder and is the current schema', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(277));
    expect(AppDatabase.migrationVersions, contains(277));
    expect(
      AppDatabase.migrationStepCount(276),
      AppDatabase.migrationStepCount(277) + 1,
    );
  });

  test('the floor holds every pre-WebDAV build', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 277);
  });
}
