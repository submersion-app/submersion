import 'dart:io';

import 'package:submersion/core/network/proxy/system/channel_system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system/linux_system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system/windows_system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

/// The URL system detection and the connection test ask about: the update
/// check's host, a public name any network the app works on must reach. A
/// PAC script's answer for it is applied to all internet traffic.
final Uri proxyProbeUrl = Uri.parse('https://api.github.com/');

/// Asks the operating system which proxy to use for a URL.
abstract class SystemProxyResolver {
  /// Never throws; failures come back as SystemProxyUnavailable.
  Future<SystemProxyResult> resolve(Uri probe);

  /// The resolver for the platform this process runs on.
  static SystemProxyResolver forPlatform() {
    if (Platform.isWindows) return WindowsSystemProxyResolver();
    if (Platform.isLinux) return LinuxSystemProxyResolver();
    return ChannelSystemProxyResolver();
  }
}
