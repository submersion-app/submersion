import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/host_platform.dart';

/// The native facade must answer exactly as `dart:io` does, because the
/// sweep that routed every `Platform.` read through it promised no change
/// in behaviour.
void main() {
  test('is never the web on the VM', () {
    expect(HostPlatform.isWeb, isFalse);
  });

  test('every platform flag matches dart:io', () {
    expect(HostPlatform.isAndroid, Platform.isAndroid);
    expect(HostPlatform.isIOS, Platform.isIOS);
    expect(HostPlatform.isMacOS, Platform.isMacOS);
    expect(HostPlatform.isWindows, Platform.isWindows);
    expect(HostPlatform.isLinux, Platform.isLinux);
  });

  test('composed flags follow the platform flags', () {
    expect(HostPlatform.isApple, Platform.isIOS || Platform.isMacOS);
    expect(
      HostPlatform.isDesktop,
      Platform.isMacOS || Platform.isWindows || Platform.isLinux,
    );
    expect(HostPlatform.isMobile, Platform.isAndroid || Platform.isIOS);
  });

  test('environment and names match dart:io', () {
    expect(HostPlatform.environment, Platform.environment);
    expect(HostPlatform.localHostname, Platform.localHostname);
    expect(HostPlatform.operatingSystem, Platform.operatingSystem);
    expect(
      HostPlatform.operatingSystemVersion,
      Platform.operatingSystemVersion,
    );
    expect(HostPlatform.localeName, Platform.localeName);
    expect(HostPlatform.numberOfProcessors, Platform.numberOfProcessors);
    expect(HostPlatform.pathSeparator, Platform.pathSeparator);
    expect(HostPlatform.resolvedExecutable, Platform.resolvedExecutable);
  });
}
