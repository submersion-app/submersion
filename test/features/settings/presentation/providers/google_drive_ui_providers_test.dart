import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

void main() {
  test(
    'googleDriveAccountEmailProvider is null when Drive not selected',
    () async {
      final container = ProviderContainer(
        overrides: [
          selectedCloudProviderTypeProvider.overrideWith(
            (ref) => CloudProviderType.icloud,
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(googleDriveAccountEmailProvider.future),
        isNull,
      );
    },
  );

  test(
    'googleDriveAvailableProvider resolves without authentication',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Must not throw and must not require sign-in; the exact value is
      // platform-dependent (config-gated on Windows/Linux, true elsewhere).
      expect(
        await container.read(googleDriveAvailableProvider.future),
        isA<bool>(),
      );
    },
  );
}
