import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/auto_update/domain/entities/release_channel.dart';
import 'package:submersion/features/auto_update/domain/hosted_web_site.dart';
import 'package:submersion/features/auto_update/presentation/providers/hosted_web_site_provider.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';

/// Issue #4481: the beta web site always runs the newest beta, so anything
/// that advises by release channel (the newer-schema peer banner) treats it
/// as beta, though a browser keeps no channel of its own.
void main() {
  ReleaseChannel effective(HostedWebSite site, ReleaseChannel stored) {
    final container = ProviderContainer(
      overrides: [
        hostedWebSiteProvider.overrideWithValue(site),
        releaseChannelProvider.overrideWithValue(stored),
      ],
    );
    addTearDown(container.dispose);
    return container.read(effectiveReleaseChannelProvider);
  }

  test('the beta web site runs the beta channel', () {
    expect(
      effective(HostedWebSite.beta, ReleaseChannel.stable),
      ReleaseChannel.beta,
    );
  });

  test('anywhere else the stored channel stands', () {
    for (final stored in ReleaseChannel.values) {
      expect(effective(HostedWebSite.stable, stored), stored);
      expect(effective(HostedWebSite.none, stored), stored);
    }
  });
}
