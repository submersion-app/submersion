import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

/// Media is read-only in a browser (issue #4121), and enrichment rows are
/// synced, so opening a dive there must not write any.
void main() {
  test('a browser enricher writes nothing and reads no database', () async {
    final container = ProviderContainer(
      overrides: [
        deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
      ],
    );
    addTearDown(container.dispose);

    // No database is open in this test: reaching a repository would throw.
    expect(
      await container
          .read(diveMediaEnricherProvider)
          .enrichMissingForDive('d1'),
      0,
    );
  });
}
