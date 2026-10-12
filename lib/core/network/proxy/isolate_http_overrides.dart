import 'dart:io';

import 'package:submersion/core/network/app_security_context.dart';
import 'package:submersion/core/network/proxy/app_http_overrides.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';

/// The proxy the app's overrides route by right now, to hand to a background
/// isolate with [ensureIsolateHttpOverrides]. Direct when the overrides are
/// not the app's (before main installs them, and in tests).
EffectiveProxy currentAppProxy() {
  final overrides = HttpOverrides.current;
  return overrides is AppHttpOverrides
      ? overrides.currentProxy
      : const EffectiveProxy.direct();
}

/// Gives a background isolate the app's network setup, routed by [proxy].
///
/// [HttpOverrides.global] is a per-isolate static, so an isolate the app
/// spawns, or a package spawns for it, starts with none: no Windows trust,
/// no proxy. Call this from the first app code that runs in such an isolate.
/// It does nothing in an isolate that already has overrides, the app's main
/// isolate included, so a second call keeps the first [proxy].
///
/// Clients built from here on get the full [AppHttpOverrides], SOCKS5
/// included. A client built before this call still reaches the app's proxy
/// settings through [AppHttpOverrides.findProxyFromEnvironment], except for
/// SOCKS5, which it cannot use and is refused, and the Windows trust is
/// added to the default context it connects with.
///
/// [proxy] is a snapshot: the isolate cannot see later settings changes.
void ensureIsolateHttpOverrides(EffectiveProxy proxy) {
  if (HttpOverrides.current != null) return;
  trustAppRootsInDefaultContext();
  // The default context now holds the app's trust, so clients built here
  // with no context of their own use it rather than a second copy.
  HttpOverrides.global = AppHttpOverrides(
    currentProxy: () => proxy,
    fallbackContext: () => null,
  );
}
