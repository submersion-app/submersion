import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/providers/provider.dart';

/// An Android phone acting as an NFC tag (host card emulation) that holds
/// the diver's buddy card link while the swap screen is open (issue #3728).
/// Another phone reads it like any NFC tag; iPhones can only read.
abstract interface class CardEmulation {
  Future<bool> isSupported();

  /// Presents [ndefMessage], a complete NDEF message, until [stop].
  Future<void> start(Uint8List ndefMessage);

  Future<void> stop();
}

/// Android's `CardEmulationService`, driven over
/// `app.submersion/card_emulation`.
class ChannelCardEmulation implements CardEmulation {
  const ChannelCardEmulation([
    this._channel = const MethodChannel('app.submersion/card_emulation'),
  ]);

  final MethodChannel _channel;

  @override
  Future<bool> isSupported() async =>
      await _channel.invokeMethod<bool>('isSupported') ?? false;

  @override
  Future<void> start(Uint8List ndefMessage) =>
      _channel.invokeMethod('start', ndefMessage);

  @override
  Future<void> stop() => _channel.invokeMethod('stop');
}

/// Everywhere a phone cannot be a tag: iOS, desktop, web, tests.
class UnsupportedCardEmulation implements CardEmulation {
  const UnsupportedCardEmulation();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<void> start(Uint8List ndefMessage) async {}

  @override
  Future<void> stop() async {}
}

final cardEmulationProvider = Provider<CardEmulation>((ref) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return const ChannelCardEmulation();
  }
  return const UnsupportedCardEmulation();
});
