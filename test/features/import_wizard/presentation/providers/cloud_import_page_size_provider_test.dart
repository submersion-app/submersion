import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/import_wizard/domain/cloud_import_paging.dart';
import 'package:submersion/features/import_wizard/presentation/providers/cloud_import_page_size_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudImportPageSizeNotifier', () {
    test('defaults to 15 when nothing is stored', () {
      final notifier = CloudImportPageSizeNotifier();
      expect(notifier.state, CloudImportPaging.defaultPageSize);
    });

    test('reads a stored page size from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({CloudImportPaging.prefsKey: 7});
      final prefs = await SharedPreferences.getInstance();

      final notifier = CloudImportPageSizeNotifier(prefs: prefs);

      expect(notifier.state, 7);
    });

    test('setPageSize clamps and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = CloudImportPageSizeNotifier(prefs: prefs);

      await notifier.setPageSize(0);
      expect(notifier.state, CloudImportPaging.minPageSize);
      expect(prefs.getInt(CloudImportPaging.prefsKey), 1);

      await notifier.setPageSize(40);
      expect(notifier.state, 40);
      expect(prefs.getInt(CloudImportPaging.prefsKey), 40);
    });

    test('provider falls back to 15 when SharedPreferences is not wired', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(cloudImportPageSizeProvider),
        CloudImportPaging.defaultPageSize,
      );
    });

    test('provider reads the stored value when prefs are overridden', () async {
      SharedPreferences.setMockInitialValues({CloudImportPaging.prefsKey: 20});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(cloudImportPageSizeProvider), 20);
    });
  });
}
