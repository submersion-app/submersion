import 'dart:async';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_codec.dart';
import 'package:submersion/features/cylinder_passports/presentation/services/passport_link_dispatcher.dart';

final _log = LoggerService.forClass(BuddyCardLinkDispatcher);

/// One subscription to a platform link source, shared by every listener.
///
/// Passport and buddy card links arrive on the same `app_links` stream, and
/// a plugin may emit the link that launched the app the moment it is first
/// listened to. Each dispatcher listens here first; [connect] then
/// subscribes to the platform once, so neither misses the launch link.
class SharedIncomingLinks implements IncomingLinkSource {
  SharedIncomingLinks(this._inner);

  final IncomingLinkSource _inner;
  final _controller = StreamController<String>.broadcast();
  StreamSubscription<String>? _subscription;

  @override
  Stream<String> get links => _controller.stream;

  void connect() {
    _subscription ??= _inner.links.listen(
      _controller.add,
      onError: _controller.addError,
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}

/// Opens buddy card links (`https://submersion.app/b#...`, issue #3728)
/// scanned with the phone's own camera or read from an NFC tag: each once,
/// and none before the app can show the preview.
class BuddyCardLinkDispatcher {
  BuddyCardLinkDispatcher({
    required IncomingLinkSource source,
    required Future<void> Function(String text) open,
    bool Function(String text)? alreadyHandled,
    DateTime Function()? clock,
    Duration repeatWindow = const Duration(seconds: 2),
  }) : _source = source,
       _open = open,
       _alreadyHandled = alreadyHandled,
       _clock = clock ?? DateTime.now,
       _repeatWindow = repeatWindow;

  final IncomingLinkSource _source;
  final Future<void> Function(String text) _open;

  /// Whether the app itself just read or wrote [text] over NFC: Android
  /// then delivers a tag still held as a link, which is dropped.
  final bool Function(String text)? _alreadyHandled;
  final DateTime Function() _clock;
  final Duration _repeatWindow;

  StreamSubscription<String>? _subscription;
  bool _ready = false;
  String? _pending;
  String? _lastText;
  DateTime? _lastAt;

  void start() {
    _subscription ??= _source.links.listen(
      _onLink,
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

  void _openContained(String text) {
    unawaited(
      _open(text).catchError((Object e, StackTrace stackTrace) {
        _log.error(
          'Failed to open a buddy card link',
          error: e,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  void _onLink(String text) {
    if (!BuddyCardCodec.isCardLink(text)) return;
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
