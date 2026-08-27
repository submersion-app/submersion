import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/root_overrides.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('supplies both providers that would otherwise throw', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // Never initialized, so no directory is created; the override only has to
    // hand back the same instance.
    final logFileService = LogFileService(logDirectory: '/tmp/submersion-test');

    final container = ProviderContainer(
      overrides: rootProviderOverrides(
        prefs: prefs,
        logFileService: logFileService,
      ).cast(),
    );
    addTearDown(container.dispose);

    expect(container.read(sharedPreferencesProvider), same(prefs));
    expect(container.read(logFileServiceProvider), same(logFileService));
  });
}
