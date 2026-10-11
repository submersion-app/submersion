# Network Proxy Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route every Dart HTTP request through the OS proxy (default), a manual HTTP or SOCKS5 proxy, or no proxy, chosen on a new Settings > Network page.

**Architecture:** One `AppHttpOverrides` installed as `HttpOverrides.global` on every platform sets `findProxy` and `connectionFactory` on each `HttpClient`; both read an immutable `EffectiveProxy` snapshot held by a process-wide `ProxyController` at connection time. The controller combines persisted `ProxySettings` with a per-platform `SystemProxyResolver` (CFNetwork via a method channel on Apple, `ConnectivityManager` on Android, WinHTTP over FFI on Windows, environment and gsettings on Linux).

**Tech Stack:** Dart `dart:io` (`HttpOverrides`, `HttpClient.connectionFactory`, `Socket`, `SecureSocket`), `dart:ffi` + `package:ffi`, Riverpod (repo's `core/providers/provider.dart`), SharedPreferences, `flutter_secure_storage` via `FallbackSecureStorage`, `connectivity_plus`, Swift (CFNetwork), Kotlin.

**Spec:** `docs/design/specs/2026-10-10-network-proxy-design.md` (issue #3217)

## Global Constraints

- Modes: `system` (default), `manual`, `none`. Manual types: `http`, `socks5`.
- Proxy settings are device-local (SharedPreferences), never synced. The password lives only in secure storage under `network_proxy_password`.
- Always direct: `localhost`, `*.local`, 127.0.0.0/8, ::1, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16, fc00::/7, fe80::/10.
- Probe URL for system detection and Test: `https://api.github.com/`.
- Startup waits at most 3 seconds for system detection; PAC evaluation is capped at 5 seconds natively; Test times out after 10 seconds.
- Never log the username or password; log each snapshot change (mode, source, host:port) only.
- Tests touch loopback only, never `HttpOverrides.global`; anything a test changes globally (method channel mocks) is restored in `addTearDown`.
- No em dashes, no en dashes as punctuation, in code, comments, strings, commits.
- Files stay under 800 lines; new code under `lib/core/network/proxy/` and `lib/features/settings/presentation/`.
- Every new user-facing string is an ARB key translated into all 10 locale ARBs; `flutter gen-l10n` runs LAST (Task 14).
- Commit messages: `feat(network): ...`, no attribution trailers.

### Discovered constraint (amends the spec's `authenticateProxy` line)

`dart:io` sends proxy credentials for HTTPS (`CONNECT`) tunnels only when they are embedded in the `findProxy` directive (`PROXY user:pass@host:port`, Basic, sent up front), and never calls `authenticateProxy` for a tunnel. Its parser splits the directive on `;`, trims both values, takes the username up to the first `:`, and rejects an empty password. So:

- `AppHttpOverrides` embeds credentials in the directive and does not use `authenticateProxy`.
- The manual form rejects, for HTTP proxies: a username with `:`, a password with `;`, a password with leading or trailing whitespace, and a username without a password. For SOCKS5 (RFC 1929): username or password over 255 UTF-8 bytes, and a username without a password.

The spec's Architecture section is updated in Task 1 to say this.

## Review Focus

- A password containing `@` or `:` (common in generated passwords) must authenticate; the directive parser takes the LAST `@`. Test in Task 5.
- An IPv6 literal target (`https://[2001:db8::1]/`) through SOCKS5 must use address type 4, and an IPv4 literal type 1, never a domain-name record. Test in Task 4.
- Windows with "Automatically detect settings" on and no WPAD server (the default on home PCs) must resolve to "no proxy", not an error banner. Test in Task 6.
- A slow PAC result arriving after the user switched to No proxy must not overwrite the newer snapshot. Test in Task 9.
- Prefs written by a newer app version (an unknown mode or type string, a port out of range) must load as safe defaults, not throw at startup. Test in Task 3.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/core/network/proxy/proxy_settings.dart` | `ProxyMode`, `ProxyType`, `ProxySettings` |
| `lib/core/network/proxy/proxy_credentials.dart` | `ProxyCredentialsProblem`, `checkProxyCredentials` |
| `lib/core/network/proxy/system_proxy_result.dart` | `SystemProxyResult` sealed family |
| `lib/core/network/proxy/effective_proxy.dart` | `ProxyKind`, `ProxySource`, `EffectiveProxy`, `EffectiveProxy.resolve` |
| `lib/core/network/proxy/proxy_routing.dart` | always-direct hosts, bypass matching, `defaultShouldProxy` |
| `lib/core/network/proxy/proxy_settings_store.dart` | prefs + secure storage persistence |
| `lib/core/network/proxy/socks5_connector.dart` | RFC 1928/1929 client, `Socks5Exception` |
| `lib/core/network/proxy/app_http_overrides.dart` | `AppHttpOverrides`, `proxyDirective` |
| `lib/core/network/proxy/system/system_proxy_resolver.dart` | interface, `proxyProbeUrl`, `forPlatform()` |
| `lib/core/network/proxy/system/channel_system_proxy_resolver.dart` | Apple and Android channel client + map parser |
| `lib/core/network/proxy/system/windows_proxy_parser.dart` | pure WinHTTP result parsing |
| `lib/core/network/proxy/system/windows_system_proxy_resolver.dart` | WinHTTP FFI |
| `lib/core/network/proxy/system/linux_proxy_parser.dart` | pure env and gsettings parsing |
| `lib/core/network/proxy/system/linux_system_proxy_resolver.dart` | env + `gsettings` process |
| `lib/core/network/proxy/proxy_controller.dart` | `ProxyControllerState`, `ProxyController` |
| `lib/core/network/proxy/proxy_refresh_triggers.dart` | resume + connectivity refresh wiring |
| `lib/core/network/proxy/proxy_connection_tester.dart` | Test request and outcome classification |
| `lib/features/settings/presentation/providers/network_proxy_providers.dart` | Riverpod providers + draft notifier |
| `lib/features/settings/presentation/pages/network_settings_page.dart` | the page |
| `lib/features/settings/presentation/widgets/network/proxy_mode_selector.dart` | radio tiles |
| `lib/features/settings/presentation/widgets/network/proxy_status_line.dart` | detected proxy line |
| `lib/features/settings/presentation/widgets/network/proxy_manual_form.dart` | manual fields + Save |
| `lib/features/settings/presentation/widgets/network/proxy_test_section.dart` | Test button + outcome text |
| `macos/Runner/SystemProxyHandler.swift`, `ios/Runner/SystemProxyHandler.swift` | CFNetwork detection |
| `android/app/src/main/kotlin/app/submersion/SystemProxyHandler.kt` | Android detection |
| `test/helpers/fake_socks5_server.dart`, `test/helpers/fake_http_proxy.dart`, `test/helpers/recording_tcp_server.dart` | loopback fakes |

Deleted: `lib/core/network/trusted_http_overrides.dart` and its test (folded into `AppHttpOverrides`).

---

### Task 1: Settings, credentials and system-result models

**Files:**
- Create: `lib/core/network/proxy/proxy_settings.dart`, `lib/core/network/proxy/proxy_credentials.dart`, `lib/core/network/proxy/system_proxy_result.dart`
- Modify: `docs/design/specs/2026-10-10-network-proxy-design.md` (Architecture: replace the `authenticateProxy` bullet)
- Test: `test/core/network/proxy/proxy_settings_test.dart`, `test/core/network/proxy/proxy_credentials_test.dart`

**Interfaces:**
- Produces: `enum ProxyMode { system, manual, none }`, `enum ProxyType { http, socks5 }`, `ProxySettings({mode, type, host, port, username})` with `ProxySettings.defaults`, `copyWith`, `==`; `ProxyCredentialsProblem? checkProxyCredentials(ProxyType type, String username, String password)`; `sealed class SystemProxyResult` with `SystemProxyNone`, `SystemProxyFixed({type, host, port, bypass, viaPac, username, password})`, `SystemProxyUnavailable(reason, {detail})`, `enum SystemProxyUnavailableReason { pacUnsupported, pacFailed, platformError }`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/network/proxy/proxy_settings_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';

void main() {
  test('defaults are system mode with no manual proxy', () {
    const s = ProxySettings.defaults;
    expect(s.mode, ProxyMode.system);
    expect(s.type, ProxyType.http);
    expect(s.host, '');
    expect(s.port, isNull);
    expect(s.username, '');
    expect(s.hasManualProxy, isFalse);
  });

  test('hasManualProxy needs a host and a port in range', () {
    const base = ProxySettings.defaults;
    expect(base.copyWith(host: 'p', port: 8080).hasManualProxy, isTrue);
    expect(base.copyWith(host: ' ', port: 8080).hasManualProxy, isFalse);
    expect(base.copyWith(host: 'p', port: 0).hasManualProxy, isFalse);
    expect(base.copyWith(host: 'p', port: 65536).hasManualProxy, isFalse);
  });

  test('copyWith can clear the port and compares by value', () {
    final a = ProxySettings.defaults.copyWith(host: 'p', port: 1);
    expect(a.copyWith(clearPort: true).port, isNull);
    expect(a, ProxySettings.defaults.copyWith(host: 'p', port: 1));
    expect(a.hashCode, ProxySettings.defaults.copyWith(host: 'p', port: 1).hashCode);
  });
}
```

```dart
// test/core/network/proxy/proxy_credentials_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_credentials.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';

void main() {
  group('http', () {
    ProxyCredentialsProblem? check(String u, String p) =>
        checkProxyCredentials(ProxyType.http, u, p);

    test('no credentials is fine', () => expect(check('', ''), isNull));
    test('ordinary pair is fine', () => expect(check('ann', 's3cr:t@x'), isNull));
    test('username needs a password', () {
      expect(check('ann', ''), ProxyCredentialsProblem.passwordRequired);
    });
    test('password without username is ignored', () => expect(check('', 'x'), isNull));
    test('username colon', () {
      expect(check('a:b', 'x'), ProxyCredentialsProblem.usernameHasColon);
    });
    test('password semicolon', () {
      expect(check('a', 'x;y'), ProxyCredentialsProblem.passwordHasSemicolon);
    });
    test('password edge whitespace', () {
      expect(check('a', ' x'), ProxyCredentialsProblem.passwordHasEdgeWhitespace);
      expect(check('a', 'x '), ProxyCredentialsProblem.passwordHasEdgeWhitespace);
    });
  });

  group('socks5', () {
    ProxyCredentialsProblem? check(String u, String p) =>
        checkProxyCredentials(ProxyType.socks5, u, p);

    test('colon and semicolon are fine', () => expect(check('a:b', 'x;y'), isNull));
    test('username needs a password', () {
      expect(check('a', ''), ProxyCredentialsProblem.passwordRequired);
    });
    test('255 UTF-8 bytes is the limit', () {
      expect(check('a' * 255, 'x'), isNull);
      expect(check('a' * 256, 'x'), ProxyCredentialsProblem.tooLong);
      expect(check('a', '\u00e9' * 128), ProxyCredentialsProblem.tooLong);
    });
  });
}
```


- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/network/proxy/proxy_settings_test.dart test/core/network/proxy/proxy_credentials_test.dart`
Expected: FAIL, the library files do not exist.

- [ ] **Step 3: Implement**

```dart
// lib/core/network/proxy/proxy_settings.dart
import 'package:flutter/foundation.dart';

/// How the app chooses a proxy for its own HTTP traffic.
enum ProxyMode { system, manual, none }

/// The protocol of a manual proxy.
enum ProxyType { http, socks5 }

/// The persisted proxy choice for this device.
///
/// Device-local: a proxy belongs to a device and the network it is on, not to
/// a diver, so this never syncs. The manual password is not here; it lives in
/// secure storage (ProxySettingsStore).
@immutable
class ProxySettings {
  const ProxySettings({
    required this.mode,
    required this.type,
    required this.host,
    required this.port,
    required this.username,
  });

  static const defaults = ProxySettings(
    mode: ProxyMode.system,
    type: ProxyType.http,
    host: '',
    port: null,
    username: '',
  );

  final ProxyMode mode;
  final ProxyType type;
  final String host;
  final int? port;
  final String username;

  /// Whether the manual fields describe a usable proxy.
  bool get hasManualProxy {
    final p = port;
    return host.trim().isNotEmpty && p != null && p >= 1 && p <= 65535;
  }

  ProxySettings copyWith({
    ProxyMode? mode,
    ProxyType? type,
    String? host,
    int? port,
    bool clearPort = false,
    String? username,
  }) => ProxySettings(
    mode: mode ?? this.mode,
    type: type ?? this.type,
    host: host ?? this.host,
    port: clearPort ? null : (port ?? this.port),
    username: username ?? this.username,
  );

  @override
  bool operator ==(Object other) =>
      other is ProxySettings &&
      other.mode == mode &&
      other.type == type &&
      other.host == host &&
      other.port == port &&
      other.username == username;

  @override
  int get hashCode => Object.hash(mode, type, host, port, username);
}
```

```dart
// lib/core/network/proxy/proxy_credentials.dart
import 'dart:convert';

import 'package:submersion/core/network/proxy/proxy_settings.dart';

/// Why a manual username and password cannot be used as entered.
enum ProxyCredentialsProblem {
  passwordRequired,
  usernameHasColon,
  passwordHasSemicolon,
  passwordHasEdgeWhitespace,
  tooLong,
}

/// Checks a manual username and password against what the transport can send.
///
/// HTTP credentials travel inside the dart:io proxy directive
/// (`PROXY user:pass@host:port`), the only way dart:io authenticates a CONNECT
/// tunnel. Its parser splits on `;`, trims both values, ends the username at
/// the first `:` and rejects an empty password. SOCKS5 (RFC 1929) allows any
/// bytes but at most 255 of each, and no empty password.
///
/// Returns null when the pair is usable, or when there is no username.
ProxyCredentialsProblem? checkProxyCredentials(
  ProxyType type,
  String username,
  String password,
) {
  if (username.isEmpty) return null;
  if (password.isEmpty) return ProxyCredentialsProblem.passwordRequired;
  switch (type) {
    case ProxyType.http:
      if (username.contains(':')) return ProxyCredentialsProblem.usernameHasColon;
      if (password.contains(';')) {
        return ProxyCredentialsProblem.passwordHasSemicolon;
      }
      if (password.trim() != password) {
        return ProxyCredentialsProblem.passwordHasEdgeWhitespace;
      }
      return null;
    case ProxyType.socks5:
      if (utf8.encode(username).length > 255 ||
          utf8.encode(password).length > 255) {
        return ProxyCredentialsProblem.tooLong;
      }
      return null;
  }
}
```

```dart
// lib/core/network/proxy/system_proxy_result.dart
import 'package:flutter/foundation.dart';

import 'package:submersion/core/network/proxy/proxy_settings.dart';

/// What the operating system says the app should use for internet traffic.
sealed class SystemProxyResult {
  const SystemProxyResult();
}

/// The OS goes direct.
class SystemProxyNone extends SystemProxyResult {
  const SystemProxyNone();

  @override
  bool operator ==(Object other) => other is SystemProxyNone;

  @override
  int get hashCode => 0;
}

/// The OS names one proxy, either configured outright or chosen by a PAC
/// script for the probe URL ([viaPac]).
@immutable
class SystemProxyFixed extends SystemProxyResult {
  const SystemProxyFixed({
    required this.type,
    required this.host,
    required this.port,
    this.bypass = const [],
    this.viaPac = false,
    this.username,
    this.password,
  });

  final ProxyType type;
  final String host;
  final int port;
  final List<String> bypass;
  final bool viaPac;

  /// Only the Linux environment variables can carry these.
  final String? username;
  final String? password;

  @override
  bool operator ==(Object other) =>
      other is SystemProxyFixed &&
      other.type == type &&
      other.host == host &&
      other.port == port &&
      listEquals(other.bypass, bypass) &&
      other.viaPac == viaPac &&
      other.username == username &&
      other.password == password;

  @override
  int get hashCode => Object.hash(
    type,
    host,
    port,
    Object.hashAll(bypass),
    viaPac,
    username,
    password,
  );

  @override
  String toString() =>
      'SystemProxyFixed(${type.name} $host:$port, pac: $viaPac, '
      'bypass: ${bypass.length}, auth: ${username != null})';
}

enum SystemProxyUnavailableReason { pacUnsupported, pacFailed, platformError }

/// The OS proxy could not be determined; the app goes direct and says why.
@immutable
class SystemProxyUnavailable extends SystemProxyResult {
  const SystemProxyUnavailable(this.reason, {this.detail});

  final SystemProxyUnavailableReason reason;
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is SystemProxyUnavailable &&
      other.reason == reason &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(reason, detail);
}
```

Spec amendment: in the spec's Architecture list, replace the `authenticateProxy` bullet with: "Credentials: dart:io authenticates a CONNECT tunnel only with credentials embedded in the `findProxy` directive (Basic, sent up front), so the directive carries them and the manual form rejects values that directive cannot represent (see `checkProxyCredentials`)." Also change "sets three callbacks" to "sets two callbacks".

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/network/proxy/proxy_settings_test.dart test/core/network/proxy/proxy_credentials_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/proxy test/core/network/proxy docs/design/specs/2026-10-10-network-proxy-design.md
git commit -m "feat(network): add proxy settings, credential rules and system result models"
```

---

### Task 2: EffectiveProxy and routing

**Files:**
- Create: `lib/core/network/proxy/effective_proxy.dart`, `lib/core/network/proxy/proxy_routing.dart`
- Test: `test/core/network/proxy/effective_proxy_test.dart`, `test/core/network/proxy/proxy_routing_test.dart`

**Interfaces:**
- Consumes: Task 1 models.
- Produces: `enum ProxyKind { direct, http, socks5 }`, `enum ProxySource { none, manual, system, systemPac }`, `EffectiveProxy` (fields `kind, host, port, username, password, bypass, source`; getters `isDirect`, `endpoint`), `EffectiveProxy.direct({ProxySource source})`, `static EffectiveProxy resolve({required ProxySettings settings, SystemProxyResult? system, String? password})`; `bool isAlwaysDirectHost(String host)`, `bool matchesBypass(String host, List<String> bypass)`, `typedef ProxyRoutingPolicy = bool Function(Uri url, EffectiveProxy proxy)`, `bool defaultShouldProxy(Uri url, EffectiveProxy proxy)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/network/proxy/effective_proxy_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

void main() {
  const manual = ProxySettings(
    mode: ProxyMode.manual,
    type: ProxyType.socks5,
    host: ' socks.example ',
    port: 1080,
    username: 'ann',
  );

  test('none mode is direct whatever the system says', () {
    final p = EffectiveProxy.resolve(
      settings: manual.copyWith(mode: ProxyMode.none),
      system: const SystemProxyFixed(type: ProxyType.http, host: 'h', port: 1),
    );
    expect(p.kind, ProxyKind.direct);
    expect(p.source, ProxySource.none);
  });

  test('manual mode uses the trimmed manual proxy and password', () {
    final p = EffectiveProxy.resolve(settings: manual, password: 'pw');
    expect(p.kind, ProxyKind.socks5);
    expect(p.host, 'socks.example');
    expect(p.port, 1080);
    expect(p.username, 'ann');
    expect(p.password, 'pw');
    expect(p.bypass, isEmpty);
    expect(p.source, ProxySource.manual);
  });

  test('manual mode without a usable proxy is direct', () {
    final p = EffectiveProxy.resolve(settings: manual.copyWith(clearPort: true));
    expect(p.isDirect, isTrue);
    expect(p.source, ProxySource.manual);
  });

  test('manual credentials are dropped when they fail the transport rules', () {
    final p = EffectiveProxy.resolve(
      settings: manual.copyWith(type: ProxyType.http),
      password: 'a;b',
    );
    expect(p.username, isNull);
    expect(p.password, isNull);
  });

  test('system fixed maps type, bypass and PAC source', () {
    final p = EffectiveProxy.resolve(
      settings: ProxySettings.defaults,
      system: const SystemProxyFixed(
        type: ProxyType.http,
        host: 'proxy.corp',
        port: 8080,
        bypass: ['*.corp'],
        viaPac: true,
      ),
    );
    expect(p.kind, ProxyKind.http);
    expect(p.endpoint, 'proxy.corp:8080');
    expect(p.bypass, ['*.corp']);
    expect(p.source, ProxySource.systemPac);
  });

  test('system none, unavailable and not-yet-known are direct', () {
    for (final system in <SystemProxyResult?>[
      null,
      const SystemProxyNone(),
      const SystemProxyUnavailable(SystemProxyUnavailableReason.pacFailed),
    ]) {
      final p = EffectiveProxy.resolve(
        settings: ProxySettings.defaults,
        system: system,
      );
      expect(p.isDirect, isTrue, reason: '$system');
      expect(p.source, ProxySource.system);
    }
  });

  test('endpoint brackets IPv6 and toString never shows the password', () {
    final p = EffectiveProxy.resolve(
      settings: manual.copyWith(host: '::1', type: ProxyType.socks5),
      password: 'hunter2',
    );
    expect(p.endpoint, '[::1]:1080');
    expect(p.toString(), isNot(contains('hunter2')));
    expect(p.toString(), isNot(contains('ann')));
  });
}
```

```dart
// test/core/network/proxy/proxy_routing_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_routing.dart';

void main() {
  group('isAlwaysDirectHost', () {
    for (final host in [
      'localhost', 'LOCALHOST', 'nas.local', 'printer.local.',
      '127.0.0.1', '127.9.9.9', '::1', '[::1]',
      '10.1.2.3', '172.16.0.1', '172.31.255.255', '192.168.1.10',
      '169.254.3.4', 'fd12::1', 'fe80::1',
    ]) {
      test('$host is direct', () => expect(isAlwaysDirectHost(host), isTrue));
    }
    for (final host in [
      'api.github.com', '172.32.0.1', '11.0.0.1', '8.8.8.8',
      '2001:db8::1', 'local.example.com',
    ]) {
      test('$host may be proxied', () => expect(isAlwaysDirectHost(host), isFalse));
    }
  });

  group('matchesBypass', () {
    test('exact host and subdomain of a plain entry', () {
      expect(matchesBypass('corp.com', ['corp.com']), isTrue);
      expect(matchesBypass('a.corp.com', ['corp.com']), isTrue);
      expect(matchesBypass('notcorp.com', ['corp.com']), isFalse);
    });
    test('wildcard and leading dot entries', () {
      expect(matchesBypass('a.corp.com', ['*.corp.com']), isTrue);
      expect(matchesBypass('corp.com', ['*.corp.com']), isTrue);
      expect(matchesBypass('a.corp.com', ['.corp.com']), isTrue);
      expect(matchesBypass('x.other.com', ['*.corp.com']), isFalse);
    });
    test('star alone bypasses everything', () {
      expect(matchesBypass('anything.com', ['*']), isTrue);
    });
    test('case and trailing dots are ignored', () {
      expect(matchesBypass('A.Corp.COM.', ['corp.com']), isTrue);
      expect(matchesBypass('a.corp.com', [' *.CORP.com ']), isTrue);
    });
    test('CIDR, including the macOS short form', () {
      expect(matchesBypass('100.64.1.2', ['100.64.0.0/10']), isTrue);
      expect(matchesBypass('100.128.0.1', ['100.64.0.0/10']), isFalse);
      expect(matchesBypass('203.0.113.9', ['203.0.113/24']), isTrue);
      expect(matchesBypass('2001:db8::5', ['2001:db8::/32']), isTrue);
    });
    test('<local> matches single-label names only', () {
      expect(matchesBypass('intranet', ['<local>']), isTrue);
      expect(matchesBypass('intranet.corp', ['<local>']), isFalse);
    });
    test('an entry with a port matches on its host part', () {
      expect(matchesBypass('corp.com', ['corp.com:8443']), isTrue);
    });
    test('empty and malformed entries never match', () {
      expect(matchesBypass('a.com', ['', '  ', '1.2.3.4/99', '/8']), isFalse);
    });
  });

  group('defaultShouldProxy', () {
    const proxy = EffectiveProxy(
      kind: ProxyKind.http,
      host: 'p',
      port: 1,
      bypass: ['*.corp'],
      source: ProxySource.system,
    );
    test('direct snapshot never proxies', () {
      expect(
        defaultShouldProxy(Uri.parse('https://a.com/'), const EffectiveProxy.direct()),
        isFalse,
      );
    });
    test('public host proxies, LAN and bypass do not', () {
      expect(defaultShouldProxy(Uri.parse('https://a.com/'), proxy), isTrue);
      expect(defaultShouldProxy(Uri.parse('http://192.168.1.5/'), proxy), isFalse);
      expect(defaultShouldProxy(Uri.parse('https://x.corp/'), proxy), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/network/proxy/effective_proxy_test.dart test/core/network/proxy/proxy_routing_test.dart`
Expected: FAIL, files missing.

- [ ] **Step 3: Implement**

```dart
// lib/core/network/proxy/effective_proxy.dart
import 'package:flutter/foundation.dart';

import 'package:submersion/core/network/proxy/proxy_credentials.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

enum ProxyKind { direct, http, socks5 }

/// Where the snapshot came from, for the settings page and the log.
enum ProxySource { none, manual, system, systemPac }

/// The proxy every new connection uses right now. Immutable: the network
/// layer reads one snapshot per connection and never sees a half update.
@immutable
class EffectiveProxy {
  const EffectiveProxy({
    required this.kind,
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.bypass = const [],
    required this.source,
  });

  const EffectiveProxy.direct({this.source = ProxySource.none})
    : kind = ProxyKind.direct,
      host = '',
      port = 0,
      username = null,
      password = null,
      bypass = const [];

  final ProxyKind kind;
  final String host;
  final int port;
  final String? username;
  final String? password;
  final List<String> bypass;
  final ProxySource source;

  bool get isDirect => kind == ProxyKind.direct;

  /// `host:port`, with an IPv6 host in brackets.
  String get endpoint => host.contains(':') ? '[$host]:$port' : '$host:$port';

  static EffectiveProxy resolve({
    required ProxySettings settings,
    SystemProxyResult? system,
    String? password,
  }) {
    switch (settings.mode) {
      case ProxyMode.none:
        return const EffectiveProxy.direct();
      case ProxyMode.manual:
        if (!settings.hasManualProxy) {
          return const EffectiveProxy.direct(source: ProxySource.manual);
        }
        final user = settings.username;
        final pass = password ?? '';
        final usable =
            user.isNotEmpty &&
            checkProxyCredentials(settings.type, user, pass) == null;
        return EffectiveProxy(
          kind: settings.type == ProxyType.http
              ? ProxyKind.http
              : ProxyKind.socks5,
          host: settings.host.trim(),
          port: settings.port!,
          username: usable ? user : null,
          password: usable ? pass : null,
          source: ProxySource.manual,
        );
      case ProxyMode.system:
        return switch (system) {
          SystemProxyFixed(:final type, :final host, :final port) =>
            EffectiveProxy(
              kind: type == ProxyType.http ? ProxyKind.http : ProxyKind.socks5,
              host: host,
              port: port,
              username: system.username,
              password: system.password,
              bypass: system.bypass,
              source: system.viaPac ? ProxySource.systemPac : ProxySource.system,
            ),
          _ => const EffectiveProxy.direct(source: ProxySource.system),
        };
    }
  }

  @override
  bool operator ==(Object other) =>
      other is EffectiveProxy &&
      other.kind == kind &&
      other.host == host &&
      other.port == port &&
      other.username == username &&
      other.password == password &&
      listEquals(other.bypass, bypass) &&
      other.source == source;

  @override
  int get hashCode => Object.hash(
    kind,
    host,
    port,
    username,
    password,
    Object.hashAll(bypass),
    source,
  );

  /// Never includes the credentials: this string reaches the debug log.
  @override
  String toString() => isDirect
      ? 'EffectiveProxy(direct, ${source.name})'
      : 'EffectiveProxy(${kind.name} $endpoint, ${source.name}, '
            'auth: ${username != null}, bypass: ${bypass.length})';
}
```

```dart
// lib/core/network/proxy/proxy_routing.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/core/network/proxy/effective_proxy.dart';

/// Decides whether one request goes through the snapshot's proxy.
typedef ProxyRoutingPolicy = bool Function(Uri url, EffectiveProxy proxy);

/// The production policy: proxy unless the snapshot is direct, the host is
/// this machine or the LAN, or the OS bypass list names it.
bool defaultShouldProxy(Uri url, EffectiveProxy proxy) {
  if (proxy.isDirect) return false;
  final host = url.host;
  if (isAlwaysDirectHost(host)) return false;
  return !matchesBypass(host, proxy.bypass);
}

String _normalize(String host) {
  var h = host.trim().toLowerCase();
  if (h.endsWith('.')) h = h.substring(0, h.length - 1);
  if (h.startsWith('[') && h.endsWith(']')) h = h.substring(1, h.length - 1);
  return h;
}

final _privateRanges = [
  _Cidr.parse('127.0.0.0/8')!,
  _Cidr.parse('10.0.0.0/8')!,
  _Cidr.parse('172.16.0.0/12')!,
  _Cidr.parse('192.168.0.0/16')!,
  _Cidr.parse('169.254.0.0/16')!,
  _Cidr.parse('::1/128')!,
  _Cidr.parse('fc00::/7')!,
  _Cidr.parse('fe80::/10')!,
];

/// This machine and the local network: never proxied in any mode, so LAN
/// features (the media network scan, a NAS) keep working.
bool isAlwaysDirectHost(String host) {
  final h = _normalize(host);
  if (h == 'localhost' || h.endsWith('.localhost') || h.endsWith('.local')) {
    return true;
  }
  final address = InternetAddress.tryParse(h);
  if (address == null) return false;
  return _privateRanges.any((r) => r.contains(address));
}

/// Whether [host] matches an OS bypass entry: an exact host (which also
/// covers its subdomains, as curl's no_proxy does), `*.domain`, `.domain`,
/// `*`, a CIDR range (macOS's short `203.0.113/24` included), or Windows'
/// `<local>` for single-label names.
bool matchesBypass(String host, List<String> bypass) {
  final h = _normalize(host);
  final address = InternetAddress.tryParse(h);
  for (final raw in bypass) {
    var entry = raw.trim().toLowerCase();
    if (entry.isEmpty) continue;
    if (entry == '*') return true;
    if (entry == '<local>') {
      if (address == null && !h.contains('.')) return true;
      continue;
    }
    if (entry.contains('/')) {
      final cidr = _Cidr.parse(entry);
      if (cidr != null && address != null && cidr.contains(address)) {
        return true;
      }
      continue;
    }
    // Drop a port: the bypass decision is per host here.
    final colon = entry.lastIndexOf(':');
    if (colon > 0 && !entry.contains('::') && entry.indexOf(':') == colon) {
      entry = entry.substring(0, colon);
    }
    if (entry.startsWith('*.')) entry = entry.substring(1);
    if (entry.startsWith('.')) {
      final bare = entry.substring(1);
      if (h == bare || h.endsWith(entry)) return true;
      continue;
    }
    if (h == entry || h.endsWith('.$entry')) return true;
  }
  return false;
}

class _Cidr {
  _Cidr(this._network, this._prefix);

  final Uint8List _network;
  final int _prefix;

  static _Cidr? parse(String text) {
    final slash = text.indexOf('/');
    if (slash <= 0) return null;
    var addressText = text.substring(0, slash);
    final prefix = int.tryParse(text.substring(slash + 1));
    if (prefix == null || prefix < 0) return null;
    if (!addressText.contains(':')) {
      final parts = addressText.split('.');
      if (parts.length > 4) return null;
      addressText = [...parts, ...List.filled(4 - parts.length, '0')].join('.');
    }
    final address = InternetAddress.tryParse(addressText);
    if (address == null) return null;
    if (prefix > address.rawAddress.length * 8) return null;
    return _Cidr(address.rawAddress, prefix);
  }

  bool contains(InternetAddress address) {
    final bytes = address.rawAddress;
    if (bytes.length != _network.length) return false;
    var bits = _prefix;
    for (var i = 0; i < bytes.length && bits > 0; i++) {
      final take = bits >= 8 ? 8 : bits;
      final mask = (0xff << (8 - take)) & 0xff;
      if ((bytes[i] & mask) != (_network[i] & mask)) return false;
      bits -= take;
    }
    return true;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/network/proxy/effective_proxy_test.dart test/core/network/proxy/proxy_routing_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/proxy test/core/network/proxy
git commit -m "feat(network): resolve the effective proxy and route LAN and bypass hosts direct"
```

---

### Task 3: ProxySettingsStore

**Files:**
- Create: `lib/core/network/proxy/proxy_settings_store.dart`
- Test: `test/core/network/proxy/proxy_settings_store_test.dart` (uses `test/support/fake_keychain_storage.dart`'s `InMemoryKeychain`)

**Interfaces:**
- Consumes: `ProxySettings`, `ProxyMode`, `ProxyType`.
- Produces: `ProxySettingsStore(SharedPreferences prefs, {FlutterSecureStorage? storage})` with `ProxySettings load()`, `Future<void> save(ProxySettings)`, `Future<String?> loadPassword()`, `Future<void> savePassword(String? password)` (null or empty deletes). Keys: `network_proxy_mode`, `network_proxy_type`, `network_proxy_host`, `network_proxy_port`, `network_proxy_username`; secure key `network_proxy_password`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/network/proxy/proxy_settings_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/proxy_settings_store.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  late InMemoryKeychain keychain;

  Future<ProxySettingsStore> store([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    return ProxySettingsStore(
      await SharedPreferences.getInstance(),
      storage: keychain,
    );
  }

  setUp(() => keychain = InMemoryKeychain());

  test('empty prefs load the defaults', () async {
    expect((await store()).load(), ProxySettings.defaults);
  });

  test('save then load round-trips every field', () async {
    final s = await store();
    const saved = ProxySettings(
      mode: ProxyMode.manual,
      type: ProxyType.socks5,
      host: 'socks.example',
      port: 1080,
      username: 'ann',
    );
    await s.save(saved);
    expect(s.load(), saved);
  });

  test('a cleared port is removed, not stored as zero', () async {
    final s = await store({'network_proxy_port': 8080});
    await s.save(ProxySettings.defaults);
    expect(s.load().port, isNull);
  });

  test('values from a newer version load as safe defaults', () async {
    final s = await store({
      'network_proxy_mode': 'pac-only',
      'network_proxy_type': 'quic',
      'network_proxy_port': 70000,
    });
    final loaded = s.load();
    expect(loaded.mode, ProxyMode.system);
    expect(loaded.type, ProxyType.http);
    expect(loaded.port, isNull);
  });

  test('the password lives in secure storage only', () async {
    final s = await store();
    await s.savePassword('hunter2');
    expect(await s.loadPassword(), 'hunter2');
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      expect(prefs.get(key), isNot('hunter2'));
    }
    await s.savePassword('');
    expect(await s.loadPassword(), isNull);
  });
}
```

Check `InMemoryKeychain`'s public API in `test/support/fake_keychain_storage.dart` before running; it implements `FlutterSecureStorage`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/network/proxy/proxy_settings_store_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Implement**

```dart
// lib/core/network/proxy/proxy_settings_store.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// Persists [ProxySettings] in SharedPreferences (device-local, never synced)
/// and the manual password in the platform keychain.
///
/// Reading tolerates anything a newer app version might have written: an
/// unknown mode or type, or a port out of range, falls back to the default
/// rather than failing startup.
class ProxySettingsStore {
  ProxySettingsStore(this._prefs, {FlutterSecureStorage? storage})
    : _storage = FallbackSecureStorage(
        storage ?? const FlutterSecureStorage(),
      );

  final SharedPreferences _prefs;
  final FallbackSecureStorage _storage;

  static const modeKey = 'network_proxy_mode';
  static const typeKey = 'network_proxy_type';
  static const hostKey = 'network_proxy_host';
  static const portKey = 'network_proxy_port';
  static const usernameKey = 'network_proxy_username';
  static const passwordKey = 'network_proxy_password';

  ProxySettings load() {
    final port = _prefs.getInt(portKey);
    return ProxySettings(
      mode: _byName(ProxyMode.values, _prefs.getString(modeKey)) ??
          ProxySettings.defaults.mode,
      type: _byName(ProxyType.values, _prefs.getString(typeKey)) ??
          ProxySettings.defaults.type,
      host: _prefs.getString(hostKey) ?? '',
      port: port != null && port >= 1 && port <= 65535 ? port : null,
      username: _prefs.getString(usernameKey) ?? '',
    );
  }

  Future<void> save(ProxySettings settings) async {
    await _prefs.setString(modeKey, settings.mode.name);
    await _prefs.setString(typeKey, settings.type.name);
    await _prefs.setString(hostKey, settings.host);
    final port = settings.port;
    if (port == null) {
      await _prefs.remove(portKey);
    } else {
      await _prefs.setInt(portKey, port);
    }
    await _prefs.setString(usernameKey, settings.username);
  }

  Future<String?> loadPassword() async {
    final value = await _storage.read(key: passwordKey);
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> savePassword(String? password) => password == null ||
          password.isEmpty
      ? _storage.delete(key: passwordKey)
      : _storage.write(key: passwordKey, value: password);

  static T? _byName<T extends Enum>(List<T> values, String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/network/proxy/proxy_settings_store_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/proxy/proxy_settings_store.dart test/core/network/proxy/proxy_settings_store_test.dart
git commit -m "feat(network): persist proxy settings locally with the password in the keychain"
```

---

### Task 4: SOCKS5 connector

**Files:**
- Create: `lib/core/network/proxy/socks5_connector.dart`, `test/helpers/fake_socks5_server.dart`, `test/helpers/recording_tcp_server.dart`
- Test: `test/core/network/proxy/socks5_connector_test.dart`

**Interfaces:**
- Produces: `enum Socks5Failure { proxyUnreachable, noAcceptableAuth, authRejected, generalFailure, notAllowed, networkUnreachable, hostUnreachable, connectionRefused, ttlExpired, commandNotSupported, addressTypeNotSupported, protocolError, hostnameTooLong }`; `class Socks5Exception extends SocketException { final Socks5Failure failure; }`; `class Socks5Tunnel { final Socket socket; Socket asPlainSocket(); }`; `Future<Socks5Tunnel> connectViaSocks5({required String proxyHost, required int proxyPort, required String targetHost, required int targetPort, String? username, String? password})`. The handshake uses the socket's only listener, left paused with nothing buffered: `SecureSocket.secure(tunnel.socket, ...)` takes the raw socket over for https (proved by a prototype during planning: two HTTPS requests through a loopback SOCKS5 server, the second on a pooled connection), and `asPlainSocket()` gives http a `Socket` whose reads come from that paused subscription.
- Test helpers: `FakeSocks5Server.start({String? username, String? password, int replyCode = 0})` exposing `port`, `List<FakeSocksRequest> requests` (`atyp`, `host`, `port`), `close()`; it pipes accepted CONNECTs to the real target. `RecordingTcpServer.start({List<int>? reply})` exposing `port`, `Future<List<int>> firstBytes`, `close()`.

- [ ] **Step 1: Write the test helpers**

```dart
// test/helpers/recording_tcp_server.dart
import 'dart:async';
import 'dart:io';

/// A loopback TCP server that records the first bytes a client sends, then
/// optionally answers with [reply] and keeps piping nothing else. Lets a test
/// prove a TLS ClientHello (0x16 0x03 ...) arrived through a tunnel without
/// needing a certificate.
class RecordingTcpServer {
  RecordingTcpServer._(this._server);

  final ServerSocket _server;
  final _first = Completer<List<int>>();

  int get port => _server.port;
  Future<List<int>> get firstBytes => _first.future;

  static Future<RecordingTcpServer> start({List<int>? reply}) async {
    final server = RecordingTcpServer._(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    );
    server._server.listen((socket) {
      socket.listen((data) {
        if (!server._first.isCompleted) server._first.complete(data);
        if (reply != null) socket.add(reply);
      }, onError: (_) {});
    });
    return server;
  }

  Future<void> close() => _server.close();
}
```

```dart
// test/helpers/fake_socks5_server.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class FakeSocksRequest {
  FakeSocksRequest(this.atyp, this.host, this.port);
  final int atyp;
  final String host;
  final int port;
}

/// A loopback SOCKS5 server (RFC 1928, optional RFC 1929 auth). Accepted
/// CONNECTs are piped to the real target, which a test keeps on loopback.
class FakeSocks5Server {
  FakeSocks5Server._(this._server, this.username, this.password, this.replyCode);

  final ServerSocket _server;
  final String? username;
  final String? password;
  final int replyCode;
  final requests = <FakeSocksRequest>[];

  int get port => _server.port;

  static Future<FakeSocks5Server> start({
    String? username,
    String? password,
    int replyCode = 0,
  }) async {
    final s = FakeSocks5Server._(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      username,
      password,
      replyCode,
    );
    s._server.listen(s._serve);
    return s;
  }

  Future<void> _serve(Socket client) async {
    final buf = <int>[];
    final it = StreamIterator(client);
    Future<List<int>> need(int n) async {
      while (buf.length < n) {
        if (!await it.moveNext()) throw StateError('closed');
        buf.addAll(it.current);
      }
      final out = buf.sublist(0, n);
      buf.removeRange(0, n);
      return out;
    }

    try {
      final greeting = await need(2);
      final methods = await need(greeting[1]);
      final wantAuth = username != null;
      final method = wantAuth ? 2 : 0;
      if (!methods.contains(method)) {
        client.add([5, 0xff]);
        await client.close();
        return;
      }
      client.add([5, method]);
      if (wantAuth) {
        await need(1);
        final ulen = (await need(1))[0];
        final user = utf8.decode(await need(ulen));
        final plen = (await need(1))[0];
        final pass = utf8.decode(await need(plen));
        final ok = user == username && pass == password;
        client.add([1, ok ? 0 : 1]);
        if (!ok) {
          await client.close();
          return;
        }
      }
      final head = await need(4);
      final atyp = head[3];
      final String host;
      if (atyp == 1) {
        host = InternetAddress.fromRawAddress(
          Uint8List.fromList(await need(4)),
        ).address;
      } else if (atyp == 4) {
        host = InternetAddress.fromRawAddress(
          Uint8List.fromList(await need(16)),
        ).address;
      } else {
        host = utf8.decode(await need((await need(1))[0]));
      }
      final pb = await need(2);
      final port = pb[0] << 8 | pb[1];
      requests.add(FakeSocksRequest(atyp, host, port));
      if (replyCode != 0) {
        client.add([5, replyCode, 0, 1, 0, 0, 0, 0, 0, 0]);
        await client.close();
        return;
      }
      // Tests only ever target loopback; map any name to it.
      final upstream = await Socket.connect(InternetAddress.loopbackIPv4, port);
      client.add([5, 0, 0, 1, 127, 0, 0, 1, 0, 0]);
      if (buf.isNotEmpty) upstream.add(buf);
      upstream.listen(client.add, onDone: client.destroy, onError: (_) {});
      unawaited(() async {
        while (await it.moveNext()) {
          upstream.add(it.current);
        }
        upstream.destroy();
      }());
    } catch (_) {
      client.destroy();
    }
  }

  Future<void> close() => _server.close();
}
```

Add `import 'dart:typed_data';` to the SOCKS helper (it uses `Uint8List`).

- [ ] **Step 2: Write the failing tests**

```dart
// test/core/network/proxy/socks5_connector_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/socks5_connector.dart';

import '../../../helpers/fake_socks5_server.dart';
import '../../../helpers/recording_tcp_server.dart';

void main() {
  late RecordingTcpServer target;

  setUp(() async => target = await RecordingTcpServer.start(reply: utf8.encode('pong')));
  tearDown(() => target.close());

  Future<String> roundTrip(Socks5Tunnel t) async {
    final s = t.asPlainSocket();
    s.add(utf8.encode('ping'));
    final reply = await s.first;
    s.destroy();
    return utf8.decode(reply);
  }

  test('no-auth CONNECT by hostname tunnels bytes', () async {
    final socks = await FakeSocks5Server.start();
    addTearDown(socks.close);
    final s = await connectViaSocks5(
      proxyHost: '127.0.0.1', proxyPort: socks.port,
      targetHost: 'example.test', targetPort: target.port,
    );
    expect(await roundTrip(s), 'pong');
    expect(socks.requests.single.atyp, 3);
    expect(socks.requests.single.host, 'example.test');
    expect(utf8.decode(await target.firstBytes), 'ping');
  });

  test('IPv4 and IPv6 literals use address types 1 and 4', () async {
    final socks = await FakeSocks5Server.start();
    addTearDown(socks.close);
    final a = await connectViaSocks5(
      proxyHost: '127.0.0.1', proxyPort: socks.port,
      targetHost: '127.0.0.1', targetPort: target.port,
    );
    a.socket.destroy();
    final b = await connectViaSocks5(
      proxyHost: '127.0.0.1', proxyPort: socks.port,
      targetHost: '[::1]', targetPort: target.port,
    );
    b.socket.destroy();
    expect(socks.requests.map((r) => r.atyp), [1, 4]);
    expect(socks.requests.last.host, '::1');
  });

  test('username and password authenticate', () async {
    final socks = await FakeSocks5Server.start(username: 'ann', password: 'p:@;w');
    addTearDown(socks.close);
    final s = await connectViaSocks5(
      proxyHost: '127.0.0.1', proxyPort: socks.port,
      targetHost: 'x.test', targetPort: target.port,
      username: 'ann', password: 'p:@;w',
    );
    expect(await roundTrip(s), 'pong');
  });

  test('wrong password is authRejected', () async {
    final socks = await FakeSocks5Server.start(username: 'ann', password: 'right');
    addTearDown(socks.close);
    await expectLater(
      connectViaSocks5(
        proxyHost: '127.0.0.1', proxyPort: socks.port,
        targetHost: 'x.test', targetPort: target.port,
        username: 'ann', password: 'wrong',
      ),
      throwsA(isA<Socks5Exception>().having((e) => e.failure, 'failure', Socks5Failure.authRejected)),
    );
  });

  test('server wanting auth from a client without credentials is noAcceptableAuth', () async {
    final socks = await FakeSocks5Server.start(username: 'ann', password: 'x');
    addTearDown(socks.close);
    await expectLater(
      connectViaSocks5(
        proxyHost: '127.0.0.1', proxyPort: socks.port,
        targetHost: 'x.test', targetPort: target.port,
      ),
      throwsA(isA<Socks5Exception>().having((e) => e.failure, 'failure', Socks5Failure.noAcceptableAuth)),
    );
  });

  test('reply codes map to failures', () async {
    final codes = {
      1: Socks5Failure.generalFailure,
      2: Socks5Failure.notAllowed,
      3: Socks5Failure.networkUnreachable,
      4: Socks5Failure.hostUnreachable,
      5: Socks5Failure.connectionRefused,
      6: Socks5Failure.ttlExpired,
      7: Socks5Failure.commandNotSupported,
      8: Socks5Failure.addressTypeNotSupported,
      9: Socks5Failure.protocolError,
    };
    for (final entry in codes.entries) {
      final socks = await FakeSocks5Server.start(replyCode: entry.key);
      await expectLater(
        connectViaSocks5(
          proxyHost: '127.0.0.1', proxyPort: socks.port,
          targetHost: 'x.test', targetPort: 1,
        ),
        throwsA(isA<Socks5Exception>().having((e) => e.failure, 'code ${entry.key}', entry.value)),
      );
      await socks.close();
    }
  });

  test('unreachable proxy is proxyUnreachable', () async {
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    await expectLater(
      connectViaSocks5(proxyHost: '127.0.0.1', proxyPort: port, targetHost: 'x.test', targetPort: 1),
      throwsA(isA<Socks5Exception>().having((e) => e.failure, 'failure', Socks5Failure.proxyUnreachable)),
    );
  });

  test('a hostname over 255 bytes fails before connecting', () async {
    await expectLater(
      connectViaSocks5(proxyHost: '127.0.0.1', proxyPort: 1, targetHost: 'a' * 256, targetPort: 1),
      throwsA(isA<Socks5Exception>().having((e) => e.failure, 'failure', Socks5Failure.hostnameTooLong)),
    );
  });

  test('a Socks5Exception is a SocketException', () {
    expect(const Socks5Exception(Socks5Failure.generalFailure), isA<SocketException>());
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/core/network/proxy/socks5_connector_test.dart`
Expected: FAIL, library missing.

- [ ] **Step 4: Implement**

```dart
// lib/core/network/proxy/socks5_connector.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum Socks5Failure {
  proxyUnreachable,
  noAcceptableAuth,
  authRejected,
  generalFailure,
  notAllowed,
  networkUnreachable,
  hostUnreachable,
  connectionRefused,
  ttlExpired,
  commandNotSupported,
  addressTypeNotSupported,
  protocolError,
  hostnameTooLong,
}

/// A SOCKS5 failure. A [SocketException], so every caller that already treats
/// socket errors as "the network is down" keeps doing so.
class Socks5Exception extends SocketException {
  const Socks5Exception(this.failure, {String? detail})
    : super(detail ?? 'SOCKS5 proxy error');

  final Socks5Failure failure;

  @override
  String toString() => 'Socks5Exception(${failure.name}): $message';
}

const _replyFailures = {
  1: Socks5Failure.generalFailure,
  2: Socks5Failure.notAllowed,
  3: Socks5Failure.networkUnreachable,
  4: Socks5Failure.hostUnreachable,
  5: Socks5Failure.connectionRefused,
  6: Socks5Failure.ttlExpired,
  7: Socks5Failure.commandNotSupported,
  8: Socks5Failure.addressTypeNotSupported,
};

/// Opens a TCP connection to [targetHost]:[targetPort] through the SOCKS5
/// server at [proxyHost]:[proxyPort] (RFC 1928), authenticating with RFC 1929
/// username and password when [username] is set.
///
/// A hostname target is sent as a name, so the proxy resolves DNS (some
/// networks only resolve public names at the proxy). IP literals go as
/// address types 1 and 4.
///
/// The handshake uses the socket's only listener; see [Socks5Tunnel] for
/// how https and http each take the open tunnel over.
Future<Socks5Tunnel> connectViaSocks5({
  required String proxyHost,
  required int proxyPort,
  required String targetHost,
  required int targetPort,
  String? username,
  String? password,
}) async {
  var host = targetHost;
  if (host.startsWith('[') && host.endsWith(']')) {
    host = host.substring(1, host.length - 1);
  }
  final literal = InternetAddress.tryParse(host);
  final nameBytes = utf8.encode(host);
  if (literal == null && nameBytes.length > 255) {
    throw const Socks5Exception(Socks5Failure.hostnameTooLong);
  }

  final Socket socket;
  try {
    socket = await Socket.connect(proxyHost, proxyPort);
  } on SocketException catch (e) {
    throw Socks5Exception(
      Socks5Failure.proxyUnreachable,
      detail: 'Could not reach SOCKS5 proxy $proxyHost:$proxyPort: ${e.message}',
    );
  }

  final pending = <int>[];
  var waiter = Completer<void>();
  var closed = false;
  final sub = socket.listen(
    (data) {
      pending.addAll(data);
      if (!waiter.isCompleted) waiter.complete();
    },
    onDone: () {
      closed = true;
      if (!waiter.isCompleted) waiter.complete();
    },
    onError: (Object _) {
      closed = true;
      if (!waiter.isCompleted) waiter.complete();
    },
  );

  Future<List<int>> need(int n) async {
    while (pending.length < n) {
      if (closed) {
        throw const Socks5Exception(
          Socks5Failure.protocolError,
          detail: 'SOCKS5 proxy closed the connection',
        );
      }
      waiter = Completer<void>();
      await waiter.future;
    }
    final out = pending.sublist(0, n);
    pending.removeRange(0, n);
    return out;
  }

  try {
    final withAuth = username != null && username.isNotEmpty;
    socket.add(withAuth ? [5, 2, 0, 2] : [5, 1, 0]);
    final choice = await need(2);
    if (choice[0] != 5) {
      throw const Socks5Exception(Socks5Failure.protocolError);
    }
    if (choice[1] == 0xff) {
      throw const Socks5Exception(Socks5Failure.noAcceptableAuth);
    }
    if (choice[1] == 2) {
      if (!withAuth) {
        throw const Socks5Exception(Socks5Failure.noAcceptableAuth);
      }
      final u = utf8.encode(username);
      final p = utf8.encode(password ?? '');
      socket.add([1, u.length, ...u, p.length, ...p]);
      final status = await need(2);
      if (status[1] != 0) {
        throw const Socks5Exception(Socks5Failure.authRejected);
      }
    } else if (choice[1] != 0) {
      throw const Socks5Exception(Socks5Failure.protocolError);
    }

    final List<int> address;
    if (literal == null) {
      address = [3, nameBytes.length, ...nameBytes];
    } else {
      address = [
        literal.type == InternetAddressType.IPv6 ? 4 : 1,
        ...literal.rawAddress,
      ];
    }
    socket.add([5, 1, 0, ...address, targetPort >> 8, targetPort & 0xff]);

    final head = await need(4);
    if (head[0] != 5) throw const Socks5Exception(Socks5Failure.protocolError);
    if (head[1] != 0) {
      throw Socks5Exception(
        _replyFailures[head[1]] ?? Socks5Failure.protocolError,
        detail: 'SOCKS5 proxy refused the connection (reply ${head[1]})',
      );
    }
    switch (head[3]) {
      case 1:
        await need(4 + 2);
      case 4:
        await need(16 + 2);
      case 3:
        await need((await need(1))[0] + 2);
      default:
        throw const Socks5Exception(Socks5Failure.protocolError);
    }
    if (pending.isNotEmpty) {
      throw const Socks5Exception(
        Socks5Failure.protocolError,
        detail: 'SOCKS5 proxy sent data before the tunnel opened',
      );
    }
    sub.pause();
    return Socks5Tunnel._(socket, sub);
  } catch (_) {
    socket.destroy();
    rethrow;
  }
}
```

Append the tunnel types to the same file (add `import 'dart:typed_data';`):

```dart
/// An open SOCKS5 tunnel.
///
/// A Socket is single-subscription and the handshake already used its
/// listener (paused, nothing buffered). For https, hand [socket] to
/// SecureSocket.secure, which detaches the raw socket and needs the real
/// dart:io Socket. For http, use [asPlainSocket].
class Socks5Tunnel {
  Socks5Tunnel._(this.socket, this._subscription);

  final Socket socket;
  final StreamSubscription<Uint8List> _subscription;

  Socket asPlainSocket() => _TunnelSocket(socket, _subscription);
}

/// A Socket whose reads come from the handshake's paused subscription and
/// whose writes and options go to the real socket.
class _TunnelSocket extends Stream<Uint8List> implements Socket {
  _TunnelSocket(this._inner, this._subscription);

  final Socket _inner;
  final StreamSubscription<Uint8List> _subscription;
  var _listened = false;

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    if (_listened) throw StateError('Stream has already been listened to.');
    _listened = true;
    final controller = StreamController<Uint8List>(
      sync: true,
      onPause: _subscription.pause,
      onResume: _subscription.resume,
      onCancel: _subscription.cancel,
    );
    _subscription
      ..onData(controller.add)
      ..onError(controller.addError)
      ..onDone(controller.close);
    final sub = controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    _subscription.resume();
    return sub;
  }

  @override
  Encoding get encoding => _inner.encoding;
  @override
  set encoding(Encoding value) => _inner.encoding = value;
  @override
  void add(List<int> data) => _inner.add(data);
  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);
  @override
  Future<void> addStream(Stream<List<int>> stream) => _inner.addStream(stream);
  @override
  Future<void> close() => _inner.close();
  @override
  Future<void> get done => _inner.done;
  @override
  Future<void> flush() => _inner.flush();
  @override
  void write(Object? object) => _inner.write(object);
  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _inner.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => _inner.writeCharCode(charCode);
  @override
  void writeln([Object? object = '']) => _inner.writeln(object);
  @override
  InternetAddress get address => _inner.address;
  @override
  InternetAddress get remoteAddress => _inner.remoteAddress;
  @override
  int get port => _inner.port;
  @override
  int get remotePort => _inner.remotePort;
  @override
  bool setOption(SocketOption option, bool enabled) =>
      _inner.setOption(option, enabled);
  @override
  Uint8List getRawOption(RawSocketOption option) =>
      _inner.getRawOption(option);
  @override
  void setRawOption(RawSocketOption option) => _inner.setRawOption(option);
  @override
  void destroy() => _inner.destroy();
}
```

If the analyzer reports a `Socket` or `IOSink` member missing on this SDK, add it as a plain delegation to `_inner`; the return types above follow the SDK's declarations, so match the analyzer's expected signature exactly.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/network/proxy/socks5_connector_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/core/network/proxy/socks5_connector.dart test/core/network/proxy/socks5_connector_test.dart test/helpers/fake_socks5_server.dart test/helpers/recording_tcp_server.dart
git commit -m "feat(network): add a SOCKS5 client connector"
```

---

### Task 5: AppHttpOverrides (replaces TrustedHttpOverrides)

**Files:**
- Create: `lib/core/network/proxy/app_http_overrides.dart`, `test/helpers/fake_http_proxy.dart`
- Delete: `lib/core/network/trusted_http_overrides.dart`, `test/core/network/trusted_http_overrides_test.dart`
- Test: `test/core/network/proxy/app_http_overrides_test.dart`

**Interfaces:**
- Consumes: `EffectiveProxy`, `ProxyRoutingPolicy`, `defaultShouldProxy`, `connectViaSocks5`, `appSecurityContext()` (from `lib/core/network/app_security_context.dart`).
- Produces: `class AppHttpOverrides extends HttpOverrides { AppHttpOverrides({required EffectiveProxy Function() currentProxy, ProxyRoutingPolicy shouldProxy = defaultShouldProxy, SecurityContext? Function() fallbackContext = appSecurityContext}); }`; `String proxyDirective(EffectiveProxy proxy)`.
- Test helper: `FakeHttpProxy.start({String? requireBasic})` (`requireBasic` = expected `user:pass`), exposing `port`, `List<String> requestLines`, `List<String?> proxyAuthorizations`, `close()`. It answers CONNECT with 200 and pipes to `127.0.0.1:<target port>`, answers absolute-form GETs by forwarding to the loopback target, and returns 407 when `requireBasic` is set and the header does not match.

- [ ] **Step 1: Write the fake HTTP proxy helper**

```dart
// test/helpers/fake_http_proxy.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A loopback HTTP proxy: CONNECT tunnels and absolute-form forwarding, both
/// to loopback ports only, with optional Basic auth.
class FakeHttpProxy {
  FakeHttpProxy._(this._server, this.requireBasic);

  final ServerSocket _server;
  final String? requireBasic;
  final requestLines = <String>[];
  final proxyAuthorizations = <String?>[];

  int get port => _server.port;

  static Future<FakeHttpProxy> start({String? requireBasic}) async {
    final p = FakeHttpProxy._(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      requireBasic,
    );
    p._server.listen(p._serve);
    return p;
  }

  Future<void> _serve(Socket client) async {
    final buf = <int>[];
    late StreamSubscription<List<int>> sub;
    final headerDone = Completer<void>();
    sub = client.listen((d) {
      buf.addAll(d);
      if (!headerDone.isCompleted &&
          latin1.decode(buf, allowInvalid: true).contains('\r\n\r\n')) {
        sub.pause();
        headerDone.complete();
      }
    }, onError: (_) {});
    await headerDone.future;
    final text = latin1.decode(buf);
    final end = text.indexOf('\r\n\r\n') + 4;
    final lines = text.substring(0, end).split('\r\n');
    final requestLine = lines.first;
    requestLines.add(requestLine);
    String? auth;
    for (final l in lines.skip(1)) {
      if (l.toLowerCase().startsWith('proxy-authorization:')) {
        auth = l.substring(l.indexOf(':') + 1).trim();
      }
    }
    proxyAuthorizations.add(auth);
    final expected = requireBasic == null
        ? null
        : 'Basic ${base64Encode(utf8.encode(requireBasic!))}';
    if (expected != null && auth != expected) {
      client.add(latin1.encode(
        'HTTP/1.1 407 Proxy Authentication Required\r\n'
        'Proxy-Authenticate: Basic realm="test"\r\nContent-Length: 0\r\n\r\n',
      ));
      await client.close();
      return;
    }
    final parts = requestLine.split(' ');
    final rest = buf.sublist(end);
    if (parts[0] == 'CONNECT') {
      final targetPort = int.parse(parts[1].split(':').last);
      final up = await Socket.connect(InternetAddress.loopbackIPv4, targetPort);
      client.add(latin1.encode('HTTP/1.1 200 Connection Established\r\n\r\n'));
      if (rest.isNotEmpty) up.add(rest);
      up.listen(client.add, onDone: client.destroy, onError: (_) {});
      sub.onData(up.add);
      sub.onDone(up.destroy);
      sub.resume();
      return;
    }
    final target = Uri.parse(parts[1]);
    final up = await Socket.connect(InternetAddress.loopbackIPv4, target.port);
    final forwarded = text
        .substring(0, end)
        .replaceFirst(parts[1], target.hasQuery ? '${target.path}?${target.query}' : target.path);
    up.add(latin1.encode(forwarded));
    if (rest.isNotEmpty) up.add(rest);
    up.listen(client.add, onDone: client.destroy, onError: (_) {});
    sub.onData(up.add);
    sub.onDone(up.destroy);
    sub.resume();
  }

  Future<void> close() => _server.close();
}
```

- [ ] **Step 2: Write the failing tests**

```dart
// test/core/network/proxy/app_http_overrides_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/app_http_overrides.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';

import '../../../helpers/fake_http_proxy.dart';
import '../../../helpers/fake_socks5_server.dart';
import '../../../helpers/recording_tcp_server.dart';

/// Tests run every endpoint on loopback, which the production policy always
/// sends direct; this policy proxies everything the snapshot allows.
bool proxyEverything(Uri url, EffectiveProxy p) => !p.isDirect;

EffectiveProxy http(int port, {String? user, String? pass}) => EffectiveProxy(
  kind: ProxyKind.http, host: '127.0.0.1', port: port,
  username: user, password: pass, source: ProxySource.manual,
);

EffectiveProxy socks(int port, {String? user, String? pass}) => EffectiveProxy(
  kind: ProxyKind.socks5, host: '127.0.0.1', port: port,
  username: user, password: pass, source: ProxySource.manual,
);

void main() {
  late HttpServer target;

  setUp(() async {
    target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    target.listen((r) => r.response..write('ok ${r.uri.path}')..close());
  });
  tearDown(() => target.close(force: true));

  Future<String> get(HttpClient c, String url) async {
    final res = await (await c.getUrl(Uri.parse(url))).close();
    return res.transform(utf8.decoder).join();
  }

  group('proxyDirective', () {
    test('direct', () => expect(proxyDirective(const EffectiveProxy.direct()), 'DIRECT'));
    test('host and port, IPv6 bracketed', () {
      expect(proxyDirective(http(8080)), 'PROXY 127.0.0.1:8080');
      expect(
        proxyDirective(const EffectiveProxy(kind: ProxyKind.http, host: '::1', port: 3128, source: ProxySource.manual)),
        'PROXY [::1]:3128',
      );
    });
    test('credentials are embedded as user:pass@', () {
      expect(proxyDirective(http(1, user: 'ann', pass: 'p@:x')), 'PROXY ann:p@:x@127.0.0.1:1');
    });
  });

  test('direct snapshot reaches the target without a proxy', () async {
    final c = AppHttpOverrides(
      currentProxy: () => const EffectiveProxy.direct(),
      shouldProxy: proxyEverything,
      fallbackContext: () => null,
    ).createHttpClient(null);
    addTearDown(() => c.close(force: true));
    expect(await get(c, 'http://127.0.0.1:${target.port}/a'), 'ok /a');
  });

  test('http proxy forwards plain http with Basic credentials containing @ and :', () async {
    final proxy = await FakeHttpProxy.start(requireBasic: 'ann:p@:x');
    addTearDown(proxy.close);
    final c = AppHttpOverrides(
      currentProxy: () => http(proxy.port, user: 'ann', pass: 'p@:x'),
      shouldProxy: proxyEverything,
      fallbackContext: () => null,
    ).createHttpClient(null);
    addTearDown(() => c.close(force: true));
    expect(await get(c, 'http://127.0.0.1:${target.port}/b'), 'ok /b');
    expect(proxy.requestLines.single, startsWith('GET http://127.0.0.1:${target.port}/b'));
  });

  test('https goes through CONNECT with credentials up front', () async {
    final proxy = await FakeHttpProxy.start(requireBasic: 'ann:pw');
    addTearDown(proxy.close);
    final hello = await RecordingTcpServer.start();
    addTearDown(hello.close);
    final c = AppHttpOverrides(
      currentProxy: () => http(proxy.port, user: 'ann', pass: 'pw'),
      shouldProxy: proxyEverything,
      fallbackContext: () => null,
    ).createHttpClient(null);
    c.connectionTimeout = const Duration(seconds: 2);
    addTearDown(() => c.close(force: true));
    // The recorder never completes a TLS handshake; the request fails, but
    // only after the ClientHello crossed the tunnel.
    final request = c.getUrl(Uri.parse('https://example.test:${hello.port}/'));
    final first = await hello.firstBytes;
    expect(first.take(2), [0x16, 0x03]);
    expect(proxy.requestLines.single, 'CONNECT example.test:${hello.port} HTTP/1.1');
    request.ignore();
  });

  test('socks5 carries plain http to the target', () async {
    final s = await FakeSocks5Server.start(username: 'ann', password: 'pw');
    addTearDown(s.close);
    final c = AppHttpOverrides(
      currentProxy: () => socks(s.port, user: 'ann', pass: 'pw'),
      shouldProxy: proxyEverything,
      fallbackContext: () => null,
    ).createHttpClient(null);
    addTearDown(() => c.close(force: true));
    expect(await get(c, 'http://example.test:${target.port}/c'), 'ok /c');
    expect(s.requests.single.host, 'example.test');
  });

  test('socks5 starts TLS for https inside the tunnel', () async {
    final s = await FakeSocks5Server.start();
    addTearDown(s.close);
    final hello = await RecordingTcpServer.start();
    addTearDown(hello.close);
    final c = AppHttpOverrides(
      currentProxy: () => socks(s.port),
      shouldProxy: proxyEverything,
      fallbackContext: () => null,
    ).createHttpClient(null);
    addTearDown(() => c.close(force: true));
    final request = c.getUrl(Uri.parse('https://example.test:${hello.port}/'));
    expect((await hello.firstBytes).take(2), [0x16, 0x03]);
    request.ignore();
  });

  test('a snapshot change applies to the next connection on the same client', () async {
    final proxy = await FakeHttpProxy.start();
    addTearDown(proxy.close);
    var current = const EffectiveProxy.direct();
    final c = AppHttpOverrides(
      currentProxy: () => current,
      shouldProxy: proxyEverything,
      fallbackContext: () => null,
    ).createHttpClient(null);
    addTearDown(() => c.close(force: true));
    expect(await get(c, 'http://127.0.0.1:${target.port}/1'), 'ok /1');
    expect(proxy.requestLines, isEmpty);
    current = http(proxy.port);
    // A different host key, so no pooled direct connection is reused.
    expect(await get(c, 'http://localhost:${target.port}/2'), 'ok /2');
    expect(proxy.requestLines, hasLength(1));
  });

  test('the production policy keeps loopback direct even with a proxy set', () async {
    final proxy = await FakeHttpProxy.start();
    addTearDown(proxy.close);
    final c = AppHttpOverrides(
      currentProxy: () => http(proxy.port),
      fallbackContext: () => null,
    ).createHttpClient(null);
    addTearDown(() => c.close(force: true));
    expect(await get(c, 'http://127.0.0.1:${target.port}/d'), 'ok /d');
    expect(proxy.requestLines, isEmpty);
  });

  test('an explicit SecurityContext wins over the fallback', () {
    var asked = false;
    final c = AppHttpOverrides(
      currentProxy: () => const EffectiveProxy.direct(),
      fallbackContext: () {
        asked = true;
        return null;
      },
    ).createHttpClient(SecurityContext(withTrustedRoots: true));
    addTearDown(() => c.close(force: true));
    expect(asked, isFalse);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/core/network/proxy/app_http_overrides_test.dart`
Expected: FAIL, library missing.

- [ ] **Step 4: Implement**

```dart
// lib/core/network/proxy/app_http_overrides.dart
import 'dart:async';
import 'dart:io';

import 'package:submersion/core/network/app_security_context.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_routing.dart';
import 'package:submersion/core/network/proxy/socks5_connector.dart';

/// The dart:io proxy directive for [proxy]: `DIRECT`, or
/// `PROXY [user:pass@]host:port`.
///
/// Credentials go in the directive because it is the only way dart:io
/// authenticates a CONNECT tunnel (HTTPS through an HTTP proxy): it sends
/// them as Basic, up front, and never calls `authenticateProxy` for a tunnel.
/// checkProxyCredentials rejects the values this format cannot carry.
String proxyDirective(EffectiveProxy proxy) {
  if (proxy.kind != ProxyKind.http) return 'DIRECT';
  final user = proxy.username;
  final auth = user == null ? '' : '$user:${proxy.password ?? ''}@';
  return 'PROXY $auth${proxy.endpoint}';
}

/// The app's one hook into every HttpClient the Dart VM creates: flutter_map
/// and FMTC tiles, NetworkImage, and every package:http client included.
///
/// It keeps the Windows trust fix (the platform-trusted SecurityContext from
/// [appSecurityContext]) and routes each connection by the proxy snapshot
/// [currentProxy] returns at connection time, so a settings or network change
/// reaches long-lived clients on their next connection.
///
/// HTTP proxies use dart:io's own forwarding and CONNECT tunnels via
/// findProxy. SOCKS5 has no dart:io support, so findProxy says DIRECT and the
/// connectionFactory opens the tunnel itself, adding TLS for https.
class AppHttpOverrides extends HttpOverrides {
  AppHttpOverrides({
    required EffectiveProxy Function() currentProxy,
    ProxyRoutingPolicy shouldProxy = defaultShouldProxy,
    SecurityContext? Function() fallbackContext = appSecurityContext,
  }) : _currentProxy = currentProxy,
       _shouldProxy = shouldProxy,
       _fallbackContext = fallbackContext;

  final EffectiveProxy Function() _currentProxy;
  final ProxyRoutingPolicy _shouldProxy;
  final SecurityContext? Function() _fallbackContext;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final effectiveContext = context ?? _fallbackContext();
    final client = super.createHttpClient(effectiveContext);
    client.findProxy = (url) {
      final proxy = _currentProxy();
      if (proxy.kind != ProxyKind.http || !_shouldProxy(url, proxy)) {
        return 'DIRECT';
      }
      return proxyDirective(proxy);
    };
    client.connectionFactory = (url, proxyHost, proxyPort) =>
        _connect(url, proxyHost, proxyPort, effectiveContext);
    return client;
  }

  Future<ConnectionTask<Socket>> _connect(
    Uri url,
    String? proxyHost,
    int? proxyPort,
    SecurityContext? context,
  ) {
    // An HTTP proxy: a plain socket to it; dart:io speaks to the proxy and
    // runs the CONNECT tunnel and TLS itself.
    if (proxyHost != null && proxyPort != null) {
      return Socket.startConnect(proxyHost, proxyPort);
    }
    final secure = url.isScheme('https');
    final port = url.hasPort ? url.port : (secure ? 443 : 80);
    final proxy = _currentProxy();
    if (proxy.kind == ProxyKind.socks5 && _shouldProxy(url, proxy)) {
      var cancelled = false;
      final socket = () async {
        final tunnel = await connectViaSocks5(
          proxyHost: proxy.host,
          proxyPort: proxy.port,
          targetHost: url.host,
          targetPort: port,
          username: proxy.username,
          password: proxy.password,
        );
        if (cancelled) {
          tunnel.socket.destroy();
          throw const SocketException('Connection cancelled');
        }
        if (!secure) return tunnel.asPlainSocket();
        return SecureSocket.secure(
          tunnel.socket,
          host: url.host,
          context: context,
        );
      }();
      return Future.value(
        ConnectionTask.fromSocket(socket, () => cancelled = true),
      );
    }
    // Direct: exactly what dart:io does without a factory.
    return secure
        ? SecureSocket.startConnect(url.host, port, context: context)
        : Socket.startConnect(url.host, port);
  }
}
```

A SOCKS5 tunnel opened by the factory is keyed by dart:io under the target host (findProxy said DIRECT), so after a switch away from SOCKS5 an idle pooled tunnel can serve one more request to that host before it closes; the spec accepts this (changes apply to new connections).

Then delete the old class and its test:

```bash
git rm lib/core/network/trusted_http_overrides.dart test/core/network/trusted_http_overrides_test.dart
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/network/proxy/app_http_overrides_test.dart test/core/network/proxy/socks5_connector_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/core/network test/core/network test/helpers/fake_http_proxy.dart
git commit -m "feat(network): route every HttpClient through the live proxy snapshot"
```

(`main.dart` still references `TrustedHttpOverrides` until Task 11; to keep the tree compiling at this commit, change that one line to `AppHttpOverrides(currentProxy: () => const EffectiveProxy.direct())` inside the existing Windows guard now, and include `lib/main.dart` in this commit.)

---

### Task 6: System resolver interface, channel resolver and parsers

**Files:**
- Create: `lib/core/network/proxy/system/system_proxy_resolver.dart`, `lib/core/network/proxy/system/channel_system_proxy_resolver.dart`, `lib/core/network/proxy/system/linux_proxy_parser.dart`, `lib/core/network/proxy/system/linux_system_proxy_resolver.dart`, `lib/core/network/proxy/system/windows_proxy_parser.dart`
- Test: `test/core/network/proxy/system/channel_system_proxy_resolver_test.dart`, `test/core/network/proxy/system/linux_proxy_parser_test.dart`, `test/core/network/proxy/system/linux_system_proxy_resolver_test.dart`, `test/core/network/proxy/system/windows_proxy_parser_test.dart`

**Interfaces:**
- Produces: `final Uri proxyProbeUrl = Uri.parse('https://api.github.com/')`; `abstract class SystemProxyResolver { Future<SystemProxyResult> resolve(Uri probe); static SystemProxyResolver forPlatform(); }`; `ChannelSystemProxyResolver({MethodChannel channel})` and `SystemProxyResult parseChannelProxyResult(Object? raw)`; `SystemProxyResult? parseProxyEnvironment(Map<String, String> env)`, `List<String> parseNoProxy(String? value)`, `String? parseGVariantString(String? out)`, `List<String> parseGVariantStringList(String? out)`; `LinuxSystemProxyResolver({Map<String, String>? environment, Future<String?> Function(String schema, String key)? gsettings})`; `class RawWindowsProxy` and `SystemProxyResult parseWindowsProxy(RawWindowsProxy raw)`, `({ProxyType type, String host, int port})? pickWindowsProxy(String list)`.

Channel contract (`app.submersion/system_proxy`, method `resolve`, args `{'url': String}`), returns a map: `{'kind': 'none'}`, `{'kind': 'fixed', 'type': 'http'|'socks5', 'host': String, 'port': int, 'bypass': List<String>, 'viaPac': bool}`, or `{'kind': 'unavailable', 'reason': 'pacUnsupported'|'pacFailed'|'platformError', 'detail': String?}`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/network/proxy/system/channel_system_proxy_resolver_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/channel_system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseChannelProxyResult', () {
    test('none', () => expect(parseChannelProxyResult({'kind': 'none'}), const SystemProxyNone()));
    test('fixed with bypass and PAC flag', () {
      expect(
        parseChannelProxyResult({
          'kind': 'fixed', 'type': 'socks5', 'host': 'h', 'port': 1080,
          'bypass': ['*.corp', 7], 'viaPac': true,
        }),
        const SystemProxyFixed(type: ProxyType.socks5, host: 'h', port: 1080, bypass: ['*.corp'], viaPac: true),
      );
    });
    test('unavailable reason and detail', () {
      expect(
        parseChannelProxyResult({'kind': 'unavailable', 'reason': 'pacFailed', 'detail': 'timeout'}),
        const SystemProxyUnavailable(SystemProxyUnavailableReason.pacFailed, detail: 'timeout'),
      );
    });
    test('malformed answers are platformError', () {
      for (final raw in [null, 'x', {'kind': 'fixed', 'host': 'h'}, {'kind': 'fixed', 'host': '', 'port': 1}, {'kind': 'fixed', 'host': 'h', 'port': 0}, {'kind': '?'}]) {
        expect(parseChannelProxyResult(raw), isA<SystemProxyUnavailable>(), reason: '$raw');
      }
    });
  });

  test('resolve sends the probe url and maps a platform exception', () async {
    const channel = MethodChannel('app.submersion/system_proxy');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Object? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call.arguments;
      throw PlatformException(code: 'boom');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final r = await ChannelSystemProxyResolver().resolve(Uri.parse('https://api.github.com/'));
    expect(seen, {'url': 'https://api.github.com/'});
    expect(r, isA<SystemProxyUnavailable>().having((u) => u.reason, 'reason', SystemProxyUnavailableReason.platformError));
  });

  test('a missing handler is none, not an error', () async {
    final r = await ChannelSystemProxyResolver(channel: const MethodChannel('nobody.home'))
        .resolve(Uri.parse('https://api.github.com/'));
    expect(r, const SystemProxyNone());
  });
}
```

```dart
// test/core/network/proxy/system/linux_proxy_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/linux_proxy_parser.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

void main() {
  group('parseProxyEnvironment', () {
    test('no variables is null', () => expect(parseProxyEnvironment({}), isNull));
    test('https_proxy wins, lowercase before uppercase', () {
      final r = parseProxyEnvironment({
        'HTTPS_PROXY': 'http://upper:1',
        'https_proxy': 'http://lower:2',
        'http_proxy': 'http://plain:3',
      });
      expect(r, const SystemProxyFixed(type: ProxyType.http, host: 'lower', port: 2));
    });
    test('falls back to http_proxy then all_proxy', () {
      expect(parseProxyEnvironment({'http_proxy': 'proxy:3128'}),
          const SystemProxyFixed(type: ProxyType.http, host: 'proxy', port: 3128));
      expect(parseProxyEnvironment({'ALL_PROXY': 'socks5h://s:1080'}),
          const SystemProxyFixed(type: ProxyType.socks5, host: 's', port: 1080));
    });
    test('credentials, default ports and no_proxy', () {
      final r = parseProxyEnvironment({
        'https_proxy': 'http://ann:p%40ss@corp',
        'no_proxy': 'localhost, .corp ,10.0.0.0/8',
      });
      expect(r, const SystemProxyFixed(
        type: ProxyType.http, host: 'corp', port: 80,
        bypass: ['localhost', '.corp', '10.0.0.0/8'],
        username: 'ann', password: 'p@ss',
      ));
      expect(parseProxyEnvironment({'all_proxy': 'socks5://s'}),
          const SystemProxyFixed(type: ProxyType.socks5, host: 's', port: 1080));
    });
    test('an unusable value is ignored', () {
      expect(parseProxyEnvironment({'https_proxy': 'ftp://x:1'}), isNull);
      expect(parseProxyEnvironment({'https_proxy': '  '}), isNull);
    });
  });

  test('gvariant strings and lists', () {
    expect(parseGVariantString("'manual'\n"), 'manual');
    expect(parseGVariantString(null), isNull);
    expect(parseGVariantStringList("['localhost', '127.0.0.0/8', '::1']"), ['localhost', '127.0.0.0/8', '::1']);
    expect(parseGVariantStringList('@as []'), isEmpty);
  });
}
```

```dart
// test/core/network/proxy/system/linux_system_proxy_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/linux_system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

void main() {
  final probe = Uri.parse('https://api.github.com/');

  Future<String?> Function(String, String) gsettings(Map<String, String> values) =>
      (schema, key) async => values['$schema $key'];

  test('environment wins over gsettings', () async {
    final r = await LinuxSystemProxyResolver(
      environment: {'https_proxy': 'http://env:1'},
      gsettings: gsettings({'org.gnome.system.proxy mode': "'manual'"}),
    ).resolve(probe);
    expect((r as SystemProxyFixed).host, 'env');
  });

  test('gnome manual prefers https, then socks', () async {
    final r = await LinuxSystemProxyResolver(
      environment: const {},
      gsettings: gsettings({
        'org.gnome.system.proxy mode': "'manual'",
        'org.gnome.system.proxy.https host': "''",
        'org.gnome.system.proxy.https port': '0',
        'org.gnome.system.proxy.socks host': "'s'",
        'org.gnome.system.proxy.socks port': '1080',
        'org.gnome.system.proxy ignore-hosts': "['localhost']",
      }),
    ).resolve(probe);
    expect(r, const SystemProxyFixed(type: ProxyType.socks5, host: 's', port: 1080, bypass: ['localhost']));
  });

  test('gnome auto is pacUnsupported, none and missing gsettings are none', () async {
    expect(
      await LinuxSystemProxyResolver(environment: const {}, gsettings: gsettings({'org.gnome.system.proxy mode': "'auto'"})).resolve(probe),
      const SystemProxyUnavailable(SystemProxyUnavailableReason.pacUnsupported),
    );
    expect(
      await LinuxSystemProxyResolver(environment: const {}, gsettings: gsettings({})).resolve(probe),
      const SystemProxyNone(),
    );
  });
}
```

```dart
// test/core/network/proxy/system/windows_proxy_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/windows_proxy_parser.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

void main() {
  group('pickWindowsProxy', () {
    test('plain host:port is http', () {
      expect(pickWindowsProxy('proxy:8080'), (type: ProxyType.http, host: 'proxy', port: 8080));
    });
    test('per-scheme list prefers https, then http, then socks', () {
      expect(pickWindowsProxy('http=a:1;https=b:2;socks=c:3'), (type: ProxyType.http, host: 'b', port: 2));
      expect(pickWindowsProxy('http=a:1 socks=c:3'), (type: ProxyType.http, host: 'a', port: 1));
      expect(pickWindowsProxy('socks=c:3'), (type: ProxyType.socks5, host: 'c', port: 3));
    });
    test('scheme prefix and missing port', () {
      expect(pickWindowsProxy('http://proxy:3128'), (type: ProxyType.http, host: 'proxy', port: 3128));
      expect(pickWindowsProxy('proxy'), (type: ProxyType.http, host: 'proxy', port: 80));
      expect(pickWindowsProxy(''), isNull);
    });
  });

  group('parseWindowsProxy', () {
    test('static proxy with bypass list', () {
      final r = parseWindowsProxy(const RawWindowsProxy(
        autoDetect: false, staticProxy: 'proxy:8080', staticBypass: '<local>;*.corp',
      ));
      expect(r, const SystemProxyFixed(type: ProxyType.http, host: 'proxy', port: 8080, bypass: ['<local>', '*.corp']));
    });
    test('nothing configured is none', () {
      expect(parseWindowsProxy(const RawWindowsProxy(autoDetect: false)), const SystemProxyNone());
    });
    test('PAC success is viaPac', () {
      final r = parseWindowsProxy(const RawWindowsProxy(
        autoDetect: true, pacAttempted: true, pacSucceeded: true, pacProxy: 'pac:3128',
      ));
      expect(r, const SystemProxyFixed(type: ProxyType.http, host: 'pac', port: 3128, viaPac: true));
    });
    test('PAC saying direct is none', () {
      expect(parseWindowsProxy(const RawWindowsProxy(autoDetect: true, pacAttempted: true, pacSucceeded: true)), const SystemProxyNone());
    });
    test('auto-detect failing with no WPAD server is none (home PCs)', () {
      expect(parseWindowsProxy(const RawWindowsProxy(autoDetect: true, pacAttempted: true, pacSucceeded: false)), const SystemProxyNone());
    });
    test('a configured PAC url failing is pacFailed, unless a static proxy exists', () {
      expect(
        parseWindowsProxy(const RawWindowsProxy(autoDetect: false, autoConfigUrl: 'http://wpad/p.pac', pacAttempted: true, pacSucceeded: false)),
        isA<SystemProxyUnavailable>().having((u) => u.reason, 'reason', SystemProxyUnavailableReason.pacFailed),
      );
      expect(
        parseWindowsProxy(const RawWindowsProxy(autoDetect: false, autoConfigUrl: 'http://wpad/p.pac', pacAttempted: true, pacSucceeded: false, staticProxy: 's:1')),
        const SystemProxyFixed(type: ProxyType.http, host: 's', port: 1),
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/network/proxy/system/`
Expected: FAIL, files missing.

- [ ] **Step 3: Implement the interface and channel resolver**

```dart
// lib/core/network/proxy/system/system_proxy_resolver.dart
import 'dart:io';

import 'package:submersion/core/network/proxy/system/channel_system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system/linux_system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system/windows_system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

/// The URL system detection and the connection test ask about: the update
/// check's host, a public name every network that lets the app work at all
/// must reach. A PAC script's answer for it is applied to all internet
/// traffic (the spec's resolve-once decision).
final Uri proxyProbeUrl = Uri.parse('https://api.github.com/');

/// Asks the operating system which proxy to use for [probe].
abstract class SystemProxyResolver {
  /// Never throws; failures come back as SystemProxyUnavailable.
  Future<SystemProxyResult> resolve(Uri probe);

  static SystemProxyResolver forPlatform() {
    if (Platform.isWindows) return WindowsSystemProxyResolver();
    if (Platform.isLinux) return LinuxSystemProxyResolver();
    return ChannelSystemProxyResolver();
  }
}
```

```dart
// lib/core/network/proxy/system/channel_system_proxy_resolver.dart
import 'package:flutter/services.dart';

import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

/// macOS, iOS and Android: the native SystemProxyHandler answers over
/// `app.submersion/system_proxy`. Parsing lives here, where it is testable.
class ChannelSystemProxyResolver implements SystemProxyResolver {
  ChannelSystemProxyResolver({
    MethodChannel channel = const MethodChannel('app.submersion/system_proxy'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<SystemProxyResult> resolve(Uri probe) async {
    try {
      final raw = await _channel.invokeMethod<Object?>('resolve', {
        'url': probe.toString(),
      });
      return parseChannelProxyResult(raw);
    } on MissingPluginException {
      return const SystemProxyNone();
    } on PlatformException catch (e) {
      return SystemProxyUnavailable(
        SystemProxyUnavailableReason.platformError,
        detail: e.message ?? e.code,
      );
    }
  }
}

SystemProxyResult parseChannelProxyResult(Object? raw) {
  const malformed = SystemProxyUnavailable(
    SystemProxyUnavailableReason.platformError,
    detail: 'Unexpected answer from the system proxy handler',
  );
  if (raw is! Map) return malformed;
  switch (raw['kind']) {
    case 'none':
      return const SystemProxyNone();
    case 'fixed':
      final host = raw['host'];
      final port = raw['port'];
      if (host is! String || host.isEmpty) return malformed;
      if (port is! int || port < 1 || port > 65535) return malformed;
      final bypass = raw['bypass'];
      return SystemProxyFixed(
        type: raw['type'] == 'socks5' ? ProxyType.socks5 : ProxyType.http,
        host: host,
        port: port,
        bypass: bypass is List ? bypass.whereType<String>().toList() : const [],
        viaPac: raw['viaPac'] == true,
      );
    case 'unavailable':
      final reason = SystemProxyUnavailableReason.values
          .where((r) => r.name == raw['reason'])
          .firstOrNull;
      return SystemProxyUnavailable(
        reason ?? SystemProxyUnavailableReason.platformError,
        detail: raw['detail'] is String ? raw['detail'] as String : null,
      );
    default:
      return malformed;
  }
}
```

- [ ] **Step 4: Implement the Linux parser and resolver**

```dart
// lib/core/network/proxy/system/linux_proxy_parser.dart
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

/// The proxy named by the curl-style environment variables, or null.
/// Order: https_proxy, HTTPS_PROXY, http_proxy, HTTP_PROXY, all_proxy,
/// ALL_PROXY; no_proxy / NO_PROXY is the bypass list.
SystemProxyResult? parseProxyEnvironment(Map<String, String> env) {
  const keys = [
    'https_proxy', 'HTTPS_PROXY', 'http_proxy', 'HTTP_PROXY',
    'all_proxy', 'ALL_PROXY',
  ];
  for (final key in keys) {
    final value = env[key]?.trim();
    if (value == null || value.isEmpty) continue;
    final parsed = _parseProxyUrl(value);
    if (parsed == null) continue;
    return SystemProxyFixed(
      type: parsed.type,
      host: parsed.host,
      port: parsed.port,
      bypass: parseNoProxy(env['no_proxy'] ?? env['NO_PROXY']),
      username: parsed.username,
      password: parsed.password,
    );
  }
  return null;
}

List<String> parseNoProxy(String? value) => (value ?? '')
    .split(',')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

({ProxyType type, String host, int port, String? username, String? password})?
_parseProxyUrl(String value) {
  final withScheme = value.contains('://') ? value : 'http://$value';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) return null;
  final ProxyType type;
  final int defaultPort;
  switch (uri.scheme) {
    case 'http':
    case 'https':
      type = ProxyType.http;
      defaultPort = 80;
    case 'socks5':
    case 'socks5h':
    case 'socks':
      type = ProxyType.socks5;
      defaultPort = 1080;
    default:
      return null;
  }
  String? user;
  String? pass;
  if (uri.userInfo.isNotEmpty) {
    final i = uri.userInfo.indexOf(':');
    user = Uri.decodeComponent(i < 0 ? uri.userInfo : uri.userInfo.substring(0, i));
    pass = i < 0 ? null : Uri.decodeComponent(uri.userInfo.substring(i + 1));
  }
  return (
    type: type,
    host: uri.host,
    port: uri.hasPort ? uri.port : defaultPort,
    username: user,
    password: pass,
  );
}

/// `'manual'` (gsettings' printed GVariant string) to `manual`.
String? parseGVariantString(String? out) {
  final t = out?.trim();
  if (t == null || t.length < 2) return null;
  if (t.startsWith("'") && t.endsWith("'")) return t.substring(1, t.length - 1);
  return t;
}

/// `['a', 'b']` or `@as []` to a list.
List<String> parseGVariantStringList(String? out) {
  final t = out?.trim() ?? '';
  final start = t.indexOf('[');
  final end = t.lastIndexOf(']');
  if (start < 0 || end <= start) return const [];
  return RegExp(r"'([^']*)'")
      .allMatches(t.substring(start + 1, end))
      .map((m) => m.group(1)!)
      .where((e) => e.isNotEmpty)
      .toList();
}
```

```dart
// lib/core/network/proxy/system/linux_system_proxy_resolver.dart
import 'dart:io';

import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/linux_proxy_parser.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

typedef GSettingsReader = Future<String?> Function(String schema, String key);

/// Linux: the environment variables first (as curl reads them), then GNOME's
/// proxy settings. There is no PAC engine here, so GNOME's automatic mode is
/// reported as unsupported.
class LinuxSystemProxyResolver implements SystemProxyResolver {
  LinuxSystemProxyResolver({
    Map<String, String>? environment,
    GSettingsReader? gsettings,
  }) : _environment = environment ?? Platform.environment,
       _gsettings = gsettings ?? _runGSettings;

  final Map<String, String> _environment;
  final GSettingsReader _gsettings;

  static Future<String?> _runGSettings(String schema, String key) async {
    try {
      final r = await Process.run('gsettings', ['get', schema, key]);
      return r.exitCode == 0 ? r.stdout as String : null;
    } on ProcessException {
      return null;
    }
  }

  @override
  Future<SystemProxyResult> resolve(Uri probe) async {
    final fromEnv = parseProxyEnvironment(_environment);
    if (fromEnv != null) return fromEnv;
    try {
      const base = 'org.gnome.system.proxy';
      final mode = parseGVariantString(await _gsettings(base, 'mode'));
      if (mode == 'auto') {
        return const SystemProxyUnavailable(
          SystemProxyUnavailableReason.pacUnsupported,
        );
      }
      if (mode != 'manual') return const SystemProxyNone();
      final bypass = parseGVariantStringList(
        await _gsettings(base, 'ignore-hosts'),
      );
      for (final (schema, type) in [
        ('$base.https', ProxyType.http),
        ('$base.http', ProxyType.http),
        ('$base.socks', ProxyType.socks5),
      ]) {
        final host = parseGVariantString(await _gsettings(schema, 'host'));
        final port = int.tryParse((await _gsettings(schema, 'port'))?.trim() ?? '');
        if (host != null && host.isNotEmpty && port != null && port > 0) {
          return SystemProxyFixed(type: type, host: host, port: port, bypass: bypass);
        }
      }
      return const SystemProxyNone();
    } catch (e) {
      return SystemProxyUnavailable(
        SystemProxyUnavailableReason.platformError,
        detail: '$e',
      );
    }
  }
}
```

- [ ] **Step 5: Implement the Windows parser**

```dart
// lib/core/network/proxy/system/windows_proxy_parser.dart
import 'package:flutter/foundation.dart';

import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

/// What WinHTTP reported, copied out of native memory so parsing is testable.
@immutable
class RawWindowsProxy {
  const RawWindowsProxy({
    required this.autoDetect,
    this.autoConfigUrl,
    this.staticProxy,
    this.staticBypass,
    this.pacAttempted = false,
    this.pacSucceeded = false,
    this.pacProxy,
    this.pacBypass,
  });

  final bool autoDetect;
  final String? autoConfigUrl;
  final String? staticProxy;
  final String? staticBypass;
  final bool pacAttempted;
  final bool pacSucceeded;

  /// WinHttpGetProxyForUrl's proxy list; null when it chose direct.
  final String? pacProxy;
  final String? pacBypass;
}

SystemProxyResult parseWindowsProxy(RawWindowsProxy raw) {
  if (raw.pacAttempted && raw.pacSucceeded) {
    final picked = raw.pacProxy == null ? null : pickWindowsProxy(raw.pacProxy!);
    if (picked == null) return const SystemProxyNone();
    return SystemProxyFixed(
      type: picked.type,
      host: picked.host,
      port: picked.port,
      bypass: _bypass(raw.pacBypass ?? raw.staticBypass),
      viaPac: true,
    );
  }
  final static = raw.staticProxy == null ? null : pickWindowsProxy(raw.staticProxy!);
  if (static != null) {
    return SystemProxyFixed(
      type: static.type,
      host: static.host,
      port: static.port,
      bypass: _bypass(raw.staticBypass),
    );
  }
  // Auto-detect alone failing means no WPAD server: the default on home
  // PCs, where "Automatically detect settings" is on. That is "no proxy".
  // A PAC URL someone configured failing is a real problem worth showing.
  final configured = raw.autoConfigUrl?.trim().isNotEmpty ?? false;
  if (raw.pacAttempted && configured) {
    return const SystemProxyUnavailable(SystemProxyUnavailableReason.pacFailed);
  }
  return const SystemProxyNone();
}

List<String> _bypass(String? value) => (value ?? '')
    .split(RegExp(r'[;\s]+'))
    .where((e) => e.isNotEmpty)
    .toList();

/// Picks one proxy from a WinHTTP list such as `proxy:8080` or
/// `http=a:1;https=b:2;socks=c:3`: https first, then http or unlabelled,
/// then socks.
({ProxyType type, String host, int port})? pickWindowsProxy(String list) {
  final entries = list.split(RegExp(r'[;\s]+')).where((e) => e.isNotEmpty);
  String? https;
  String? http;
  String? socks;
  for (final entry in entries) {
    final eq = entry.indexOf('=');
    if (eq < 0) {
      http ??= entry;
      continue;
    }
    final scheme = entry.substring(0, eq).toLowerCase();
    final value = entry.substring(eq + 1);
    if (scheme == 'https') https ??= value;
    if (scheme == 'http') http ??= value;
    if (scheme == 'socks') socks ??= value;
  }
  final chosen = https ?? http;
  if (chosen != null) return _endpoint(chosen, ProxyType.http, 80);
  if (socks != null) return _endpoint(socks, ProxyType.socks5, 1080);
  return null;
}

({ProxyType type, String host, int port})? _endpoint(
  String value,
  ProxyType type,
  int defaultPort,
) {
  final uri = Uri.tryParse(value.contains('://') ? value : 'x://$value');
  if (uri == null || uri.host.isEmpty) return null;
  return (type: type, host: uri.host, port: uri.hasPort ? uri.port : defaultPort);
}
```

Create a stub `lib/core/network/proxy/system/windows_system_proxy_resolver.dart` for this task (so `forPlatform` compiles) with `class WindowsSystemProxyResolver implements SystemProxyResolver { @override Future<SystemProxyResult> resolve(Uri probe) async => const SystemProxyNone(); }`; Task 7 replaces its body.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/core/network/proxy/system/`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/core/network/proxy/system test/core/network/proxy/system
git commit -m "feat(network): parse system proxy settings for every platform"
```

---

### Task 7: Windows WinHTTP resolver (FFI)

**Files:**
- Modify: `lib/core/network/proxy/system/windows_system_proxy_resolver.dart`
- Test: `test/core/network/proxy/system/windows_system_proxy_resolver_test.dart`

**Interfaces:**
- Consumes: `RawWindowsProxy`, `parseWindowsProxy` (Task 6).
- Produces: `WindowsSystemProxyResolver({Future<RawWindowsProxy> Function(String url)? query, Duration timeout = const Duration(seconds: 5)})`.

- [ ] **Step 1: Write the failing test** (the FFI itself only runs on Windows; the test drives the injected query)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/windows_proxy_parser.dart';
import 'package:submersion/core/network/proxy/system/windows_system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

void main() {
  final probe = Uri.parse('https://api.github.com/');

  test('passes the probe url and parses the answer', () async {
    String? asked;
    final r = await WindowsSystemProxyResolver(query: (url) async {
      asked = url;
      return const RawWindowsProxy(autoDetect: false, staticProxy: 'p:1');
    }).resolve(probe);
    expect(asked, 'https://api.github.com/');
    expect(r, const SystemProxyFixed(type: ProxyType.http, host: 'p', port: 1));
  });

  test('a slow WinHTTP answer is pacFailed after the timeout', () async {
    final r = await WindowsSystemProxyResolver(
      query: (_) => Future.delayed(const Duration(seconds: 1), () => const RawWindowsProxy(autoDetect: false)),
      timeout: const Duration(milliseconds: 20),
    ).resolve(probe);
    expect(r, isA<SystemProxyUnavailable>().having((u) => u.reason, 'reason', SystemProxyUnavailableReason.pacFailed));
  });

  test('a thrown error is platformError', () async {
    final r = await WindowsSystemProxyResolver(query: (_) async => throw StateError('dll')).resolve(probe);
    expect(r, isA<SystemProxyUnavailable>().having((u) => u.reason, 'reason', SystemProxyUnavailableReason.platformError));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/network/proxy/system/windows_system_proxy_resolver_test.dart`
Expected: FAIL (stub ignores `query`).

- [ ] **Step 3: Implement**

```dart
// lib/core/network/proxy/system/windows_system_proxy_resolver.dart
import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system/windows_proxy_parser.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

/// Windows: WinHTTP over FFI, in the style of windows_root_store.dart.
/// WinHttpGetProxyForUrl blocks (WPAD lookups, PAC download), so the query
/// runs in a short-lived isolate with a Dart-side deadline.
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

final class _IeProxyConfig extends Struct {
  @Int32()
  external int fAutoDetect;
  external Pointer<Utf16> lpszAutoConfigUrl;
  external Pointer<Utf16> lpszProxy;
  external Pointer<Utf16> lpszProxyBypass;
}

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

/// Runs in a background isolate on Windows only.
RawWindowsProxy queryWinHttp(String url) {
  final winhttp = DynamicLibrary.open('winhttp.dll');
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final getIeConfig = winhttp.lookupFunction<
    Int32 Function(Pointer<_IeProxyConfig>),
    int Function(Pointer<_IeProxyConfig>)
  >('WinHttpGetIEProxyConfigForCurrentUser');
  final open = winhttp.lookupFunction<
    Pointer<Void> Function(Pointer<Utf16>, Uint32, Pointer<Utf16>, Pointer<Utf16>, Uint32),
    Pointer<Void> Function(Pointer<Utf16>, int, Pointer<Utf16>, Pointer<Utf16>, int)
  >('WinHttpOpen');
  final getProxyForUrl = winhttp.lookupFunction<
    Int32 Function(Pointer<Void>, Pointer<Utf16>, Pointer<_AutoProxyOptions>, Pointer<_ProxyInfo>),
    int Function(Pointer<Void>, Pointer<Utf16>, Pointer<_AutoProxyOptions>, Pointer<_ProxyInfo>)
  >('WinHttpGetProxyForUrl');
  final closeHandle = winhttp.lookupFunction<
    Int32 Function(Pointer<Void>),
    int Function(Pointer<Void>)
  >('WinHttpCloseHandle');
  final globalFree = kernel32.lookupFunction<
    Pointer<Void> Function(Pointer<Void>),
    Pointer<Void> Function(Pointer<Void>)
  >('GlobalFree');

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
        ..dwFlags = (autoDetect ? _autoDetect : 0) | (configUrl != null ? _configUrl : 0)
        ..dwAutoDetectFlags = autoDetect ? (_detectDhcp | _detectDnsA) : 0
        ..lpszAutoConfigUrl = configUrl == null ? nullptr : configUrl.toNativeUtf16(allocator: arena)
        ..lpvReserved = nullptr
        ..dwReserved = 0
        ..fAutoLogonIfChallenged = 1;
      final info = arena<_ProxyInfo>();
      final ok = getProxyForUrl(session, url.toNativeUtf16(allocator: arena), options, info) != 0;
      final pacProxy = ok ? take(info.ref.lpszProxy) : null;
      final pacBypass = ok ? take(info.ref.lpszProxyBypass) : null;
      return RawWindowsProxy(
        autoDetect: autoDetect,
        autoConfigUrl: configUrl,
        staticProxy: staticProxy,
        staticBypass: staticBypass,
        pacAttempted: true,
        pacSucceeded: ok,
        pacProxy: ok && info.ref.dwAccessType == _accessNamedProxy ? pacProxy : null,
        pacBypass: pacBypass,
      );
    } finally {
      closeHandle(session);
    }
  });
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/network/proxy/system/`
Expected: PASS. `flutter analyze lib/core/network` clean (FFI compiles on every host).

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/proxy/system/windows_system_proxy_resolver.dart test/core/network/proxy/system/windows_system_proxy_resolver_test.dart
git commit -m "feat(network): read the Windows proxy and PAC result through WinHTTP"
```

---

### Task 8: Native handlers (macOS, iOS, Android)

**Files:**
- Create: `macos/Runner/SystemProxyHandler.swift`, `ios/Runner/SystemProxyHandler.swift`, `android/app/src/main/kotlin/app/submersion/SystemProxyHandler.kt`
- Modify: `macos/Runner/MainFlutterWindow.swift` (or wherever macOS handlers register; follow `LocalMediaHandler`), `ios/Runner/AppDelegate.swift` (follow `DeviceNameHandler` lines 12 and 42-43), `android/app/src/main/kotlin/app/submersion/MainActivity.kt` (follow `DeviceNameHandler` lines 12 and 31-33), `macos/Runner.xcodeproj/project.pbxproj` and `ios/Runner.xcodeproj/project.pbxproj` (four entries each, mirroring the `DeviceNameHandler.swift` / `LocalMediaHandler.swift` PBXBuildFile, PBXFileReference, group child and Sources phase lines with fresh unique 24-hex ids)

**Interfaces:**
- Consumes: the channel contract from Task 6.

- [ ] **Step 1: macOS handler** (iOS file identical except `import Flutter` / `import UIKit` instead of `import FlutterMacOS` / `import Cocoa`, and iOS has no `ExceptionsList`, which the code tolerates)

```swift
import Cocoa
import FlutterMacOS
import CFNetwork

/// Tells Dart which proxy the OS would use for a URL (issue #3217).
///
/// Methods (channel: app.submersion/system_proxy):
///   - resolve({url}) -> Dictionary
///       {kind: "none"}
///       {kind: "fixed", type: "http"|"socks5", host, port, bypass, viaPac}
///       {kind: "unavailable", reason: "pacFailed", detail}
///
/// PAC scripts are evaluated with CFNetwork on a background thread's run
/// loop, capped at 5 seconds. Parsing and fallback live Dart-side in
/// ChannelSystemProxyResolver.
class SystemProxyHandler: NSObject {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "app.submersion/system_proxy",
            binaryMessenger: messenger
        )
        super.init()
        channel.setMethodCallHandler(handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "resolve" else {
            result(FlutterMethodNotImplemented)
            return
        }
        guard let args = call.arguments as? [String: Any],
              let text = args["url"] as? String,
              let url = URL(string: text) else {
            result(FlutterError(code: "bad_args", message: "url required", details: nil))
            return
        }
        Thread.detachNewThread {
            let answer = SystemProxyHandler.resolve(url: url)
            DispatchQueue.main.async { result(answer) }
        }
    }

    static func resolve(url: URL) -> [String: Any] {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() else {
            return ["kind": "none"]
        }
        let bypass = ((settings as NSDictionary)["ExceptionsList"] as? [String]) ?? []
        let proxies = CFNetworkCopyProxiesForURL(url as CFURL, settings)
            .takeRetainedValue() as? [[String: Any]] ?? []
        return firstUsable(proxies, url: url, bypass: bypass, viaPac: false)
    }

    private static func firstUsable(
        _ proxies: [[String: Any]], url: URL, bypass: [String], viaPac: Bool
    ) -> [String: Any] {
        for proxy in proxies {
            guard let type = proxy[kCFProxyTypeKey as String] as? String else { continue }
            switch type {
            case kCFProxyTypeNone as String:
                return ["kind": "none"]
            case kCFProxyTypeHTTP as String, kCFProxyTypeHTTPS as String,
                 kCFProxyTypeSOCKS as String:
                guard let host = proxy[kCFProxyHostNameKey as String] as? String,
                      let port = (proxy[kCFProxyPortNumberKey as String] as? NSNumber)?.intValue
                else { continue }
                return [
                    "kind": "fixed",
                    "type": type == (kCFProxyTypeSOCKS as String) ? "socks5" : "http",
                    "host": host, "port": port, "bypass": bypass, "viaPac": viaPac,
                ]
            case kCFProxyTypeAutoConfigurationURL as String:
                guard let pac = proxy[kCFProxyAutoConfigurationURLKey as String] else { continue }
                return runPac(url: url, bypass: bypass) { cb, context in
                    CFNetworkExecuteProxyAutoConfigurationURL(
                        pac as! CFURL, url as CFURL, cb, context
                    ).takeRetainedValue()
                }
            case kCFProxyTypeAutoConfigurationJavaScript as String:
                guard let script = proxy[kCFProxyAutoConfigurationJavaScriptKey as String] as? String
                else { continue }
                return runPac(url: url, bypass: bypass) { cb, context in
                    CFNetworkExecuteProxyAutoConfigurationScript(
                        script as CFString, url as CFURL, cb, context
                    ).takeRetainedValue()
                }
            default:
                continue
            }
        }
        return ["kind": "none"]
    }

    private final class PacBox {
        var proxies: [[String: Any]]?
        var error: String?
        var done = false
    }

    private static func runPac(
        url: URL, bypass: [String],
        start: (CFProxyAutoConfigurationResultCallback,
                UnsafeMutablePointer<CFStreamClientContext>) -> CFRunLoopSource
    ) -> [String: Any] {
        let box = PacBox()
        var context = CFStreamClientContext(
            version: 0, info: Unmanaged.passUnretained(box).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        let callback: CFProxyAutoConfigurationResultCallback = { info, proxies, error in
            let box = Unmanaged<PacBox>.fromOpaque(info).takeUnretainedValue()
            if let error = error {
                box.error = CFErrorCopyDescription(error) as String
            } else {
                box.proxies = proxies as? [[String: Any]]
            }
            box.done = true
            CFRunLoopStop(CFRunLoopGetCurrent())
        }
        let source = start(callback, &context)
        let runLoop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(runLoop, source, .defaultMode)
        let deadline = Date().addingTimeInterval(5)
        while !box.done && Date() < deadline {
            _ = CFRunLoopRunInMode(.defaultMode, deadline.timeIntervalSinceNow, true)
        }
        CFRunLoopRemoveSource(runLoop, source, .defaultMode)
        if !box.done {
            return ["kind": "unavailable", "reason": "pacFailed",
                    "detail": "Timed out evaluating the proxy auto-configuration script"]
        }
        if let error = box.error {
            return ["kind": "unavailable", "reason": "pacFailed", "detail": error]
        }
        return firstUsable(box.proxies ?? [], url: url, bypass: bypass, viaPac: true)
    }
}
```

- [ ] **Step 2: Android handler** (minSdk is 26, so `getDefaultProxy` is always available)

```kotlin
package app.submersion

import android.content.Context
import android.net.ConnectivityManager
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

/**
 * Tells Dart which proxy Android would use (issue #3217).
 *
 * Methods (channel: app.submersion/system_proxy):
 *   - resolve({url}): Map, same contract as the Apple handlers.
 *
 * A Wi-Fi network configured with a PAC URL is served by Android's local
 * PAC proxy, reported here as localhost:<port>, so it needs no PAC engine.
 * If a device reports only the PAC URL, Dart is told it is unsupported.
 */
class SystemProxyHandler(
    private val context: Context,
    private val channel: MethodChannel,
) : MethodCallHandler {

    companion object {
        const val CHANNEL = "app.submersion/system_proxy"
    }

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "resolve") {
            result.notImplemented()
            return
        }
        try {
            result.success(resolve())
        } catch (e: Exception) {
            result.error("system_proxy", e.message, null)
        }
    }

    private fun resolve(): Map<String, Any?> {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val info = cm.defaultProxy ?: return mapOf("kind" to "none")
        val hasPac = info.pacFileUrl != null && info.pacFileUrl != Uri.EMPTY
        val host = info.host
        if (host.isNullOrEmpty() || info.port <= 0) {
            return if (hasPac) {
                mapOf("kind" to "unavailable", "reason" to "pacUnsupported")
            } else {
                mapOf("kind" to "none")
            }
        }
        return mapOf(
            "kind" to "fixed",
            "type" to "http",
            "host" to host,
            "port" to info.port,
            "bypass" to (info.exclusionList?.toList() ?: emptyList<String>()),
            "viaPac" to hasPac,
        )
    }
}
```

- [ ] **Step 3: Register the handlers** in `ios/Runner/AppDelegate.swift`, the macOS registration site and `MainActivity.kt`, copying the `DeviceNameHandler` lines (a stored property plus construction with the registrar's or engine's messenger). Add the Swift files to both Xcode projects (four pbxproj entries each).

- [ ] **Step 4: Verify they compile**

Run (from a scratchpad script, since a bare `build` token in a Bash command is refused): `flutter build macos --debug` and `flutter build apk --debug`. iOS: `flutter build ios --debug --no-codesign --simulator`.
Expected: all three succeed.

- [ ] **Step 5: Verify detection on this Mac.** This Mac has no system proxy, so the expected answer is none. Check it end to end in Task 15 through the Network page's status line ("No proxy configured on this device") on the macOS debug app. Do not change macOS network settings to exercise PAC; list PAC and the other platforms as unverified in the PR.

- [ ] **Step 6: Commit**

```bash
git add macos/Runner ios/Runner android/app/src/main/kotlin/app/submersion macos/Runner.xcodeproj/project.pbxproj ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat(network): report the OS proxy from macOS, iOS and Android"
```

---

### Task 9: ProxyController and refresh triggers

**Files:**
- Create: `lib/core/network/proxy/proxy_controller.dart`, `lib/core/network/proxy/proxy_refresh_triggers.dart`
- Test: `test/core/network/proxy/proxy_controller_test.dart`, `test/core/network/proxy/proxy_refresh_triggers_test.dart`

**Interfaces:**
- Consumes: `ProxySettingsStore`, `SystemProxyResolver`, `proxyProbeUrl`, `EffectiveProxy.resolve`, `LoggerService`.
- Produces:
  - `class ProxyControllerState { ProxySettings settings; SystemProxyResult? system; bool detecting; EffectiveProxy effective; }`
  - `class ProxyController { ProxyController({required SystemProxyResolver resolver, Uri? probeUrl}); EffectiveProxy get current; ProxyControllerState get state; String? get manualPassword; Stream<ProxyControllerState> get changes; Future<void> initialize(ProxySettingsStore store, {Duration startupTimeout = const Duration(seconds: 3)}); Future<void> saveSettings(ProxySettings settings, {String? password, bool updatePassword = false}); Future<void> refresh(); void dispose(); }`
  - `class ProxyRefreshTriggers { ProxyRefreshTriggers(ProxyController controller, {Stream<Object?>? networkChanges, bool listenToLifecycle = true}); void dispose(); }`

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/network/proxy/proxy_controller_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/proxy_settings_store.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

import '../../../support/fake_keychain_storage.dart';

class _Resolver implements SystemProxyResolver {
  final answers = <Completer<SystemProxyResult>>[];
  int calls = 0;
  @override
  Future<SystemProxyResult> resolve(Uri probe) {
    calls++;
    final c = Completer<SystemProxyResult>();
    answers.add(c);
    return c.future;
  }
}

const _fixed = SystemProxyFixed(type: ProxyType.http, host: 'corp', port: 8080);

void main() {
  late ProxySettingsStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = ProxySettingsStore(await SharedPreferences.getInstance(), storage: InMemoryKeychain());
  });

  test('starts direct, then system mode applies the detected proxy', () async {
    final r = _Resolver();
    final c = ProxyController(resolver: r);
    addTearDown(c.dispose);
    expect(c.current.isDirect, isTrue);
    final init = c.initialize(store);
    r.answers.single.complete(_fixed);
    await init;
    expect(c.current.endpoint, 'corp:8080');
    expect(c.state.system, _fixed);
    expect(c.state.detecting, isFalse);
  });

  test('startup stops waiting after the timeout and applies the late answer', () async {
    final r = _Resolver();
    final c = ProxyController(resolver: r);
    addTearDown(c.dispose);
    await c.initialize(store, startupTimeout: const Duration(milliseconds: 10));
    expect(c.current.isDirect, isTrue);
    expect(c.state.detecting, isTrue);
    r.answers.single.complete(_fixed);
    await pumpEventQueue();
    expect(c.current.endpoint, 'corp:8080');
  });

  test('a slow answer never overwrites a newer choice', () async {
    final r = _Resolver();
    final c = ProxyController(resolver: r);
    addTearDown(c.dispose);
    await c.initialize(store, startupTimeout: const Duration(milliseconds: 10));
    await c.saveSettings(ProxySettings.defaults.copyWith(mode: ProxyMode.none));
    r.answers.first.complete(_fixed);
    await pumpEventQueue();
    expect(c.current.isDirect, isTrue);
    expect(c.state.settings.mode, ProxyMode.none);
  });

  test('a stale refresh answer is dropped when a newer refresh started', () async {
    final r = _Resolver();
    final c = ProxyController(resolver: r);
    addTearDown(c.dispose);
    final init = c.initialize(store);
    r.answers[0].complete(const SystemProxyNone());
    await init;
    final first = c.refresh();
    final second = c.refresh();
    r.answers[2].complete(_fixed);
    r.answers[1].complete(const SystemProxyNone());
    await Future.wait([first, second]);
    expect(c.current.endpoint, 'corp:8080');
  });

  test('manual mode loads the password and never asks the OS', () async {
    await store.save(const ProxySettings(mode: ProxyMode.manual, type: ProxyType.http, host: 'm', port: 3128, username: 'ann'));
    await store.savePassword('pw');
    final r = _Resolver();
    final c = ProxyController(resolver: r);
    addTearDown(c.dispose);
    await c.initialize(store);
    expect(r.calls, 0);
    expect(c.current.username, 'ann');
    expect(c.current.password, 'pw');
    expect(c.manualPassword, 'pw');
  });

  test('saveSettings persists, updates the password only when asked, and emits', () async {
    final r = _Resolver();
    final c = ProxyController(resolver: r);
    addTearDown(c.dispose);
    final init = c.initialize(store);
    r.answers.single.complete(const SystemProxyNone());
    await init;
    final emitted = <ProxyControllerState>[];
    final sub = c.changes.listen(emitted.add);
    addTearDown(sub.cancel);
    const manual = ProxySettings(mode: ProxyMode.manual, type: ProxyType.socks5, host: 's', port: 1080, username: 'u');
    await c.saveSettings(manual, password: 'x', updatePassword: true);
    expect(store.load(), manual);
    expect(await store.loadPassword(), 'x');
    await c.saveSettings(manual.copyWith(host: 't'));
    expect(await store.loadPassword(), 'x');
    await pumpEventQueue();
    expect(emitted.map((s) => s.effective.host), containsAllInOrder(['s', 't']));
    expect(c.current.kind, ProxyKind.socks5);
  });

  test('switching to system mode detects again', () async {
    await store.save(ProxySettings.defaults.copyWith(mode: ProxyMode.none));
    final r = _Resolver();
    final c = ProxyController(resolver: r);
    addTearDown(c.dispose);
    await c.initialize(store);
    expect(r.calls, 0);
    final save = c.saveSettings(ProxySettings.defaults);
    await pumpEventQueue();
    r.answers.single.complete(_fixed);
    await save;
    expect(c.current.endpoint, 'corp:8080');
  });
}
```

```dart
// test/core/network/proxy/proxy_refresh_triggers_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/proxy_refresh_triggers.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

class _Counting implements SystemProxyResolver {
  int calls = 0;
  @override
  Future<SystemProxyResult> resolve(Uri probe) async {
    calls++;
    return const SystemProxyNone();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a network change refreshes; dispose stops listening', () async {
    final r = _Counting();
    final c = ProxyController(resolver: r);
    addTearDown(c.dispose);
    final changes = StreamController<Object?>();
    addTearDown(changes.close);
    final t = ProxyRefreshTriggers(c, networkChanges: changes.stream, listenToLifecycle: false);
    changes.add(null);
    await pumpEventQueue();
    expect(r.calls, 1);
    t.dispose();
    changes.add(null);
    await pumpEventQueue();
    expect(r.calls, 1);
  });
}
```

(`refresh()` on a controller that was never initialized uses the default settings, which are system mode, so it asks the resolver.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/network/proxy/proxy_controller_test.dart test/core/network/proxy/proxy_refresh_triggers_test.dart`
Expected: FAIL, files missing.

- [ ] **Step 3: Implement**

```dart
// lib/core/network/proxy/proxy_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/proxy_settings_store.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';
import 'package:submersion/core/services/logger_service.dart';

@immutable
class ProxyControllerState {
  const ProxyControllerState({
    required this.settings,
    required this.system,
    required this.detecting,
    required this.effective,
  });

  final ProxySettings settings;

  /// The last OS answer; null until one arrives.
  final SystemProxyResult? system;
  final bool detecting;
  final EffectiveProxy effective;
}

/// Holds the proxy snapshot every new connection reads (through
/// AppHttpOverrides) and recomputes it when the settings or the network
/// change. One instance per process, made in main().
///
/// Each recompute takes a generation number; an OS answer that arrives after
/// a newer recompute started is dropped, so a slow PAC lookup can never
/// overwrite a choice the user made after it began.
class ProxyController {
  ProxyController({required SystemProxyResolver resolver, Uri? probeUrl})
    : _resolver = resolver,
      _probe = probeUrl ?? proxyProbeUrl;

  static const _log = LoggerService('Proxy');

  final SystemProxyResolver _resolver;
  final Uri _probe;
  final _changes = StreamController<ProxyControllerState>.broadcast();

  ProxySettingsStore? _store;
  String? _password;
  int _generation = 0;
  var _state = const ProxyControllerState(
    settings: ProxySettings.defaults,
    system: null,
    detecting: false,
    effective: EffectiveProxy.direct(source: ProxySource.system),
  );

  EffectiveProxy get current => _state.effective;
  ProxyControllerState get state => _state;
  String? get manualPassword => _password;
  Stream<ProxyControllerState> get changes => _changes.stream;

  /// Loads the saved choice and, in system mode, asks the OS, waiting at most
  /// [startupTimeout] so a slow PAC server cannot hold up app launch. A late
  /// answer is applied when it arrives.
  Future<void> initialize(
    ProxySettingsStore store, {
    Duration startupTimeout = const Duration(seconds: 3),
  }) async {
    _store = store;
    final settings = store.load();
    _password = await _loadPassword(store, settings);
    final detection = _recompute(settings);
    await detection.timeout(startupTimeout, onTimeout: () {
      _log.info('System proxy detection is slow; starting direct');
    });
  }

  Future<void> saveSettings(
    ProxySettings settings, {
    String? password,
    bool updatePassword = false,
  }) async {
    final store = _store;
    if (store != null) {
      await store.save(settings);
      if (updatePassword) await store.savePassword(password);
    }
    if (updatePassword) _password = password;
    await _recompute(settings);
  }

  Future<void> refresh() => _recompute(_state.settings);

  Future<String?> _loadPassword(ProxySettingsStore store, ProxySettings s) async {
    if (s.mode != ProxyMode.manual || s.username.isEmpty) return null;
    try {
      return await store.loadPassword();
    } catch (e, st) {
      _log.error('Could not read the proxy password', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> _recompute(ProxySettings settings) async {
    final generation = ++_generation;
    if (settings.mode != ProxyMode.system) {
      _apply(settings, _state.system, detecting: false);
      return;
    }
    _apply(settings, _state.system, detecting: true);
    SystemProxyResult result;
    try {
      result = await _resolver.resolve(_probe);
    } catch (e) {
      result = SystemProxyUnavailable(
        SystemProxyUnavailableReason.platformError,
        detail: '$e',
      );
    }
    if (generation != _generation) return;
    if (result is SystemProxyUnavailable) {
      _log.warning(
        'System proxy unavailable: ${result.reason.name} ${result.detail ?? ''}',
      );
    }
    _apply(settings, result, detecting: false);
  }

  void _apply(
    ProxySettings settings,
    SystemProxyResult? system, {
    required bool detecting,
  }) {
    final effective = EffectiveProxy.resolve(
      settings: settings,
      system: system,
      password: _password,
    );
    if (effective != _state.effective) _log.info('Proxy now $effective');
    _state = ProxyControllerState(
      settings: settings,
      system: system,
      detecting: detecting,
      effective: effective,
    );
    if (!_changes.isClosed) _changes.add(_state);
  }

  void dispose() => _changes.close();
}
```

If the existing `LoggerService` has no `const` constructor usable in a static field, use `static final _log = LoggerService('Proxy');`.

```dart
// lib/core/network/proxy/proxy_refresh_triggers.dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import 'package:submersion/core/network/proxy/proxy_controller.dart';

/// Re-asks the OS for its proxy when the app returns to the foreground or the
/// network changes, the two moments a laptop or phone typically moves between
/// office, home and travel networks.
class ProxyRefreshTriggers {
  ProxyRefreshTriggers(
    ProxyController controller, {
    Stream<Object?>? networkChanges,
    bool listenToLifecycle = true,
  }) {
    _network = (networkChanges ?? Connectivity().onConnectivityChanged)
        .listen((_) => unawaited(controller.refresh()));
    if (listenToLifecycle) {
      _lifecycle = AppLifecycleListener(
        onResume: () => unawaited(controller.refresh()),
      );
    }
  }

  late final StreamSubscription<Object?> _network;
  AppLifecycleListener? _lifecycle;

  void dispose() {
    unawaited(_network.cancel());
    _lifecycle?.dispose();
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/network/proxy/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/proxy test/core/network/proxy
git commit -m "feat(network): keep a live proxy snapshot and refresh it on resume and network change"
```

---

### Task 10: Connection tester

**Files:**
- Create: `lib/core/network/proxy/proxy_connection_tester.dart`
- Test: `test/core/network/proxy/proxy_connection_tester_test.dart`

**Interfaces:**
- Consumes: `AppHttpOverrides`, `EffectiveProxy`, `ProxyRoutingPolicy`, `Socks5Exception`, `proxyProbeUrl`.
- Produces: `sealed class ProxyTestOutcome` with `ProxyTestSuccess(Duration elapsed, EffectiveProxy via)`, `ProxyTestUnreachable(String endpoint)`, `ProxyTestAuthRejected()`, `ProxyTestTlsFailure()`, `ProxyTestTimeout()`, `ProxyTestFailed(String detail)`; `class ProxyConnectionTester { ProxyConnectionTester({Uri? probeUrl, Duration timeout = const Duration(seconds: 10), ProxyRoutingPolicy shouldProxy = defaultShouldProxy}); Future<ProxyTestOutcome> run(EffectiveProxy proxy); }`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_connection_tester.dart';

import '../../../helpers/fake_http_proxy.dart';
import '../../../helpers/fake_socks5_server.dart';
import '../../../helpers/recording_tcp_server.dart';

bool proxyEverything(Uri url, EffectiveProxy p) => !p.isDirect;

EffectiveProxy httpProxy(int port, {String? user, String? pass}) => EffectiveProxy(
  kind: ProxyKind.http, host: '127.0.0.1', port: port,
  username: user, password: pass, source: ProxySource.manual,
);

void main() {
  late HttpServer target;

  setUp(() async {
    target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    target.listen((r) => r.response..statusCode = 204..close());
  });
  tearDown(() => target.close(force: true));

  ProxyConnectionTester tester({Uri? url, Duration? timeout}) => ProxyConnectionTester(
    probeUrl: url ?? Uri.parse('http://example.test:${target.port}/'),
    timeout: timeout ?? const Duration(seconds: 5),
    shouldProxy: proxyEverything,
  );

  test('direct success', () async {
    final o = await tester(url: Uri.parse('http://127.0.0.1:${target.port}/'))
        .run(const EffectiveProxy.direct());
    expect(o, isA<ProxyTestSuccess>());
  });

  test('success through an http proxy names it', () async {
    final p = await FakeHttpProxy.start();
    addTearDown(p.close);
    final o = await tester().run(httpProxy(p.port));
    expect(o, isA<ProxyTestSuccess>().having((s) => s.via.port, 'port', p.port));
  });

  test('407 is authRejected', () async {
    final p = await FakeHttpProxy.start(requireBasic: 'ann:right');
    addTearDown(p.close);
    expect(await tester().run(httpProxy(p.port, user: 'ann', pass: 'wrong')), isA<ProxyTestAuthRejected>());
    final hello = await RecordingTcpServer.start();
    addTearDown(hello.close);
    expect(
      await tester(url: Uri.parse('https://example.test:${hello.port}/')).run(httpProxy(p.port)),
      isA<ProxyTestAuthRejected>(),
    );
  });

  test('a closed proxy port is unreachable, for http and socks5', () async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = s.port;
    await s.close();
    expect(await tester().run(httpProxy(port)), isA<ProxyTestUnreachable>());
    expect(
      await tester().run(EffectiveProxy(kind: ProxyKind.socks5, host: '127.0.0.1', port: port, source: ProxySource.manual)),
      isA<ProxyTestUnreachable>(),
    );
  });

  test('socks5 wrong password is authRejected', () async {
    final s = await FakeSocks5Server.start(username: 'a', password: 'b');
    addTearDown(s.close);
    final o = await tester().run(EffectiveProxy(
      kind: ProxyKind.socks5, host: '127.0.0.1', port: s.port,
      username: 'a', password: 'x', source: ProxySource.manual,
    ));
    expect(o, isA<ProxyTestAuthRejected>());
  });

  test('a TLS handshake failure is tlsFailure', () async {
    final garbage = await RecordingTcpServer.start(reply: List.filled(64, 0x41));
    addTearDown(garbage.close);
    final o = await tester(url: Uri.parse('https://127.0.0.1:${garbage.port}/'))
        .run(const EffectiveProxy.direct());
    expect(o, isA<ProxyTestTlsFailure>());
  });

  test('no answer in time is timeout', () async {
    final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(silent.close);
    silent.listen((_) {});
    final o = await tester(
      url: Uri.parse('http://127.0.0.1:${silent.port}/'),
      timeout: const Duration(milliseconds: 200),
    ).run(const EffectiveProxy.direct());
    expect(o, isA<ProxyTestTimeout>());
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/network/proxy/proxy_connection_tester_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Implement**

```dart
// lib/core/network/proxy/proxy_connection_tester.dart
import 'dart:async';
import 'dart:io';

import 'package:submersion/core/network/proxy/app_http_overrides.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_routing.dart';
import 'package:submersion/core/network/proxy/socks5_connector.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/services/logger_service.dart';

sealed class ProxyTestOutcome {
  const ProxyTestOutcome();
}

class ProxyTestSuccess extends ProxyTestOutcome {
  const ProxyTestSuccess(this.elapsed, this.via);
  final Duration elapsed;
  final EffectiveProxy via;
}

class ProxyTestUnreachable extends ProxyTestOutcome {
  const ProxyTestUnreachable(this.endpoint);
  final String endpoint;
}

class ProxyTestAuthRejected extends ProxyTestOutcome {
  const ProxyTestAuthRejected();
}

class ProxyTestTlsFailure extends ProxyTestOutcome {
  const ProxyTestTlsFailure();
}

class ProxyTestTimeout extends ProxyTestOutcome {
  const ProxyTestTimeout();
}

class ProxyTestFailed extends ProxyTestOutcome {
  const ProxyTestFailed(this.detail);
  final String detail;
}

/// One HEAD request with a throwaway client built from [proxy], which may be
/// unsaved form values, so a user can check a proxy before committing to it.
/// Any HTTP response at all counts as success: the route works.
class ProxyConnectionTester {
  ProxyConnectionTester({
    Uri? probeUrl,
    Duration timeout = const Duration(seconds: 10),
    ProxyRoutingPolicy shouldProxy = defaultShouldProxy,
  }) : _probe = probeUrl ?? proxyProbeUrl,
       _timeout = timeout,
       _shouldProxy = shouldProxy;

  static final _log = LoggerService('ProxyTest');

  final Uri _probe;
  final Duration _timeout;
  final ProxyRoutingPolicy _shouldProxy;

  Future<ProxyTestOutcome> run(EffectiveProxy proxy) async {
    final client = AppHttpOverrides(
      currentProxy: () => proxy,
      shouldProxy: _shouldProxy,
    ).createHttpClient(null)..connectionTimeout = _timeout;
    final watch = Stopwatch()..start();
    try {
      final response = await () async {
        final request = await client.headUrl(_probe);
        final res = await request.close();
        await res.drain<void>();
        return res;
      }().timeout(_timeout);
      if (response.statusCode == HttpStatus.proxyAuthenticationRequired) {
        return const ProxyTestAuthRejected();
      }
      return ProxyTestSuccess(watch.elapsed, proxy);
    } catch (e, st) {
      _log.warning('Proxy test failed via $proxy: $e', error: e, stackTrace: st);
      return _classify(e, proxy);
    } finally {
      client.close(force: true);
    }
  }

  ProxyTestOutcome _classify(Object e, EffectiveProxy proxy) {
    if (e is TimeoutException) return const ProxyTestTimeout();
    if (e is Socks5Exception) {
      return switch (e.failure) {
        Socks5Failure.proxyUnreachable => ProxyTestUnreachable(proxy.endpoint),
        Socks5Failure.authRejected ||
        Socks5Failure.noAcceptableAuth => const ProxyTestAuthRejected(),
        _ => ProxyTestFailed(e.message),
      };
    }
    if (e is HttpException && e.message.contains('407')) {
      return const ProxyTestAuthRejected();
    }
    if (e is HandshakeException || e is TlsException) {
      return const ProxyTestTlsFailure();
    }
    if (e is SocketException) {
      if (!proxy.isDirect && e.port == proxy.port) {
        return ProxyTestUnreachable(proxy.endpoint);
      }
      if (e.message.contains('timed out')) return const ProxyTestTimeout();
      return ProxyTestFailed(e.osError?.message ?? e.message);
    }
    return ProxyTestFailed('$e');
  }
}
```

Note: `warning` may not accept `error:`/`stackTrace:` in this repo's `LoggerService`; check its signature (Task 9 notes it) and pass the error inside the message if not.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/network/proxy/proxy_connection_tester_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/proxy/proxy_connection_tester.dart test/core/network/proxy/proxy_connection_tester_test.dart
git commit -m "feat(network): test a proxy with one request and explain the failure"
```

---

### Task 11: Wire into startup and Riverpod

**Files:**
- Modify: `lib/main.dart` (the `if (Platform.isWindows) HttpOverrides.global = ...` block near line 64, and after `SharedPreferences.getInstance()`), `lib/core/providers/root_overrides.dart`
- Create: `lib/features/settings/presentation/providers/network_proxy_providers.dart`
- Test: `test/features/settings/presentation/providers/network_proxy_providers_test.dart`, `test/core/providers/root_overrides_test.dart` (extend if it exists; else add a case to the new providers test)

**Interfaces:**
- Consumes: `ProxyController`, `ProxyRefreshTriggers`, `ProxySettingsStore`, `SystemProxyResolver.forPlatform`, `AppHttpOverrides`, `ProxyConnectionTester`.
- Produces: `proxyControllerProvider` (`Provider<ProxyController>`, throws `UnimplementedError` unless overridden), `proxyStateProvider` (`StreamProvider<ProxyControllerState>`, emits the current state first), `proxyConnectionTesterProvider` (`Provider<ProxyConnectionTester>`), `networkProxyDraftProvider` (`StateNotifierProvider<NetworkProxyDraftNotifier, NetworkProxyDraft?>`), `class NetworkProxyDraft { ProxyType type; String host; String port; String username; String password; }`; `rootProviderOverrides(..., ProxyController? proxyController)`.

- [ ] **Step 1: Write the failing provider test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/network_proxy_providers.dart';

class _None implements SystemProxyResolver {
  @override
  Future<SystemProxyResult> resolve(Uri probe) async => const SystemProxyNone();
}

void main() {
  test('state stream starts with the current state and follows changes', () async {
    final controller = ProxyController(resolver: _None());
    addTearDown(controller.dispose);
    final container = ProviderContainer(overrides: [
      proxyControllerProvider.overrideWithValue(controller),
    ]);
    addTearDown(container.dispose);
    final seen = <ProxyMode>[];
    container.listen(proxyStateProvider, (_, next) {
      final v = next.valueOrNull;
      if (v != null) seen.add(v.settings.mode);
    }, fireImmediately: true);
    await pumpEventQueue();
    await controller.saveSettings(ProxySettings.defaults.copyWith(mode: ProxyMode.none));
    await pumpEventQueue();
    expect(seen.first, ProxyMode.system);
    expect(seen.last, ProxyMode.none);
  });

  test('the draft keeps edits until cleared', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(networkProxyDraftProvider.notifier);
    expect(container.read(networkProxyDraftProvider), isNull);
    n.update(const NetworkProxyDraft(type: ProxyType.http, host: 'h', port: '1', username: '', password: ''));
    expect(container.read(networkProxyDraftProvider)!.host, 'h');
    n.clear();
    expect(container.read(networkProxyDraftProvider), isNull);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/settings/presentation/providers/network_proxy_providers_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Implement providers**

```dart
// lib/features/settings/presentation/providers/network_proxy_providers.dart
import 'package:flutter/foundation.dart';

import 'package:submersion/core/network/proxy/proxy_connection_tester.dart';
import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/providers/provider.dart';

/// The process-wide controller made in main(); overridden there through
/// rootProviderOverrides.
final proxyControllerProvider = Provider<ProxyController>(
  (ref) => throw UnimplementedError('ProxyController is created in main()'),
);

final proxyStateProvider = StreamProvider<ProxyControllerState>((ref) async* {
  final controller = ref.watch(proxyControllerProvider);
  yield controller.state;
  yield* controller.changes;
});

final proxyConnectionTesterProvider = Provider<ProxyConnectionTester>(
  (ref) => ProxyConnectionTester(),
);

/// Unsaved manual-proxy edits. Kept outside the page so switching settings
/// sections in the desktop layout does not lose them; cleared on Save or on
/// a confirmed discard.
@immutable
class NetworkProxyDraft {
  const NetworkProxyDraft({
    required this.type,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  final ProxyType type;
  final String host;
  final String port;
  final String username;
  final String password;
}

class NetworkProxyDraftNotifier extends StateNotifier<NetworkProxyDraft?> {
  NetworkProxyDraftNotifier() : super(null);

  void update(NetworkProxyDraft draft) => state = draft;
  void clear() => state = null;
}

final networkProxyDraftProvider =
    StateNotifierProvider<NetworkProxyDraftNotifier, NetworkProxyDraft?>(
      (ref) => NetworkProxyDraftNotifier(),
    );
```

- [ ] **Step 4: Root overrides.** Add an optional parameter and override:

```dart
List<dynamic> rootProviderOverrides({
  required SharedPreferences prefs,
  required LogFileService logFileService,
  NavigationReadyGate<IncomingShare>? incomingShares,
  ProxyController? proxyController,
}) {
  return [
    if (incomingShares != null)
      incomingShareGateProvider.overrideWithValue(incomingShares),
    // Made once per process in main(), before the first request, so the
    // HttpOverrides and the settings page share one snapshot (#3217).
    if (proxyController != null)
      proxyControllerProvider.overrideWithValue(proxyController),
    // ...existing entries unchanged
  ];
}
```

- [ ] **Step 5: main.dart.** Replace the Windows-only block:

```dart
  // Every HttpClient in the Dart VM (S3 sync, map tiles, NetworkImage,
  // weather, geocoding) gets the platform-trusted SecurityContext on Windows
  // and the current proxy snapshot everywhere (#3217). Installed before the
  // first network request; the snapshot is direct until the saved proxy
  // choice loads below.
  final proxyController = ProxyController(
    resolver: SystemProxyResolver.forPlatform(),
  );
  HttpOverrides.global = AppHttpOverrides(
    currentProxy: () => proxyController.current,
  );
```

and directly after `final prefs = await SharedPreferences.getInstance();`:

```dart
  // Load the proxy choice and, in system mode, ask the OS (at most 3 s, so a
  // slow PAC server cannot hold up launch), then keep it current as the
  // network changes and the app resumes.
  await proxyController.initialize(ProxySettingsStore(prefs));
  ProxyRefreshTriggers(proxyController);
```

Pass `proxyController` down to the widget that calls `rootProviderOverrides` (the `prefs` constructor parameter on the root widget, line ~85, shows the pattern: add a `final ProxyController proxyController;` field, pass it from `runApp(...)`, and forward it as `proxyController: proxyController` in the `rootProviderOverrides(...)` call at line ~190). `post_restore_safety_review.dart` keeps calling `rootProviderOverrides` without it.

Remove the `coverage:ignore` markers that only wrapped the Windows guard if the block they guarded is gone; keep any still meaningful.

- [ ] **Step 6: Verify**

Run: `flutter analyze` then `flutter test test/features/settings/presentation/providers/network_proxy_providers_test.dart test/core/providers test/app_test.dart`
Expected: analyze clean, tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/main.dart lib/core/providers/root_overrides.dart lib/features/settings/presentation/providers/network_proxy_providers.dart test/features/settings/presentation/providers/network_proxy_providers_test.dart
git commit -m "feat(network): install the proxy hook on every platform at startup"
```

---

### Task 12: Network section in Settings

**Files:**
- Modify: `lib/features/settings/presentation/widgets/settings_list_content.dart` (insert the section between `manage` and `notifications`; add `'network'` cases to `_getLocalizedTitle` / `_getLocalizedSubtitle`), `lib/features/settings/presentation/pages/settings_page.dart` (add `case 'network': return const NetworkSettingsPage();` to `_buildSectionContent` and `_buildContent`, and `'network' => context.l10n.settings_section_network_title` to `_getLocalizedSectionTitle`), `lib/core/theme/feature_accent_colors.dart` (`'settings-network': Color(0xFF8D6E63)` light, `Color(0xFFBCAAA4)` dark), `lib/l10n/arb/app_en.arb` (two keys, inserted surgically before `settings_section_notifications_subtitle`)
- Create: `lib/features/settings/presentation/pages/network_settings_page.dart` as a placeholder `const NetworkSettingsPage()` returning `const SizedBox.shrink()` (Task 13 fills it), so the routing compiles
- Test: `test/features/settings/presentation/widgets/settings_list_content_test.dart`, `test/core/theme/feature_accent_colors_test.dart` (add `'network'` to the id list)
- Check: any route table that whitelists settings section ids (`grep -rn "'sharedData'" lib/core/router lib/app*` ) gets `'network'` too.

New `app_en.arb` keys:

```json
  "settings_section_network_subtitle": "Proxy server",
  "settings_section_network_title": "Network",
```

- [ ] **Step 1: Write the failing tests**

In `settings_list_content_test.dart` add:

```dart
    testWidgets('shows Network between Manage and Notifications', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(await buildWidget(debugEnabled: false));
      await tester.pumpAndSettle();
      expect(find.text('Network'), findsOneWidget);
      expect(find.text('Proxy server'), findsOneWidget);
      final manage = tester.getTopLeft(find.text('Manage')).dy;
      final network = tester.getTopLeft(find.text('Network')).dy;
      final notifications = tester.getTopLeft(find.text('Notifications')).dy;
      expect(manage < network && network < notifications, isTrue);
    });
```

and `'network',` in the accent test's id list.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/settings/presentation/widgets/settings_list_content_test.dart test/core/theme/feature_accent_colors_test.dart`
Expected: FAIL (no Network row; no accent).

- [ ] **Step 3: Implement** the list entry:

```dart
  SettingsSection(
    id: 'network',
    icon: Icons.lan_outlined,
    title: 'Network',
    subtitle: 'Proxy server',
  ),
```

plus the switch cases, accents, ARB keys, and placeholder page. Run `flutter gen-l10n` only to compile against the English keys here; Task 14 regenerates after translating (the memory "ordering trap": the generated non-English files are rewritten then).

- [ ] **Step 4: Run tests to verify they pass**

Run: same as Step 2, plus `flutter test test/features/settings`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings lib/core/theme/feature_accent_colors.dart lib/l10n test/features/settings test/core/theme
git commit -m "feat(network): add the Network section to Settings"
```

---

### Task 13: Network settings page

**Files:**
- Modify: `lib/features/settings/presentation/pages/network_settings_page.dart`
- Create: `lib/features/settings/presentation/widgets/network/proxy_mode_selector.dart`, `proxy_status_line.dart`, `proxy_manual_form.dart`, `proxy_test_section.dart`
- Modify: `lib/l10n/arb/app_en.arb` (keys below, inserted surgically in sorted position)
- Test: `test/features/settings/presentation/pages/network_settings_page_test.dart`

**Interfaces:**
- Consumes: `proxyControllerProvider`, `proxyStateProvider`, `proxyConnectionTesterProvider`, `networkProxyDraftProvider`, `NetworkProxyDraft`, `checkProxyCredentials`, `EffectiveProxy.resolve`, `ProxyTestOutcome` family, existing `forms_discard_*` keys.

English keys (`app_en.arb`):

```json
  "settings_network_mode_header": "Proxy",
  "settings_network_mode_system": "System proxy",
  "settings_network_mode_system_subtitle": "Use the proxy configured in your device's network settings",
  "settings_network_mode_manual": "Manual",
  "settings_network_mode_manual_subtitle": "Enter a proxy server",
  "settings_network_mode_none": "No proxy",
  "settings_network_mode_none_subtitle": "Always connect directly",
  "settings_network_status_detecting": "Checking this device's proxy settings",
  "settings_network_status_none": "No proxy configured on this device",
  "settings_network_status_fixed": "Using {endpoint}",
  "settings_network_status_fixedPac": "Using {endpoint} (from automatic configuration)",
  "settings_network_status_fixedSocks": "Using {endpoint} (SOCKS5)",
  "settings_network_status_pacUnsupported": "Automatic proxy configuration isn't supported on this device. Choose Manual and enter the proxy.",
  "settings_network_status_pacFailed": "The automatic proxy configuration couldn't be read. Choose Manual and enter the proxy.",
  "settings_network_status_error": "This device's proxy settings couldn't be read.",
  "settings_network_status_refresh": "Check again",
  "settings_network_manual_typeHttp": "HTTP",
  "settings_network_manual_typeSocks": "SOCKS5",
  "settings_network_manual_host": "Host",
  "settings_network_manual_port": "Port",
  "settings_network_manual_username": "Username (optional)",
  "settings_network_manual_password": "Password (optional)",
  "settings_network_manual_showPassword": "Show password",
  "settings_network_manual_hidePassword": "Hide password",
  "settings_network_manual_save": "Save",
  "settings_network_manual_saved": "Proxy settings saved",
  "settings_network_manual_nativeNote": "Sign-in screens provided by the operating system use the system proxy.",
  "settings_network_validation_hostRequired": "Enter the proxy host",
  "settings_network_validation_portInvalid": "Enter a port from 1 to 65535",
  "settings_network_validation_passwordRequired": "Enter the password for this username",
  "settings_network_validation_usernameColon": "The username can't contain a colon",
  "settings_network_validation_passwordSemicolon": "The password can't contain a semicolon",
  "settings_network_validation_passwordWhitespace": "The password can't start or end with a space",
  "settings_network_validation_tooLong": "Must be 255 bytes or fewer",
  "settings_network_test_button": "Test connection",
  "settings_network_test_running": "Testing",
  "settings_network_test_successProxy": "Connected through {endpoint} ({type}) in {ms} ms",
  "settings_network_test_successDirect": "Connected directly in {ms} ms",
  "settings_network_test_unreachable": "Couldn't reach {endpoint}. Check the host and port.",
  "settings_network_test_authRejected": "The proxy rejected the username or password.",
  "settings_network_test_authRequiredSystem": "This proxy requires a username and password. Choose Manual and enter them.",
  "settings_network_test_tls": "Secure connection failed. Your network may inspect HTTPS traffic; its certificate must be trusted by this device.",
  "settings_network_test_timeout": "The connection timed out.",
  "settings_network_test_failed": "The connection failed: {detail}. The debug log has the full error."
```

Each placeholder key gets an `@` entry in `app_en.arb` (`endpoint`, `type`, `detail` as `String`; `ms` as `int`), written compactly on one line like the file's neighbours.

Page behaviour (the tests below pin it):

- `NetworkSettingsPage` is a `ConsumerStatefulWidget` returning a `ListView` (no Scaffold: `SettingsSectionDetailPage` supplies the AppBar) inside a `PopScope(canPop: draft == null, onPopInvokedWithResult: ...)` that asks with the `forms_discard_*` dialog and clears the draft on discard.
- On first build (`initState`, via a post-frame callback), the page calls `controller.refresh()` when the saved mode is system, as the spec asks (detection reruns whenever the Network page opens).
- `ProxyModeSelector(mode, onChanged)`: three `RadioListTile<ProxyMode>` with the title and subtitle keys. `onChanged` calls `controller.saveSettings(state.settings.copyWith(mode: m))` at once.
- `ProxyStatusLine(state)`: shown in system mode. Text by `state.detecting` (detecting), `state.system` (`SystemProxyNone` -> none; `SystemProxyFixed` -> fixed / fixedPac / fixedSocks with `endpoint`; `SystemProxyUnavailable` -> pacUnsupported / pacFailed / error), with an `IconButton(Icons.refresh, tooltip: refresh)` calling `controller.refresh()`.
- `ProxyManualForm`: shown in manual mode. A `SegmentedButton<ProxyType>`, `TextField`s with keys `ValueKey('proxy-host')`, `'proxy-port'` (digits only, `hintText` `8080` for HTTP, `1080` for SOCKS5), `'proxy-username'`, `'proxy-password'` (obscured, suffix toggle with show/hide tooltips), the native note, and `FilledButton(save)`. Initial values come from the draft, else saved settings plus `controller.manualPassword`. Every edit writes `networkProxyDraftProvider`. Save validates (host required; port 1..65535; `checkProxyCredentials` problem mapped to its message) and shows errors as `errorText`; on success it calls `controller.saveSettings(settings.copyWith(type, host, port, username), password: pw, updatePassword: true)` keeping the current mode, clears the draft, and shows a SnackBar `saved`.
- `ProxyTestSection`: `OutlinedButton(test_button)`; while running shows a small progress indicator and `test_running`. It builds the snapshot under test with `EffectiveProxy.resolve(settings: <saved settings, overlaid with the draft when mode is manual>, system: state.system, password: <draft password or manualPassword>)` and runs `ref.read(proxyConnectionTesterProvider).run(...)`. Outcome text: success -> successProxy (`endpoint`, `type` = HTTP or SOCKS5, `ms`) or successDirect; unreachable; authRejected (authRequiredSystem when the mode is system); tls; timeout; failed (`detail`). Success text in `colorScheme.primary`, failures in `colorScheme.error`.

- [ ] **Step 1: Write the failing widget tests**

```dart
// test/features/settings/presentation/pages/network_settings_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_connection_tester.dart';
import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/proxy_settings_store.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/network_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/network_proxy_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../support/fake_keychain_storage.dart';

class _Resolver implements SystemProxyResolver {
  _Resolver(this.answer);
  SystemProxyResult answer;
  @override
  Future<SystemProxyResult> resolve(Uri probe) async => answer;
}

class _Tester extends ProxyConnectionTester {
  _Tester(this.outcome);
  final ProxyTestOutcome outcome;
  EffectiveProxy? ran;
  @override
  Future<ProxyTestOutcome> run(EffectiveProxy proxy) async {
    ran = proxy;
    return outcome;
  }
}

void main() {
  late ProxyController controller;
  late ProxySettingsStore store;

  Future<void> pump(
    WidgetTester tester, {
    SystemProxyResult system = const SystemProxyNone(),
    ProxySettings? saved,
    _Tester? testerFake,
  }) async {
    SharedPreferences.setMockInitialValues({});
    store = ProxySettingsStore(await SharedPreferences.getInstance(), storage: InMemoryKeychain());
    if (saved != null) await store.save(saved);
    controller = ProxyController(resolver: _Resolver(system));
    addTearDown(controller.dispose);
    await controller.initialize(store);
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        proxyControllerProvider.overrideWithValue(controller),
        if (testerFake != null) proxyConnectionTesterProvider.overrideWithValue(testerFake),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: NetworkSettingsPage()),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('system mode shows the detected proxy', (tester) async {
    await pump(tester, system: const SystemProxyFixed(type: ProxyType.http, host: 'corp', port: 8080, viaPac: true));
    expect(find.text('System proxy'), findsOneWidget);
    expect(find.text('Using corp:8080 (from automatic configuration)'), findsOneWidget);
    expect(find.byKey(const ValueKey('proxy-host')), findsNothing);
  });

  testWidgets('unsupported PAC tells the user to choose Manual', (tester) async {
    await pump(tester, system: const SystemProxyUnavailable(SystemProxyUnavailableReason.pacUnsupported));
    expect(find.textContaining('Choose Manual'), findsOneWidget);
  });

  testWidgets('choosing No proxy saves at once', (tester) async {
    await pump(tester);
    await tester.tap(find.text('No proxy'));
    await tester.pumpAndSettle();
    expect(store.load().mode, ProxyMode.none);
    expect(controller.current.isDirect, isTrue);
  });

  testWidgets('manual fields validate and save', (tester) async {
    await pump(tester, saved: ProxySettings.defaults.copyWith(mode: ProxyMode.manual));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter the proxy host'), findsOneWidget);
    expect(find.text('Enter a port from 1 to 65535'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('proxy-host')), 'proxy.corp');
    await tester.enterText(find.byKey(const ValueKey('proxy-port')), '3128');
    await tester.enterText(find.byKey(const ValueKey('proxy-username')), 'ann');
    await tester.enterText(find.byKey(const ValueKey('proxy-password')), 'a;b');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text("The password can't contain a semicolon"), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('proxy-password')), 'pw');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.load().host, 'proxy.corp');
    expect(await store.loadPassword(), 'pw');
    expect(controller.current.endpoint, 'proxy.corp:3128');
    expect(find.text('Proxy settings saved'), findsOneWidget);
  });

  testWidgets('Test uses unsaved manual values and reports success', (tester) async {
    final fake = _Tester(ProxyTestSuccess(const Duration(milliseconds: 240),
        const EffectiveProxy(kind: ProxyKind.http, host: 'draft.host', port: 9, source: ProxySource.manual)));
    await pump(tester, saved: ProxySettings.defaults.copyWith(mode: ProxyMode.manual), testerFake: fake);
    await tester.enterText(find.byKey(const ValueKey('proxy-host')), 'draft.host');
    await tester.enterText(find.byKey(const ValueKey('proxy-port')), '9');
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
    expect(fake.ran!.host, 'draft.host');
    expect(find.text('Connected through draft.host:9 (HTTP) in 240 ms'), findsOneWidget);
    expect(store.load().host, '');
  });

  testWidgets('auth failure in system mode suggests Manual', (tester) async {
    await pump(tester,
        system: const SystemProxyFixed(type: ProxyType.http, host: 'corp', port: 8080),
        testerFake: _Tester(const ProxyTestAuthRejected()));
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
    expect(find.text('This proxy requires a username and password. Choose Manual and enter them.'), findsOneWidget);
  });

  testWidgets('each failure outcome has its message', (tester) async {
    final cases = <ProxyTestOutcome, String>{
      const ProxyTestUnreachable('p:1'): "Couldn't reach p:1. Check the host and port.",
      const ProxyTestTlsFailure(): 'Secure connection failed. Your network may inspect HTTPS traffic; its certificate must be trusted by this device.',
      const ProxyTestTimeout(): 'The connection timed out.',
      const ProxyTestFailed('boom'): 'The connection failed: boom. The debug log has the full error.',
    };
    for (final entry in cases.entries) {
      await pump(tester, testerFake: _Tester(entry.key));
      await tester.tap(find.text('Test connection'));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget, reason: '${entry.key}');
    }
  });

  testWidgets('back with unsaved edits asks before discarding', (tester) async {
    // Push the page as a route so PopScope applies.
    SharedPreferences.setMockInitialValues({});
    store = ProxySettingsStore(await SharedPreferences.getInstance(), storage: InMemoryKeychain());
    await store.save(ProxySettings.defaults.copyWith(mode: ProxyMode.manual));
    controller = ProxyController(resolver: _Resolver(const SystemProxyNone()));
    addTearDown(controller.dispose);
    await controller.initialize(store);
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
      overrides: [proxyControllerProvider.overrideWithValue(controller)],
      child: MaterialApp(
        navigatorKey: navKey,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Text('root')),
      ),
    ));
    navKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: NetworkSettingsPage())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('proxy-host')), 'unsaved');
    await navKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
```

Use the real English text of `forms_discard_*` from `app_en.arb` if the test needs to tap the dialog buttons.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/settings/presentation/pages/network_settings_page_test.dart`
Expected: FAIL (placeholder page).

- [ ] **Step 3: Implement** the page and four widgets as described above. Keep each widget file under 250 lines. Use `context.l10n` for every string. Map the credentials problem:

```dart
String credentialsMessage(AppLocalizations l10n, ProxyCredentialsProblem p) => switch (p) {
  ProxyCredentialsProblem.passwordRequired => l10n.settings_network_validation_passwordRequired,
  ProxyCredentialsProblem.usernameHasColon => l10n.settings_network_validation_usernameColon,
  ProxyCredentialsProblem.passwordHasSemicolon => l10n.settings_network_validation_passwordSemicolon,
  ProxyCredentialsProblem.passwordHasEdgeWhitespace => l10n.settings_network_validation_passwordWhitespace,
  ProxyCredentialsProblem.tooLong => l10n.settings_network_validation_tooLong,
};
```

Place a `usernameHasColon` and `tooLong` error on the username field, the rest on the password field.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter gen-l10n && flutter test test/features/settings/presentation/pages/network_settings_page_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings lib/l10n test/features/settings
git commit -m "feat(network): add the Network settings page with proxy test"
```

---

### Task 14: Translations

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`, regenerated `lib/l10n/arb/app_localizations*.dart`

- [ ] **Step 1:** List this branch's new English keys: `git diff origin/main...HEAD -- lib/l10n/arb/app_en.arb | grep '^+  "settings_'`.
- [ ] **Step 2:** For each locale, insert the translated keys surgically after an anchor key present in all 11 files (`settings_section_notifications_title`), building each line as `'  "%s": %s,' % (key, json.dumps(value, ensure_ascii=False))` in a python3.14 script; assert `json.loads` succeeds per file; no `@` metadata in locale files. Keep `{endpoint}`, `{type}`, `{ms}`, `{detail}` verbatim. Match each locale's existing terms for "proxy", "Save", "Host", "Port" where the file has them; "HTTP" and "SOCKS5" stay untranslated.
- [ ] **Step 3:** `git diff --numstat -- lib/l10n/arb/*.arb` shows the same added count and 0 removed for every locale ARB.
- [ ] **Step 4:** `flutter gen-l10n`, then verify one generated getter per locale is not English, for example `grep -A1 'get settings_network_mode_none' lib/l10n/arb/app_localizations_de.dart`.
- [ ] **Step 5:** `flutter test test/l10n` PASS.
- [ ] **Step 6: Commit**

```bash
git add lib/l10n
git commit -m "i18n(network): translate the Network settings page"
```

---

### Task 15: Verification, screenshots, cleanup

- [ ] **Step 1:** `dart format .` and `flutter analyze` (clean).
- [ ] **Step 2:** `flutter test test/architecture test/shared test/core/network test/features/settings test/l10n test/app_test.dart` PASS. Confirm `test/architecture/test_global_state_restored_test.dart` passes (no test assigns `HttpOverrides.global`).
- [ ] **Step 3:** Grep the branch for em and en dashes in added lines: `git diff origin/main...HEAD | grep '^+' | python3.14 -c "import sys;print(sum(l.count(chr(0x2014))+l.count(chr(0x2013)) for l in sys.stdin))"` prints 0.
- [ ] **Step 4:** Grep that no log line includes credentials: `grep -rn "password" lib/core/network/proxy | grep -i log` shows nothing that interpolates a password.
- [ ] **Step 5:** After screenshots with the throwaway golden harness in untracked `test/zz_shots/` (fonts from the Flutter SDK cache): Settings list phone light and dark; Network page phone light and dark in System mode with a detected PAC proxy; Manual mode with fields filled and a success Test result; desktop width (1280 x 800) of the Network page. Save to the scratchpad as `NN-<screen>-after[-dark][-phone].png`. Delete `test/zz_shots/` afterwards.
- [ ] **Step 6:** Build the macOS debug app from a scratchpad script and confirm it launches past the first frame; check the debug log has `Proxy now EffectiveProxy(direct, system)` and no proxy errors (this Mac has no system proxy).
- [ ] **Step 7:** Commit any formatting fixes as `chore(network): format`.
