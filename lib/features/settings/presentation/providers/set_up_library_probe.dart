import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/sync_device_footprint.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/settings/presentation/providers/sync_device_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

final _log = LoggerService.forClass(SetUpLibrary);

/// What the sync account holds, as step 2 of Set up this device reads it
/// (issue #3482, spec 6.4). It names the library by device and time only:
/// the manifest carries no dive count.
sealed class SetUpLibrary {
  const SetUpLibrary();
}

/// No library yet: the dives here become the one every device shares.
final class NoLibrary extends SetUpLibrary {
  const NoLibrary(this.localDives);
  final int localDives;
}

/// A library to download, combine with or replace this device's dives by.
final class LibraryFound extends SetUpLibrary {
  const LibraryFound({
    required this.localDives,
    this.deviceName,
    this.changedAt,
  });
  final int localDives;

  /// The device that last changed it and when, where its manifest says.
  final String? deviceName;
  final DateTime? changedAt;
}

/// Encrypted, and this device has no key for it yet.
final class LibraryLocked extends SetUpLibrary {
  const LibraryLocked();
}

/// Another device's upload was left unfinished.
final class LibraryIncomplete extends SetUpLibrary {
  const LibraryIncomplete();
}

/// The library was replaced since this device last accepted it, and this
/// device has dives the adopt would set aside.
final class LibraryAwaitingAdoption extends SetUpLibrary {
  const LibraryAwaitingAdoption(this.marker);
  final LibraryEpochMarker marker;
}

/// The account could not be read.
final class LibraryUnreachable extends SetUpLibrary {
  const LibraryUnreachable();
}

/// How many dives this device holds; re-counted when the dives change (a
/// combine or a replace downloads some).
final setUpLocalDiveCountProvider = FutureProvider.autoDispose<int>((ref) {
  final dives = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(dives.watchDivesChanges());
  return dives.getDiveCount();
});

/// Whether the sync account holds a library, as first contact classifies it.
final setUpPeerLibraryStateProvider =
    FutureProvider.autoDispose<PeerLibraryState>((ref) async {
      final provider = ref.watch(cloudStorageProviderProvider);
      if (provider == null) throw StateError('No sync account selected');
      final localDives = await ref.watch(setUpLocalDiveCountProvider.future);
      return ref
          .watch(syncInitializerProvider)
          .firstContactLibraryState(
            provider,
            localLibraryIsEmpty: localDives == 0,
          );
    });

/// The replace marker this device has not accepted, as Sync now reads it
/// before the first sync.
final setUpReplaceMarkerProvider =
    FutureProvider.autoDispose<LibraryEpochMarker?>(
      (ref) => ref.read(syncStateProvider.notifier).libraryReplaceInfo(),
    );

/// Step 2's reading of the account. Invalidate it to read again (Check
/// again, after an unlock).
final setUpLibraryProvider = FutureProvider.autoDispose<SetUpLibrary>((
  ref,
) async {
  final PeerLibraryState peers;
  try {
    peers = await ref.watch(setUpPeerLibraryStateProvider.future);
  } on Object catch (e, stackTrace) {
    _log.warning(
      'Could not read the sync account for set up',
      error: e,
      stackTrace: stackTrace,
    );
    return const LibraryUnreachable();
  }
  final localDives = await ref.watch(setUpLocalDiveCountProvider.future);
  switch (peers) {
    case PeerLibraryState.none:
      return NoLibrary(localDives);
    case PeerLibraryState.incomplete:
      return const LibraryIncomplete();
    case PeerLibraryState.pullable:
      break;
  }
  // A device with no dives adopts a replaced library silently on its first
  // sync; there is nothing to set aside.
  if (localDives > 0) {
    final marker = await ref.watch(setUpReplaceMarkerProvider.future);
    if (marker != null) return LibraryAwaitingAdoption(marker);
  }
  final peerFootprints = [
    for (final f in await ref.watch(syncDeviceFootprintListProvider.future))
      if (!f.isSelf &&
          (f.state == SyncDeviceFootprintState.active ||
              f.state == SyncDeviceFootprintState.unreadable))
        f,
  ];
  final readable = peerFootprints
      .where((f) => f.state == SyncDeviceFootprintState.active)
      .toList();
  if (peerFootprints.isNotEmpty && readable.isEmpty) {
    return const LibraryLocked();
  }
  final newest = readable
      .sortedBy<DateTime>((f) => f.publishedAt ?? f.lastModified ?? DateTime(0))
      .lastOrNull;
  return LibraryFound(
    localDives: localDives,
    deviceName: newest?.deviceName,
    changedAt: newest?.publishedAt ?? newest?.lastModified,
  );
});

/// Reads the account again (Check again, after an unlock): every input, not
/// only the combination, which would serve their cached answers.
void refreshSetUpLibrary(void Function(ProviderOrFamily provider) invalidate) {
  invalidate(setUpPeerLibraryStateProvider);
  invalidate(setUpReplaceMarkerProvider);
  invalidate(setUpLocalDiveCountProvider);
  invalidate(syncDeviceFootprintListProvider);
  invalidate(setUpLibraryProvider);
}
