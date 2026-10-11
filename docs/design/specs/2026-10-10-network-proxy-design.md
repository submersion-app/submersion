# Network Proxy Support: Design

Status: approved in design review, 2026-10-10. Target release: v1.8.2.

## Problem

Submersion's own network traffic (cloud sync to S3, Dropbox and Google Drive on
desktop, map tiles, network images, weather, tides, bathymetry, species
lookups, divelogs.de, Garmin, Suunto, Lightroom and the update check) runs on
Dart's `dart:io` `HttpClient`. That client ignores the operating system's proxy
settings: its default `findProxy` reads only the `http_proxy` / `https_proxy`
environment variables, which a Finder-launched macOS app, a Start-menu Windows
app or any phone app never has. On a corporate or school network that forces
traffic through a proxy, the browser works and Submersion does not: sync fails,
maps stay blank, updates never arrive.

Two kinds of user need this:

- A diver on a corporate or school network whose OS is configured with a proxy,
  often through a PAC script or auto-discovery. The app should just work, with
  no setup.
- A diver who wants to send the app's traffic through a proxy of their own
  choosing (HTTP or SOCKS5), independent of the OS.

## Decisions

| Question | Decision |
| --- | --- |
| Modes | System proxy, Manual, No proxy |
| Default | System proxy, for new and upgrading users. With no OS proxy configured (almost everyone) nothing changes. |
| Manual protocols | HTTP (CONNECT for HTTPS) and SOCKS5, each with optional username and password |
| PAC / auto-discovery | Evaluated once per refresh for a public probe URL; that answer applies to all internet traffic |
| Bypass | Loopback and private LAN always direct, plus the OS bypass list in System mode. No user-editable bypass list. |
| Storage | Device-local (SharedPreferences), never synced. Password in secure storage. |
| UI extras | Test connection button; detected system proxy shown in System mode |
| Mechanism | One global `HttpOverrides` on every platform, reading a live snapshot per connection |

## Architecture

Everything that reaches the internet from Dart goes through an `HttpClient`,
and every `HttpClient()` constructor consults `HttpOverrides.global`. The app
already installs one on Windows (`TrustedHttpOverrides`, for certificate
trust). This feature generalizes it into `AppHttpOverrides`, installed on every
platform in `main()` before the first request. Its `createHttpClient` keeps the
Windows `SecurityContext` behaviour and sets two callbacks on each client:

- `findProxy`: returns `PROXY [user:pass@]host:port` in HTTP mode, otherwise
  `DIRECT`.
- `connectionFactory`: opens a SOCKS5 tunnel in SOCKS5 mode; otherwise it does
  exactly what `dart:io` does without a factory (a plain socket to the proxy,
  or a direct plain or TLS socket).

Credentials: `dart:io` authenticates a CONNECT tunnel (HTTPS through an HTTP
proxy) only with credentials embedded in the `findProxy` directive, sent up
front as Basic; it never calls `authenticateProxy` for a tunnel. So the
directive carries them, and the manual form rejects values that directive
cannot represent: for HTTP, a username with `:`, a password with `;` or with
leading or trailing spaces; for SOCKS5 (RFC 1929), more than 255 bytes; for
both, a username without a password. Approved in review, 2026-10-10.

Each callback reads an immutable `EffectiveProxy` snapshot from a process-wide
holder at connection time. A settings change or a network change therefore
applies to the next connection, including on long-lived clients (the tile
provider, the S3 client), without rebuilding them. An idle keep-alive
connection that is already open keeps its route until it closes.

This covers every `http.Client()` and `HttpClient()` the app constructs and the
ones it does not: flutter_map and FMTC tile fetches, `NetworkImage` and
`cached_network_image`. No call site changes. `HttpOverrides.global` is
isolate-local; the app's spawned isolates (Drift, the sync changeset parser,
UDDF encoding, tide maths) do no network I/O, and the app does not use FMTC
bulk downloads, so nothing escapes it.

Native code that uses the OS network stack (Google Sign-In on mobile, the
platform geocoder, OAuth in the browser, HealthKit) already follows the system
proxy. It does not follow a Manual proxy; the page says so.

## Components

New code lives in `lib/core/network/proxy/`, one purpose per file.

