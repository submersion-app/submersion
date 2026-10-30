import 'dart:async';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';

/// A provider that may report a write done before it reaches the backend.
///
/// Git batches deletes into one commit instead of pushing once per file.
/// Callers that tell the diver a delete is complete, and the end of every
/// sync run, call [flush] first. Every other provider writes immediately and
/// does not implement this.
abstract interface class DeferredWriteProvider {
  /// Pushes every deferred write now.
  ///
  /// With [timeout], throws a [TimeoutException] once the flush's own push
  /// has run that long. Waiting behind earlier writes, and for the spacing
  /// between pushes, does not count; a push that runs out may still land.
  Future<void> flush({Duration? timeout});
}

/// A provider whose backend keeps deleted data in history until told to drop
/// it (Git). Privacy-motivated deletes call [resetHistoryNow] afterwards.
abstract interface class HistoryResettable {
  /// Flushes deferred writes, then replaces the stored history with the
  /// current files.
  Future<void> resetHistoryNow();
}

/// Flushes [provider]'s deferred writes, if it defers any; [timeout] as in
/// [DeferredWriteProvider.flush].
Future<void> flushDeferredWrites(
  CloudStorageProvider provider, {
  Duration? timeout,
}) async {
  if (provider is DeferredWriteProvider) {
    await (provider as DeferredWriteProvider).flush(timeout: timeout);
  }
}

/// Drops deleted data from [provider]'s history, if it keeps any.
Future<void> resetHistoryNowIfSupported(CloudStorageProvider provider) async {
  if (provider is HistoryResettable) {
    await (provider as HistoryResettable).resetHistoryNow();
  }
}
