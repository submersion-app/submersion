import 'dart:async';

import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';

final _log = LoggerService.forClass(NfcManagerTagService);

/// [NfcTagService] over `nfc_manager` on iOS and Android. Runs on a device
/// only; the device checklist covers it.
class NfcManagerTagService implements NfcTagService {
  void Function()? _cancelPending;

  @override
  Future<NfcSupport> support() async {
    try {
      return switch (await NfcManager.instance.checkAvailability()) {
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
  }) async {
    final result = Completer<T>();
    void cancelled() {
      if (!result.isCompleted) {
        result.completeError(const NfcSessionCancelled());
      }
    }

    _cancelPending = cancelled;
    try {
      await NfcManager.instance.startSession(
        // NTAG21x and most cylinder tags are ISO 14443 type A.
        pollingOptions: const {NfcPollingOption.iso14443},
        alertMessageIos: promptIos,
        // The write reads back in the same session, so keep it open.
        invalidateAfterFirstReadIos: false,
        onDiscovered: (tag) async {
          if (result.isCompleted) return;
          try {
            final ndef = Ndef.from(tag);
            final value = await onTag(ndef == null ? null : _NdefHandle(ndef));
            if (!result.isCompleted) result.complete(value);
          } catch (e, stackTrace) {
            if (!result.isCompleted) result.completeError(e, stackTrace);
          }
        },
        onSessionErrorIos: (_) => cancelled(),
      );
      return await result.future;
    } finally {
      _cancelPending = null;
      try {
        await NfcManager.instance.stopSession();
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