| Unit | Responsibility |
| --- | --- |
| `ProxySettings` | Immutable persisted choice: `mode` (`system`, `manual`, `none`; default `system`), and for manual `type` (`http`, `socks5`), `host`, `port`, `username`. `copyWith` and value equality. |
| `ProxySettingsStore` | Loads and saves `ProxySettings` in SharedPreferences. The password lives in `flutter_secure_storage` through the existing fallback wrapper, never in prefs. |
| `SystemProxyResolver` | Platform interface returning `SystemProxyResult`: `none`, `fixed(type, host, port, bypass)` or `unavailable(reason)`. One implementation per OS, plus a fake for tests. |
| `EffectiveProxy` | Immutable snapshot: `direct`, `http(host, port, credentials?)` or `socks5(host, port, credentials?)`, plus the bypass list and a `source` for the UI (manual, system fixed, system PAC). Built by a pure `EffectiveProxy.resolve(settings, systemResult, password)`. |
| `ProxyController` | Holds the current snapshot. Recomputes on startup, settings change, app resume, connectivity change (the existing `connectivity_plus` stream), opening the Network page and Test. Exposed to the UI through a Riverpod notifier. |
| `ProxyRouting` | Pure per-request decision for a `Uri` and a snapshot: direct or proxy. |
| `Socks5Connector` | TCP to the SOCKS server, RFC 1928 handshake (no auth, or RFC 1929 username and password), CONNECT by hostname so the proxy resolves DNS, then TLS for `https` with the client's `SecurityContext`. |
| `AppHttpOverrides` | Replaces `TrustedHttpOverrides`, wiring the two callbacks to `ProxyController`. |
| `ProxyConnectionTester` | Runs one test request with a throwaway client built from given (possibly unsaved) settings and classifies the outcome. |

Data flow: `ProxySettingsStore` and `SystemProxyResolver` feed
`EffectiveProxy.resolve`; `ProxyController` holds the result; `AppHttpOverrides`
reads it per connection; `ProxyRouting` picks direct or proxy; the request goes
through HTTP CONNECT (built into `dart:io`) or `Socks5Connector`.

### Routing

Always direct, in every mode: `localhost`, names ending `.local`, loopback
(127.0.0.0/8, ::1), private and link-local IPv4 (10.0.0.0/8, 172.16.0.0/12,
192.168.0.0/16, 169.254.0.0/16) and IPv6 unique-local and link-local
(fc00::/7, fe80::/10). This keeps LAN features such as the media network scan
off the proxy. In System mode the OS bypass list also applies: exact hosts,
`*.domain` and `.domain` suffixes, CIDR ranges where the OS gives them, and
Windows `<local>` (single-label host names).

## System proxy detection

Each platform answers: what proxy would the OS use for
`https://api.github.com/` (the update check host), and what is the bypass list?

| Platform | Mechanism | PAC and auto-discovery |
| --- | --- | --- |
| macOS, iOS | Swift handler on `app.submersion/system_proxy`, same pattern as `DeviceNameHandler.swift`: `CFNetworkCopySystemProxySettings` and `CFNetworkCopyProxiesForURL`. HTTP, HTTPS and SOCKS entries map to the two proxy types; `ExceptionsList` is the bypass list. | `CFNetworkExecuteProxyAutoConfigurationURL` (or `...Script`) on a run loop, 5 second cap. |
| Android | Kotlin handler on the same channel: `ConnectivityManager.getDefaultProxy()` gives host, port and exclusion list. | Android serves a PAC network through a local proxy it reports as `localhost:<port>`, which works as a fixed proxy. If a version reports only the PAC URL, the result is `unavailable` with the "choose Manual" hint. |
| Windows | Dart FFI to `winhttp.dll`, the same style as `windows_root_store.dart`: `WinHttpGetIEProxyConfigForCurrentUser`, parsing per-scheme `https=` and `socks=` entries and the bypass list including `<local>`. | `WinHttpGetProxyForUrl` with auto-detect and the configured PAC URL (covers WPAD). |
| Linux | Environment variables first (`https_proxy`, `http_proxy`, `all_proxy` including `socks5://`, `no_proxy`; upper and lower case, as curl reads them), then GNOME `gsettings org.gnome.system.proxy` in manual mode. | Not supported. GNOME automatic mode reports `unavailable`: automatic configuration is not supported on Linux, choose Manual. |

A system SOCKS proxy is used as SOCKS5. A system proxy's credentials are not
readable by the app, so an authenticating system proxy gives a 407; Test and
the status line then tell the user to choose Manual and enter them.

### Startup

`main()` loads the settings, and in Manual mode with a username the password,
before the first request. In System mode it starts detection and waits at most
3 seconds. If detection is slower (a slow PAC server), startup continues
direct and the snapshot switches when detection finishes.

