import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/hidden_built_ins_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  ProviderContainer container(MockSettingsNotifier settings) {
    final c = ProviderContainer(
      overrides: [settingsProvider.overrideWith((ref) => settings)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('yields only its own catalog', () {
    final c = container(
      MockSettingsNotifier(
        const AppSettings(
          hiddenBuiltInIds: {
            'diveRoles': {'solo'},
            'siteTypes': {'lake'},
          },
        ),
      ),
    );
    expect(c.read(hiddenBuiltInIdsProvider(BuiltInCatalog.diveRoles)), {
      'solo',
    });
    expect(c.read(hiddenBuiltInIdsProvider(BuiltInCatalog.diveTypes)), isEmpty);
  });

  test('another catalog changing does not notify listeners', () async {
    final settings = MockSettingsNotifier();
    final c = container(settings);
    var notified = 0;
    c.listen(
      hiddenBuiltInIdsProvider(BuiltInCatalog.diveRoles),
      (_, _) => notified++,
    );

    await settings.setBuiltInHidden(BuiltInCatalog.siteTypes, 'lake', true);
    // Riverpod rebuilds dependents lazily; a read flushes any pending one.
    expect(c.read(hiddenBuiltInIdsProvider(BuiltInCatalog.diveRoles)), isEmpty);
    expect(notified, 0);

    await settings.setBuiltInHidden(BuiltInCatalog.diveRoles, 'solo', true);
    expect(c.read(hiddenBuiltInIdsProvider(BuiltInCatalog.diveRoles)), {
      'solo',
    });
    expect(notified, 1);
  });
}
