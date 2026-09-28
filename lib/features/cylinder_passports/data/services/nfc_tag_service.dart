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

  /// The message the phone read when it found the tag (null for an empty
  /// tag). Both platforms read it before reporting the tag, and iOS skips a
  /// tag it could not read, so a scan needs no second read.
  NdefMessage? get discoveredMessage;

  Future<NdefMessage?> read();

  Future<void> write(NdefMessage message);
}

/// The diver closed the system NFC sheet, or [NfcTagService.cancel] ran.
class NfcSessionCancelled implements Exception {
  const NfcSessionCancelled();
}

/// The system ended the session on its own: it timed out, the system was
/// busy, or NFC is not allowed here. Unlike a cancel, the diver is told.
class NfcSessionFailed implements Exception {
  const NfcSessionFailed(this.message);

  final String message;

  @override
  String toString() => 'NfcSessionFailed: $message';
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

  /// Whether a session is running, from its start until it has stopped. On
  /// iOS its system sheet is over the app all that time.
  bool get sessionActive;

  /// Waits for a tag, runs [onTag] with it (null when it cannot hold NDEF),
  /// ends the session and returns [onTag]'s result. [promptIos] is shown on
  /// the iOS system sheet, which then closes as [iosEnd] says for the result,
  /// or with [iosFailure] when [onTag] throws. Throws [NfcSessionCancelled]
  /// when the diver dismisses that sheet or [cancel] is called while no tag
  /// is being handled (a tag already being written finishes first), and
  /// [NfcSessionFailed] when the system ends the session.
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
  bool get sessionActive => false;

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
