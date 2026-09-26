import 'dart:async';

import 'package:app_links/app_links.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';

/// Where incoming links come from. An interface so tests, and the app's own
/// widget tests, never open the platform channel.
abstract interface class IncomingLinkSource {
  Stream<Uri> get links;
}

/// `app_links`: the link that launched the app arrives through the same
/// stream as later ones, on iOS, Android and macOS.
class AppLinksSource implements IncomingLinkSource {
  AppLinksSource([AppLinks? appLinks]) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Stream<Uri> get links => _appLinks.uriLinkStream;
}

final incomingLinkSourceProvider = Provider<IncomingLinkSource>(
  (ref) => AppLinksSource(),
);

/// Turns incoming links into opened passports (spec 13.2): passport tags
/// only, each once, and none before the app can show one.
class PassportLinkDispatcher {
  PassportLinkDispatcher({
    required IncomingLinkSource source,
    required Future<void> Function(String tagText) open,
    DateTime Function()? clock,
    Duration repeatWindow = const Duration(seconds: 2),
  }) : _source = source,
       _open = open,
       _clock = clock ?? DateTime.now,
       _repeatWindow = repeatWindow;

  final IncomingLinkSource _source;
  final Future<void> Function(String tagText) _open;
  final DateTime Function() _clock;
  final Duration _repeatWindow;

  StreamSubscription<Uri>? _subscription;
  bool _ready = false;
  String? _pending;
  String? _lastText;
  DateTime? _lastAt;

  void start() {
    _subscription ??= _source.links.listen(
      _onLink,
      // One unreadable link must not end the subscription.
      onError: (Object _) {},
    );
  }

  /// Ready once a diver exists; a link that arrived before then opens now.
  void setReady(bool ready) {
    _ready = ready;
    final pending = _pending;
    if (!ready || pending == null) return;
    _pending = null;
    unawaited(_open(pending));
  }

  void _onLink(Uri uri) {
    final text = uri.toString();
    // An OAuth callback, a future /f record link, any other page: not ours.
    if (PassportPayloadCodec.extractQuery(text) == null) return;
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
      unawaited(_open(text));
    } else {
      _pending = text;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
