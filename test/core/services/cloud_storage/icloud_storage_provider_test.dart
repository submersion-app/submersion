import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_storage_provider.dart';

/// Routes getApplicationDocumentsDirectory to a temp dir, so that if the
/// provider ever tries to substitute local storage for the iCloud container the
/// attempt succeeds and the test can catch it.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('icloud_provider_test');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPathProvider;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // The container lookup is injected rather than mocked at the method channel:
  // ICloudNativeService.getContainerPath carries its own platform guard and
  // returns null without touching the channel on a non-Apple host, so a mocked
  // channel would go unconsulted on the Linux CI runner.
  ICloudStorageProvider providerWithContainer(
    String? containerPath, {
    ICloudHostPlatform platform = ICloudHostPlatform.ios,
  }) {
    return ICloudStorageProvider(
      platform: platform,
      containerPathLookup: () async => containerPath,
    );
  }

  group('ICloudStorageProvider with no reachable ubiquity container', () {
    // The native lookup returns null whenever iCloud cannot serve this app:
    // no iCloud account signed in, or a build without the ubiquity
    // entitlement. The iOS Simulator is permanently in this state.

    test(
      'reports unavailable on iOS instead of substituting local storage',
      () async {
        expect(await providerWithContainer(null).isAvailable(), isFalse);
      },
    );

    test('leaves no local stand-in directory behind on iOS', () async {
      await providerWithContainer(null).isAvailable();

      expect(
        Directory(p.join(tempDir.path, 'iCloud')).existsSync(),
        isFalse,
        reason:
            'a local Documents/iCloud folder is not iCloud; syncing into it '
            'strands data where no other device can ever see it',
      );
    });

    test('authenticate throws on iOS rather than reporting success', () async {
      await expectLater(
        providerWithContainer(null).authenticate(),
        throwsA(isA<CloudStorageException>()),
      );
    });

    test('reports unavailable on macOS', () async {
      final provider = providerWithContainer(
        null,
        platform: ICloudHostPlatform.macos,
      );

      expect(await provider.isAvailable(), isFalse);
    });

    test('reports unavailable on non-Apple platforms', () async {
      final provider = providerWithContainer(
        null,
        platform: ICloudHostPlatform.other,
      );

      expect(await provider.isAvailable(), isFalse);
    });
  });

  group('ICloudStorageProvider with a reachable ubiquity container', () {
    // Control: proves the injected lookup is genuinely wired into
    // _getICloudContainer. Without it, a provider that ignored the lookup and
    // always returned null would satisfy every unavailability test above.
    test('reports available when the container resolves', () async {
      final container = Directory(p.join(tempDir.path, 'container'))
        ..createSync();

      final provider = providerWithContainer(container.path);

      expect(await provider.isAvailable(), isTrue);
    });

    test('authenticate succeeds when the container resolves', () async {
      final container = Directory(p.join(tempDir.path, 'container'))
        ..createSync();

      await expectLater(
        providerWithContainer(container.path).authenticate(),
        completes,
      );
    });

    test(
      'creates the container directory when it does not yet exist',
      () async {
        final container = p.join(tempDir.path, 'not-yet-there');

        expect(await providerWithContainer(container).isAvailable(), isTrue);
        expect(Directory(container).existsSync(), isTrue);
      },
    );
  });

  group('ICloudHostPlatform', () {
    test('treats both Apple platforms as Apple', () {
      expect(ICloudHostPlatform.ios.isApple, isTrue);
      expect(ICloudHostPlatform.macos.isApple, isTrue);
      expect(ICloudHostPlatform.other.isApple, isFalse);
    });

    test(
      'current() reports macos on a macOS host',
      () => expect(ICloudHostPlatform.current(), ICloudHostPlatform.macos),
      skip: !Platform.isMacOS,
    );

    test(
      'current() reports other on a non-Apple host',
      () => expect(ICloudHostPlatform.current(), ICloudHostPlatform.other),
      skip: Platform.isMacOS || Platform.isIOS,
    );
  });
}
