import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/settings/presentation/providers/web_forget_device_provider.dart';

/// Forget this device promises everything the browser keeps, so every
/// database the app opens in a browser is on its list (issue #4121).
void main() {
  test('both browser databases are forgotten', () {
    expect(
      kWebForgottenDatabasePaths,
      containsAll([kWebDatabasePath, kWebLocalCacheDatabasePath]),
    );
  });
}
