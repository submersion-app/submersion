import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';

/// Where incoming links come from. An interface so tests, and the app's own
/// widget tests, never open the platform channel.
abstract interface class IncomingLinkSource {
  /// Each incoming link as the raw text it arrived as. Raw, not a parsed
  /// [Uri]: parsing repairs a stray '%' into '%25', and the passport codec
  /// refuses a broken tag only when it sees the text as written.
  Stream<String> get links;
}

/// `app_links`: the link that launched the app arrives through the same
/// stream as later ones, on iOS, Android and macOS.
class AppLinksSource implements IncomingLinkSource {
  AppLinksSource([AppLinks? appLinks]) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Stream<String> get links => _appLinks.stringLinkStream;
}

final _log = LoggerService.forClass(PassportLinkDispatcher);

/// A source with no links: the platforms where no passport link can reach
/// the app, and tests of the app root.
class NoIncomingLinks implements IncomingLinkSource {
  const NoIncomingLinks();

  @override
  Stream<String> get links => const Stream<String>.empty();
}

/// Where passport links arrive: `app_links` on iOS, Android and macOS, which
/// register the scheme and app link. Windows and Linux register no protocol
/// for passport links (spec 13.5 gives them Paste link), so nothing listens
/// there, nor on the web.
final incomingLinkSourceProvider = Provider<IncomingLinkSource>((ref) {
  if (kIsWeb) return const NoIncomingLinks();
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS ||
    TargetPlatform.android ||
    TargetPlatform.macOS => AppLinksSource(),
    _ => const NoIncomingLinks(),
  };
});

/// Turns incoming links into opened passports (spec 13.2): passport tags
/// only, each once, and none before the app can show one.
class PassportLinkDispatcher {
  PassportLinkDispatcher({
    required IncomingLinkSource source,
    required Future<void> Function(String tagText) open,
    DateTime Function()? clock,
    Duration repeatWindow = const Duration(seconds: 2),
    bool Function(String tagText)? alreadyHandled,
  }) : _source = source,
       _open = open,
       _clock = clock ?? DateTime.now,
       _repeatWindow = repeatWindow,
       _alreadyHandled = alreadyHandled;

  final IncomingLinkSource _source;
  final Future<void> Function(String tagText) _open;
  final DateTime Function() _clock;

  /// Whether the app itself just handled this tag (read or written over
  /// NFC), in which case its arrival as a link is a re-dispatch to drop.
  final bool Function(String tagText)? _alreadyHandled;
  final Duration _repeatWindow;

  StreamSubscription<String>? _subscription;
  bool _ready = false;
  String? _pending;
  String? _lastText;
  DateTime? _lastAt;

  void start() {
    _subscription ??= _source.links.listen(
      _onLink,
      // One unreadable link must not end the subscription.
      onError: (Object e, StackTrace stackTrace) => _log.warning(
        'An incoming link could not be read',
        error: e,
        stackTrace: stackTrace,
      ),
    );
  }

  /// Ready once a diver exists; a link that arrived before then opens now.
  void setReady(bool ready) {
    _ready = ready;
    final pending = _pending;
    if (!ready || pending == null) return;
    _pending = null;
    _openContained(pending);
  }

  /// Opens [text] without letting a failure escape as an unhandled error:
  /// the link is logged and the next one still opens.
  void _openContained(String text) {
    unawaited(
      _open(text).catchError((Object e, StackTrace stackTrace) {
        _log.error(
          'Failed to open an incoming link',
          error: e,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  void _onLink(String text) {
    // An OAuth callback, a future /f record link, any other page: not ours.
    if (PassportPayloadCodec.extractQuery(text) == null) return;
    if (_alreadyHandled?.call(text) ?? false) return;
    final now = _clock();
    final last = _lastAt;
    if (text == _lastText &&
        last != null &&
        now.difference(last) < _repeatWindow) {
      return;
    }
    _lastText = text;
    _lastAt = now;
    if (_ready) {
      _openContained(text);
    } else {
      _pending = text;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