## Network settings page

A new **Network** section in Settings, between Manage and Notifications, icon
`Icons.lan_outlined`, subtitle "Proxy server", with its own `settings-network`
accent. The detail page has:

1. **Proxy mode**: radio tiles for System proxy ("Use the proxy configured in
   your device's network settings"), Manual ("Enter a proxy server") and No
   proxy ("Always connect directly"). Changing the mode applies at once.
   Choosing Manual before any manual proxy has been saved keeps traffic
   direct until Save.
2. **Status line** in System mode, with a refresh button: "No proxy configured
   on this device", "Using proxy.corp:8080 (from automatic configuration)",
   "Using socks.example:1080 (SOCKS5)", or the `unavailable` reason and hint.
3. **Manual fields** in Manual mode: an HTTP | SOCKS5 segmented control, Host,
   Port (1 to 65535; hint 8080 for HTTP, 1080 for SOCKS5), optional Username
   and Password (obscured, with a reveal toggle), a note that sign-in screens
   provided by the operating system use the system proxy, and **Save**. Manual
   fields apply on Save only, so a half-typed host never reroutes live traffic.
   Leaving with unsaved edits asks before discarding them.
4. **Test connection**, in every mode. It tests the settings on screen,
   unsaved edits included, with a throwaway client: one `HEAD` to
   `https://api.github.com/` with a 10 second timeout. Outcomes:
   - Success: "Connected through proxy.corp:8080 (HTTP) in 240 ms" or
     "Connected directly in 90 ms".
   - Proxy unreachable: "Couldn't reach proxy.corp:8080. Check the host and
     port."
   - 407 or SOCKS authentication rejected: "The proxy rejected the username or
     password." In System mode, the choose-Manual hint instead.
   - TLS failure: "Secure connection failed. Your network may inspect HTTPS
     traffic; its certificate must be trusted by this device."
   - Timeout or other: the reason, and a pointer to the debug log, which holds
     the full error.

All strings go through the ARB files. The page uses the existing settings
detail layout, so it works as a phone push and in the desktop master-detail
pane.

## Error handling

- Detection never throws into the network layer. A platform failure becomes
  `unavailable(reason)`; the snapshot falls back to direct and the reason is
  logged and shown on the page.
- The callbacks read an immutable snapshot, so a request never sees a
  half-updated proxy.
- A corrupt or partial saved setting (Manual with an empty host) resolves to
  direct with a logged warning.
- SOCKS failures raise `SocketException` with the RFC 1928 reply translated
  ("connection refused by SOCKS server", "authentication rejected"), so the
  existing sync and tile error paths, which already treat `SocketException`
  as a network error, keep working.

## Logging and privacy

`LoggerService` records each snapshot change (mode, source, host and port).
It never records the username or password, and does not log per-request
routing decisions.

## Testing

All tests run on loopback; nothing reaches the internet.

- Pure units: the `EffectiveProxy.resolve` truth table; `ProxyRouting`
  (private ranges, IPv6, `.local`, bypass suffixes, CIDR, `<local>`); the
  Windows proxy-string parser and the Linux environment and gsettings parsers;
  the settings store round trip with the password in the fake secure store and
  never in prefs.
- `Socks5Connector` against an in-test fake SOCKS5 server on 127.0.0.1: no
  auth, username and password, authentication rejected, each reply code, and
  an HTTPS request tunnelled through it.
- `AppHttpOverrides` end to end: a real `HttpClient` through a loopback fake
  HTTP proxy (CONNECT; 407 then credentials), and a settings change applying
  to the next connection. These tests inject a routing policy that proxies
  loopback; the production policy is unchanged. Every test restores
  `HttpOverrides.global`.
- `ProxyController`: refresh triggers, the 3 second startup cap with a slow
  fake resolver, fallback on resolver error.
- Widget tests: mode switching, field validation, Save, the discard prompt and
  each Test outcome, with a fake tester.
- The Swift, Kotlin and FFI layers are thin; their parsing is tested on the
  Dart side and the native calls are verified by hand on the platforms
  available, with the unverified ones listed in the PR.

## Out of scope

- NTLM and Kerberos proxy authentication (not supported by `dart:io`).
- Per-host PAC evaluation, and PAC on Linux.
- A user-editable bypass list.
- Routing native SDK traffic (OS sign-in screens, the platform geocoder,
  HealthKit) through a Manual proxy.
