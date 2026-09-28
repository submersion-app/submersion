import 'dart:async';

import 'package:ndef_record/ndef_record.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';

/// A tag that stores what is written and reads it back, unless told to
/// fail or to read back something else.
class FakeTagHandle implements NdefTagHandle {
  FakeTagHandle({
    this.isWritable = true,
    this.maxMessageBytes = 496,
    this.typeLabel = 'org.nfcforum.ndef.type2',
    this.stored,
    this.writeError,
    this.readError,
    this.readBackOverride,
  }) : discoveredMessage = stored;

  @override
  final bool isWritable;

  @override
  final int maxMessageBytes;

  @override
  final String? typeLabel;

  /// What [stored] held when the tag was found.
  @override
  final NdefMessage? discoveredMessage;

  NdefMessage? stored;
  Object? writeError;
  Object? readError;
  NdefMessage? readBackOverride;
  int writes = 0;

  @override
  Future<NdefMessage?> read() async {
    if (readError case final error?) throw error;
    return readBackOverride ?? stored;
  }

  @override
  Future<void> write(NdefMessage message) async {
    writes++;
    if (writeError case final error?) throw error;
    stored = message;
  }
}

/// A session that hands [tag] (null: a tag that cannot hold NDEF) straight
/// to the caller, or reports the diver closing it when [cancelled].
class FakeNfcTagService implements NfcTagService {
  FakeNfcTagService({
    this.supportValue = NfcSupport.enabled,
    this.tag,
    this.cancelled = false,
    this.waitForCancel = false,
    this.sessionError,
  });

  NfcSupport supportValue;
  NdefTagHandle? tag;
  bool cancelled;

  /// Fails the session itself (not the tag), like a plugin error.
  Object? sessionError;

  /// Waits, like a real session with no tag, until [cancel] ends it.
  bool waitForCancel;
  Completer<void>? _waiting;
  int sessions = 0;
  int cancels = 0;

  /// How the last session would have closed the iOS system sheet.
  IosSheetEnd? lastIosEnd;

  /// Runs after the tag is handled and before the session would stop, the
  /// moment Android resumes its own dispatch of a tag still held.
  void Function()? beforeEnd;

  @override
  Future<NfcSupport> support() async => supportValue;

  @override
  Future<T> withTag<T>({
    required String promptIos,
    required Future<T> Function(NdefTagHandle? tag) onTag,
    IosSheetEnd Function(T result)? iosEnd,
    String? iosFailure,
  }) async {
    sessions++;
    if (cancelled) throw const NfcSessionCancelled();
    if (sessionError case final error?) throw error;
    if (waitForCancel) {
      final waiting = _waiting = Completer<void>();
      await waiting.future;
      throw const NfcSessionCancelled();
    }
    final result = await onTag(tag);
    lastIosEnd = iosEnd?.call(result);
    beforeEnd?.call();
    return result;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    final waiting = _waiting;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }
}
