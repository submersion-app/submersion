import 'package:ndef_record/ndef_record.dart';

/// Whether this device can read and write NFC tags right now.
enum NfcSupport { enabled, disabled, unsupported }

/// One NFC tag that can hold NDEF, as the passport write and read need it.
abstract interface class NdefTagHandle {
  bool get isWritable;

  /// The largest NDEF message the tag takes, in bytes, as the phone
  /// reports it (the TLV wrapper is not counted).
  int get maxMessageBytes;

  /// The platform's name for the tag type, when it gives one.
  String? get typeLabel;

  Future<NdefMessage?> read();

  Future<void> write(NdefMessage message);
}

/// The diver closed the system NFC sheet, or [NfcTagService.cancel] ran.
class NfcSessionCancelled implements Exception {
  const NfcSessionCancelled();
}

/// How the iOS system sheet closes after a tag: [alert] shows as a
/// success, [error] as a failure. Without one iOS shows a success checkmark,
/// which would contradict a failed write.
class IosSheetEnd {
  const IosSheetEnd.success([this.alert]) : error = null;

  const IosSheetEnd.failure(String this.error) : alert = null;

  final String? alert;
  final String? error;
}

/// NFC sessions, one tag at a time.
abstract interface class NfcTagService {
  Future<NfcSupport> support();

  /// Waits for a tag, runs [onTag] with it (null when it cannot hold NDEF),
  /// ends the session and returns [onTag]'s result. [promptIos] is shown on
  /// the iOS system sheet, which then closes as [iosEnd] says for the result,
  /// or with [iosFailure] when [onTag] throws. Throws [NfcSessionCancelled]
  /// when the diver dismisses that sheet or [cancel] is called.
  Future<T> withTag<T>({
    required String promptIos,
    required Future<T> Function(NdefTagHandle? tag) onTag,
    IosSheetEnd Function(T result)? iosEnd,
    String? iosFailure,
  });

  /// Ends a waiting session.
  Future<void> cancel();
}

/// Where there is no NFC: desktop, web, and tests by default.
class UnsupportedNfcTagService implements NfcTagService {
  const UnsupportedNfcTagService();

  @override
  Future<NfcSupport> support() async => NfcSupport.unsupported;

  @override
  Future<T> withTag<T>({
    required String promptIos,
    required Future<T> Function(NdefTagHandle? tag) onTag,
    IosSheetEnd Function(T result)? iosEnd,
    String? iosFailure,
  }) => Future<T>.error(StateError('NFC is not supported on this device'));

  @override
  Future<void> cancel() async {}
}
