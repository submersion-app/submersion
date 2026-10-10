import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system/windows_proxy_parser.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

/// Windows: WinHTTP over FFI, in the style of windows_root_store.dart.
///
/// Two steps, each in a short-lived isolate (they make no Dart HTTP request,
/// so no HttpOverrides is needed there): [readConfig] reads the user's proxy
/// settings, which is fast; only when they use auto-detection or a setup
/// script does [queryPac] ask WinHTTP for the probe URL's proxy, which can
/// block on WPAD discovery or a PAC download. A PAC query that outlasts
/// [timeout] keeps what the first step found, as Windows itself falls back
/// to the static proxy, so a slow auto-detect never discards it.
class WindowsSystemProxyResolver implements SystemProxyResolver {
  WindowsSystemProxyResolver({
    Future<RawWindowsProxy> Function()? readConfig,
    Future<RawWindowsProxy> Function(String url, RawWindowsProxy config)?
    queryPac,
    Duration timeout = const Duration(seconds: 5),
  }) : _readConfig = readConfig ?? (() => Isolate.run(readIeProxyConfig)),
       _queryPac =
           queryPac ??
           ((url, config) => Isolate.run(() => queryPacForUrl(url, config))),
       _timeout = timeout;

  final Future<RawWindowsProxy> Function() _readConfig;
  final Future<RawWindowsProxy> Function(String url, RawWindowsProxy config)
  _queryPac;
  final Duration _timeout;

  @override
  Future<SystemProxyResult> resolve(Uri probe) async {
    final RawWindowsProxy config;
    try {
      config = await _readConfig().timeout(_timeout);
    } catch (e) {
      return SystemProxyUnavailable(
        SystemProxyUnavailableReason.platformError,
        detail: '$e',
      );
    }
    if (autoProxyFlags(config) == 0) return parseWindowsProxy(config);
    RawWindowsProxy answered;
    try {
      answered = await _queryPac(probe.toString(), config).timeout(_timeout);
    } catch (_) {
      // Timed out or failed: what the settings say without the PAC answer.
      answered = RawWindowsProxy(
        autoDetect: config.autoDetect,
        autoConfigUrl: config.autoConfigUrl,
        staticProxy: config.staticProxy,
        staticBypass: config.staticBypass,
        pacAttempted: true,
      );
    }
    return parseWindowsProxy(answered);
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

const _configUrl = 0x2; // WINHTTP_AUTOPROXY_CONFIG_URL
const _detectDhcp = 0x1; // WINHTTP_AUTO_DETECT_TYPE_DHCP
const _detectDnsA = 0x2; // WINHTTP_AUTO_DETECT_TYPE_DNS_A
const _accessNoProxy = 1; // WINHTTP_ACCESS_TYPE_NO_PROXY
const _accessNamedProxy = 3; // WINHTTP_ACCESS_TYPE_NAMED_PROXY

/// The current user's WinHTTP proxy settings. Runs in a background isolate,
/// on Windows only.
// coverage:ignore-start
RawWindowsProxy readIeProxyConfig() {
  final f = _WinHttp.open();
  return using((arena) {
    final ie = arena<_IeProxyConfig>();
    if (f.getIeConfig(ie) == 0) {
      return const RawWindowsProxy(autoDetect: false);
    }
    return RawWindowsProxy(
      autoDetect: ie.ref.fAutoDetect != 0,
      autoConfigUrl: f.take(ie.ref.lpszAutoConfigUrl),
      staticProxy: f.take(ie.ref.lpszProxy),
      staticBypass: f.take(ie.ref.lpszProxyBypass),
    );
  });
}

/// [config] completed with WinHTTP's auto-detect or setup-script answer for
/// [url]. Runs in a background isolate, on Windows only.
RawWindowsProxy queryPacForUrl(String url, RawWindowsProxy config) {
  final f = _WinHttp.open();
  final flags = autoProxyFlags(config);
  final configUrl = flags & _configUrl != 0 ? config.autoConfigUrl : null;
  RawWindowsProxy result({bool ok = false, String? proxy, String? bypass}) =>
      RawWindowsProxy(
        autoDetect: config.autoDetect,
        autoConfigUrl: configUrl,
        staticProxy: config.staticProxy,
        staticBypass: config.staticBypass,
        pacAttempted: true,
        pacSucceeded: ok,
        pacProxy: proxy,
        pacBypass: bypass,
      );
  return using((arena) {
    final session = f.open(
      'Submersion'.toNativeUtf16(allocator: arena),
      _accessNoProxy,
      nullptr,
      nullptr,
      0,
    );
    if (session == nullptr) return result();
    try {
      final options = arena<_AutoProxyOptions>();
      options.ref
        ..dwFlags = flags
        ..dwAutoDetectFlags = config.autoDetect
            ? (_detectDhcp | _detectDnsA)
            : 0
        ..lpszAutoConfigUrl = configUrl == null
            ? nullptr
            : configUrl.toNativeUtf16(allocator: arena)
        ..lpvReserved = nullptr
        ..dwReserved = 0
        ..fAutoLogonIfChallenged = 1;
      final info = arena<_ProxyInfo>();
      final ok =
          f.getProxyForUrl(
            session,
            url.toNativeUtf16(allocator: arena),
            options,
            info,
          ) !=
          0;
      if (!ok) return result();
      final proxy = f.take(info.ref.lpszProxy);
      final bypass = f.take(info.ref.lpszProxyBypass);
      return result(
        ok: true,
        proxy: info.ref.dwAccessType == _accessNamedProxy ? proxy : null,
        bypass: bypass,
      );
    } finally {
      f.closeHandle(session);
    }
  });
}

/// The WinHTTP and kernel32 entry points the two queries use.
class _WinHttp {
  _WinHttp._(DynamicLibrary winhttp, DynamicLibrary kernel32)
    : getIeConfig = winhttp
          .lookupFunction<
            Int32 Function(Pointer<_IeProxyConfig>),
            int Function(Pointer<_IeProxyConfig>)
          >('WinHttpGetIEProxyConfigForCurrentUser'),
      open = winhttp
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
          >('WinHttpOpen'),
      getProxyForUrl = winhttp
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
          >('WinHttpGetProxyForUrl'),
      closeHandle = winhttp
          .lookupFunction<
            Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('WinHttpCloseHandle'),
      _globalFree = kernel32
          .lookupFunction<
            Pointer<Void> Function(Pointer<Void>),
            Pointer<Void> Function(Pointer<Void>)
          >('GlobalFree');

  factory _WinHttp.open() => _WinHttp._(
    DynamicLibrary.open('winhttp.dll'),
    DynamicLibrary.open('kernel32.dll'),
  );

  final int Function(Pointer<_IeProxyConfig>) getIeConfig;
  final Pointer<Void> Function(
    Pointer<Utf16>,
    int,
    Pointer<Utf16>,
    Pointer<Utf16>,
    int,
  )
  open;
  final int Function(
    Pointer<Void>,
    Pointer<Utf16>,
    Pointer<_AutoProxyOptions>,
    Pointer<_ProxyInfo>,
  )
  getProxyForUrl;
  final int Function(Pointer<Void>) closeHandle;
  final Pointer<Void> Function(Pointer<Void>) _globalFree;

  /// Copies a WinHTTP string and frees it: WinHTTP allocates every string
  /// it returns with GlobalAlloc.
  String? take(Pointer<Utf16> p) {
    if (p == nullptr) return null;
    final s = p.toDartString();
    _globalFree(p.cast());
    return s;
  }
}

// coverage:ignore-end
