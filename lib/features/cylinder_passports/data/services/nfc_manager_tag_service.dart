import 'dart:async';

import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';

final _log = LoggerService.forClass(NfcManagerTagService);

/// [NfcTagService] over `nfc_manager` on iOS and Android. The device
/// checklist covers the real hardware; the session handling is tested with
/// an injected [NfcManager].
class NfcManagerTagService implements NfcTagService {
  NfcManagerTagService({
    NfcManager? manager,
    NdefTagHandle? Function(NfcTag tag)? handleFor,
  }) : _managerOverride = manager,
       _handleFor = handleFor ?? _ndefHandleFor;

  final NfcManager? _managerOverride;
  final NdefTagHandle? Function(NfcTag tag) _handleFor;
  void Function()? _cancelPending;

  /// Read lazily: [NfcManager.instance] throws on platforms without NFC.
  NfcManager get _manager => _managerOverride ?? NfcManager.instance;

  static NdefTagHandle? _ndefHandleFor(NfcTag tag) {
    final ndef = Ndef.from(tag);
    return ndef == null ? null : _NdefHandle(ndef);
  }

  @override
  Future<NfcSupport> support() async {
    try {
      return switch (await _manager.checkAvailability()) {
        NfcAvailability.enabled => NfcSupport.enabled,
        NfcAvailability.disabled => NfcSupport.disabled,
        NfcAvailability.unsupported => NfcSupport.unsupported,
      };
    } catch (e, stackTrace) {
      _log.warning(
        'NFC availability check failed',
        error: e,
        stackTrace: stackTrace,
      );
      return NfcSupport.unsupported;
    }
  }

  @override
  Future<T> withTag<T>({
    required String promptIos,
    required Future<T> Function(NdefTagHandle? tag) onTag,
    IosSheetEnd Function(T result)? iosEnd,
    String? iosFailure,
  }) async {
    final result = Completer<T>();
    // How the iOS sheet closes; none after a cancel, which already closed it.
    IosSheetEnd? end;
    // Only the first tag is handled: a tag that stays in the field can be
    // reported again before its write finishes.
    var handling = false;
    void cancelled() {
      if (!result.isCompleted) {
        result.completeError(const NfcSessionCancelled());
      }
    }

    _cancelPending = cancelled;
    try {
      await _manager.startSession(
        // NTAG21x and most cylinder tags are ISO 14443 type A.
        pollingOptions: const {NfcPollingOption.iso14443},
        alertMessageIos: promptIos,
        // Left at its default (true): false makes nfc_manager restart
        // polling right after reporting a tag, which invalidates that tag
        // before Dart can write to it. The session itself stays open until
        // stopSession below.
        onDiscovered: (tag) async {
          if (handling || result.isCompleted) return;
          handling = true;
          try {
            final value = await onTag(_handleFor(tag));
            end = iosEnd?.call(value);
            if (!result.isCompleted) result.complete(value);
          } catch (e, stackTrace) {
            if (iosFailure != null) end = IosSheetEnd.failure(iosFailure);
            if (!result.isCompleted) result.completeError(e, stackTrace);
          }
        },
        onSessionErrorIos: (_) => cancelled(),
      );
      return await result.future;
    } finally {
      _cancelPending = null;
      try {
        await _manager.stopSession(
          alertMessageIos: end?.alert,
          errorMessageIos: end?.error,
        );
      } catch (e, stackTrace) {
        // Already ended by the system sheet or an error: nothing to stop.
        _log.info(
          'NFC session was already closed',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  @override
  Future<void> cancel() async {
    final cancel = _cancelPending;
    _cancelPending = null;
    cancel?.call();
  }
}

class _NdefHandle implements NdefTagHandle {
  _NdefHandle(this._ndef);

  final Ndef _ndef;

  @override
  bool get isWritable => _ndef.isWritable;

  @override
  int get maxMessageBytes => _ndef.maxSize;

  @override
  String? get typeLabel => _ndef.additionalData['type'] as String?;

  @override
  Future<NdefMessage?> read() => _ndef.read();

  @override
  Future<void> write(NdefMessage message) => _ndef.write(message: message);
}
