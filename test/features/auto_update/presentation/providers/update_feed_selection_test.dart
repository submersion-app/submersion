import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/auto_update/data/services/github_update_service.dart';
import 'package:submersion/features/auto_update/data/services/sparkle_update_service.dart';
import 'package:submersion/features/auto_update/domain/entities/release_channel.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Builds a container whose preferences carry the given channel and reads
  /// the platform-appropriate update service out of it.
  Future<Object?> serviceFor(String? channel) async {
    SharedPreferences.setMockInitialValues({
      'update_release_channel': ?channel,
    });
    PackageInfo.setMockInitialValues(
      appName: 'Submersion',
      packageName: 'app.submersion',
      version: '1.7.2',
      buildNumber: '119',
      buildSignature: '',
      installerStore: null,
    );
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container.read(updateServiceProvider.future);
  }

  test('service provider builds the stable-feed service by default', () async {
    final service = await serviceFor(null);
    // The engine differs by host platform (Sparkle on macOS/Windows, GitHub
    // polling elsewhere); both must point at the stable channel.
    if (service is SparkleUpdateService) {
      expect(service.feedUrl, appcastUrlFor(ReleaseChannel.stable));
    } else {
      expect(
        (service as GithubUpdateService).repo,
        githubRepoFor(ReleaseChannel.stable),
      );
    }
  });

  test('service provider follows the beta channel preference', () async {
    final service = await serviceFor('beta');
    if (service is SparkleUpdateService) {
      expect(service.feedUrl, appcastUrlFor(ReleaseChannel.beta));
    } else {
      expect(
        (service as GithubUpdateService).repo,
        githubRepoFor(ReleaseChannel.beta),
      );
    }
  });
  test('stable channel uses the main repo appcast', () {
    expect(
      appcastUrlFor(ReleaseChannel.stable),
      'https://github.com/submersion-app/submersion/releases/latest/download/appcast.xml',
    );
    expect(githubRepoFor(ReleaseChannel.stable), 'submersion');
  });

  test('beta channel uses the beta-builds superset feed and repo', () {
    expect(
      appcastUrlFor(ReleaseChannel.beta),
      'https://github.com/submersion-app/beta-builds/releases/latest/download/appcast-beta.xml',
    );
    expect(githubRepoFor(ReleaseChannel.beta), 'beta-builds');
  });
}
