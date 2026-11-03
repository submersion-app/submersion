import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Hands a URL to the platform's URL launcher. Injectable so tests never
/// open a real browser.
typedef UrlLaunch = Future<bool> Function(Uri uri);

/// Runs an opener command and reports whether it took the URL. Injectable so
/// tests never shell out.
typedef BrowserSpawn =
    Future<bool> Function(String executable, List<String> arguments);

/// Generic URL openers tried, in order, when url_launcher fails on Linux.
///
/// Each entry is an executable plus its fixed leading arguments; the URL is
/// appended. `xdg-open` and `gio open` are the freedesktop standards.
/// `x-www-browser` and `sensible-browser` are Debian's alternatives system,
/// which resolves a browser from `update-alternatives` and `$BROWSER` even
/// when GIO has no registered `x-scheme-handler/https` at all -- the case
/// that leaves url_launcher with nothing to hand the URL to.
const List<List<String>> linuxBrowserOpeners = [
  ['xdg-open'],
  ['gio', 'open'],
  ['x-www-browser'],
  ['sensible-browser'],
];

/// How long a spawned opener may stay alive before it counts as a success.
///
/// The generic openers split into two shapes: `xdg-open` and `gio open` hand
/// off and exit within milliseconds, while `x-www-browser` on Debian is the
/// browser itself and never exits. A process still running after this window
/// has therefore started something, which is exactly what we wanted.
const Duration _openerSettleWindow = Duration(seconds: 3);

const _log = LoggerService('BrowserLaunch');

/// Opens [uri] in the user's browser, returning whether a browser took it.
///
/// url_launcher first, then -- on Linux only -- a chain of generic openers.
/// The extra chain exists because `url_launcher_linux` resolves the handler
/// through GIO alone (`gtk_show_uri_on_window`), so a desktop with no
/// registered `x-scheme-handler/https` leaves it with nothing to launch,
/// even when the machine plainly has a browser that `xdg-open` or Debian's
/// `x-www-browser` alternative would find (issue: Dropbox connect on Debian
/// 13 opened nothing).
///
/// A true return is not a promise the user saw a window: GIO reports success
/// as soon as it spawns a handler, so a stale `.desktop` entry pointing at an
/// uninstalled binary still "succeeds". Callers that strand the user without
/// a browser -- the OAuth dialogs -- must offer the URL some other way rather
/// than trusting this result.
///
/// On Linux a launcher `Exception` is absorbed into the fallback chain,
/// because that is simply how `url_launcher_linux` says "no handler" (it
/// throws a `PlatformException` rather than returning false). Elsewhere it is
/// rethrown so callers keep the platform's own message. An `Error` always
/// propagates: that is a bug here, not a verdict on the user's desktop.
Future<bool> openInBrowser(
  Uri uri, {
  UrlLaunch? launch,
  BrowserSpawn? spawn,
  bool? onLinux,
}) async {
  final isLinux = onLinux ?? HostPlatform.isLinux;
  try {
    if (await (launch ?? _launchExternally)(uri)) return true;
  } on Exception catch (e) {
    // Exception, not everything: an `Error` is a bug in our own code, and
    // absorbing it would report the user's desktop as broken and send us
    // shelling out for no reason. The boundary is deliberately wider than
    // PlatformException, though -- a MissingPluginException (the Linux
    // plugin never registered) is equally "url_launcher cannot help here",
    // and equally rescuable by the chain below.
    if (!isLinux) rethrow;
    _log.warning('url_launcher could not open a browser: $e');
  }
  if (!isLinux) return false;

  final run = spawn ?? spawnBrowserOpener;
  final url = uri.toString();
  for (final opener in linuxBrowserOpeners) {
    final executable = opener.first;
    try {
      if (await run(executable, [...opener.skip(1), url])) return true;
    } on ProcessException catch (e) {
      // Process.start throws rather than returning non-zero when the
      // executable is absent, which is routine: no desktop ships all four.
      // Logged rather than swallowed, because the same exception carries
      // EACCES and ENOEXEC, and silence would make those undiagnosable. The
      // message distinguishes them ("No such file or directory" vs
      // "Permission denied") without us branching on a platform errno.
      _log.warning('Browser opener $executable unavailable: ${e.message}');
    } on Exception catch (e) {
      _log.warning('Browser opener $executable failed: $e');
    }
  }
  _log.warning('No browser opener accepted the URL');
  return false;
}

/// Runs one opener and reports whether it took the URL.
///
/// A process still alive after [settleWindow] counts as a success: half the
/// chain never exits on its own, so waiting for an exit code would time out
/// on the browser we just launched and send us on to the next opener,
/// stacking up a second and third browser window.
///
/// [settleWindow] is injectable only so tests need not wait three seconds.
@visibleForTesting
Future<bool> spawnBrowserOpener(
  String executable,
  List<String> arguments, {
  Duration settleWindow = _openerSettleWindow,
}) async {
  final process = await Process.start(executable, arguments);
  // Drained, not awaited: a browser started as our child would otherwise
  // block forever once it filled the 64KB pipe buffer.
  unawaited(process.stdout.drain<void>());
  unawaited(process.stderr.drain<void>());
  final exitCode = await process.exitCode.timeout(
    settleWindow,
    onTimeout: () => 0,
  );
  return exitCode == 0;
}

// coverage:ignore-start
// The real url_launcher call. Exercised by manual desktop smoke tests; every
// caller in the app goes through openInBrowser, whose ordering and command
// shapes ARE unit tested via injected doubles.
Future<bool> _launchExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
// coverage:ignore-end
