import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system/windows_proxy_parser.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

/// Windows: WinHTTP over FFI, in the style of windows_root_store.dart.
///
/// WinHttpGetProxyForUrl blocks (WPAD lookups, PAC download and evaluation),
/// so the query runs in a short-lived isolate with a Dart-side deadline. It
/// makes no Dart HTTP request, so the isolate needs no HttpOverrides.
class WindowsSystemProxyResolver implements SystemProxyResolver {
  WindowsSystemProxyResolver({
    Future<RawWindowsProxy> Function(String url)? query,
    Duration timeout = const Duration(seconds: 5),
  }) : _query = query ?? ((url) => Isolate.run(() => queryWinHttp(url))),
       _timeout = timeout;

  final Future<RawWindowsProxy> Function(String url) _query;
  final Duration _timeout;

  @override
  Future<SystemProxyResult> resolve(Uri probe) async {
    try {
      final raw = await _query(probe.toString()).timeout(_timeout);
      return parseWindowsProxy(raw);
    } on TimeoutException {
      return const SystemProxyUnavailable(
        SystemProxyUnavailableReason.pacFailed,
        detail: 'Timed out waiting for automatic proxy configuration',
      );
    } catch (e) {
      return SystemProxyUnavailable(
        SystemProxyUnavailableReason.platformError,
        detail: '$e',
      );
    }
  }
}

// WINHTTP_CURRENT_USER_IE_PROXY_CONFIG
final class _IeProxyConfig extends Struct {
  @Int32()
  external int fAutoDetect;
  external Pointer<Utf16> lpszAutoConfigUrl;
  external Pointer<Utf16> lpszProxy;
  external Pointer<Utf16> lpszProxyBypass;
}

// WINHTTP_AUTOPROXY_OPTIONS
final class _AutoProxyOptions extends Struct {
  @Uint32()
  external int dwFlags;
  @Uint32()
  external int dwAutoDetectFlags;
  external Pointer<Utf16> lpszAutoConfigUrl;
  external Pointer<Void> lpvReserved;
  @Uint32()
  external int dwReserved;
  @Int32()
  external int fAutoLogonIfChallenged;
}

// WINHTTP_PROXY_INFO
final class _ProxyInfo extends Struct {
  @Uint32()
  external int dwAccessType;
  external Pointer<Utf16> lpszProxy;
  external Pointer<Utf16> lpszProxyBypass;
}

const _autoDetect = 0x1; // WINHTTP_AUTOPROXY_AUTO_DETECT
const _configUrl = 0x2; // WINHTTP_AUTOPROXY_CONFIG_URL
const _detectDhcp = 0x1; // WINHTTP_AUTO_DETECT_TYPE_DHCP
const _detectDnsA = 0x2; // WINHTTP_AUTO_DETECT_TYPE_DNS_A
const _accessNoProxy = 1; // WINHTTP_ACCESS_TYPE_NO_PROXY
const _accessNamedProxy = 3; // WINHTTP_ACCESS_TYPE_NAMED_PROXY

/// Asks WinHTTP for the current user's proxy settings and, when they use
/// auto-detection or a setup script, for the proxy it would use for [url].
/// Runs in a background isolate, on Windows only.
// coverage:ignore-start
RawWindowsProxy queryWinHttp(String url) {
  final winhttp = DynamicLibrary.open('winhttp.dll');
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final getIeConfig = winhttp
      .lookupFunction<
        Int32 Function(Pointer<_IeProxyConfig>),
        int Function(Pointer<_IeProxyConfig>)
      >('WinHttpGetIEProxyConfigForCurrentUser');
  final open = winhttp
      .lookupFunction<
        Pointer<Void> Function(
          Pointer<Utf16>,
          Uint32,
          Pointer<Utf16>,
          Pointer<Utf16>,
          Uint32,
        ),
        Pointer<Void> Function(
          Pointer<Utf16>,
          int,
          Pointer<Utf16>,
          Pointer<Utf16>,
          int,
        )
      >('WinHttpOpen');
  final getProxyForUrl = winhttp
      .lookupFunction<
        Int32 Function(
          Pointer<Void>,
          Pointer<Utf16>,
          Pointer<_AutoProxyOptions>,
          Pointer<_ProxyInfo>,
        ),
        int Function(
          Pointer<Void>,
          Pointer<Utf16>,
          Pointer<_AutoProxyOptions>,
          Pointer<_ProxyInfo>,
        )
      >('WinHttpGetProxyForUrl');
  final closeHandle = winhttp
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('WinHttpCloseHandle');
  final globalFree = kernel32
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>)
      >('GlobalFree');

  // WinHTTP allocates every returned string with GlobalAlloc.
  String? take(Pointer<Utf16> p) {
    if (p == nullptr) return null;
    final s = p.toDartString();
    globalFree(p.cast());
    return s;
  }

  return using((arena) {
    final ie = arena<_IeProxyConfig>();
    if (getIeConfig(ie) == 0) {
      return const RawWindowsProxy(autoDetect: false);
    }
    final autoDetect = ie.ref.fAutoDetect != 0;
    final configUrl = take(ie.ref.lpszAutoConfigUrl);
    final staticProxy = take(ie.ref.lpszProxy);
    final staticBypass = take(ie.ref.lpszProxyBypass);
    if (!autoDetect && configUrl == null) {
      return RawWindowsProxy(
        autoDetect: false,
        staticProxy: staticProxy,
        staticBypass: staticBypass,
      );
    }
    final session = open(
      'Submersion'.toNativeUtf16(allocator: arena),
      _accessNoProxy,
      nullptr,
      nullptr,
      0,
    );
    if (session == nullptr) {
      return RawWindowsProxy(
        autoDetect: autoDetect,
        autoConfigUrl: configUrl,
        staticProxy: staticProxy,
        staticBypass: staticBypass,
        pacAttempted: true,
      );
    }
    try {
      final options = arena<_AutoProxyOptions>();
      options.ref
        ..dwFlags =
            (autoDetect ? _autoDetect : 0) |
            (configUrl != null ? _configUrl : 0)
        ..dwAutoDetectFlags = autoDetect ? (_detectDhcp | _detectDnsA) : 0
        ..lpszAutoConfigUrl = configUrl == null
            ? nullptr
            : configUrl.toNativeUtf16(allocator: arena)
        ..lpvReserved = nullptr
        ..dwReserved = 0
        ..fAutoLogonIfChallenged = 1;
      final info = arena<_ProxyInfo>();
      final ok =
          getProxyForUrl(
            session,
            url.toNativeUtf16(allocator: arena),
            options,
            info,
          ) !=
          0;
      final pacProxy = ok ? take(info.ref.lpszProxy) : null;
      final pacBypass = ok ? take(info.ref.lpszProxyBypass) : null;
      return RawWindowsProxy(
        autoDetect: autoDetect,
        autoConfigUrl: configUrl,
        staticProxy: staticProxy,
        staticBypass: staticBypass,
        pacAttempted: true,
        pacSucceeded: ok,
        pacProxy: ok && info.ref.dwAccessType == _accessNamedProxy
            ? pacProxy
            : null,
        pacBypass: pacBypass,
      );
    } finally {
      closeHandle(session);
    }
  });
}

// coverage:ignore-end
