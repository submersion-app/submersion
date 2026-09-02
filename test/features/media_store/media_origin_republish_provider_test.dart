import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media_store/data/media_origin_republish_sweep.dart';
import 'package:submersion/features/media_store/presentation/providers/media_origin_republish_provider.dart';

void main() {
  // Building the resolver registry constructs every resolver in the app.
  // That is fine once, on the launch that does the repair, and wasteful on
  // every launch after, so the flag is checked before the registry is read.
  test('a finished repair never builds the resolver registry', () async {
    SharedPreferences.setMockInitialValues({
      MediaOriginRepublishSweep.doneFlagKey: true,
    });
    final container = ProviderContainer(
      overrides: [
        mediaSourceResolverRegistryProvider.overrideWith(
          (ref) => throw StateError('registry must not be built'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(mediaOriginRepublishProvider)(),
      completes,
    );
  });

  // The call site is fire-and-forget at launch, so an escaping throw would
  // land in the zone handler with nothing to catch it.
  test('contains its failures and leaves the flag unset', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        mediaSourceResolverRegistryProvider.overrideWith(
          (ref) => MediaSourceResolverRegistry(const {}),
        ),
      ],
    );
    addTearDown(container.dispose);

    // No database is initialized here, so the device id read throws.
    await expectLater(
      container.read(mediaOriginRepublishProvider)(),
      completes,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(MediaOriginRepublishSweep.doneFlagKey), isNull);
  });
}
