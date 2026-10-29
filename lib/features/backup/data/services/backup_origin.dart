import 'package:equatable/equatable.dart';

import 'package:submersion/features/backup/data/services/backup_attribution.dart';

/// Which device made a backup, as the history row names it (issue #3651).
sealed class BackupOrigin extends Equatable {
  const BackupOrigin();

  @override
  List<Object?> get props => const [];
}

/// Made by this device.
class BackupFromThisDevice extends BackupOrigin {
  const BackupFromThisDevice();
}

/// Made by a sync peer that published [name] on its manifest.
class BackupFromNamedDevice extends BackupOrigin {
  final String name;

  const BackupFromNamedDevice(this.name);

  @override
  List<Object?> get props => [name];
}

/// Made by some other device whose name this device has not learned.
class BackupFromAnotherDevice extends BackupOrigin {
  const BackupFromAnotherDevice();
}

/// Names the device behind each backup from the tag in its filename (see
/// backup_attribution.dart), matched against this device's id and the names
/// sync peers publish.
///
/// The tag is a hash, so a peer's name is found by hashing each known peer
/// id the same way. Nothing new is written into a backup or its name: a
/// shared cloud folder still reveals nothing about the devices behind it.
class BackupOriginResolver {
  BackupOriginResolver({
    required String? thisDeviceId,
    required Map<String, String> peerDeviceNames,
  }) : _thisTag = thisDeviceId == null || thisDeviceId.isEmpty
           ? null
           : deviceTag(thisDeviceId),
       _peerNamesByTag = {
         for (final e in peerDeviceNames.entries)
           if (e.key.isNotEmpty && e.value.isNotEmpty)
             deviceTag(e.key): e.value,
       };

  final String? _thisTag;
  final Map<String, String> _peerNamesByTag;

  /// Who made the backup called [filename], or null when that cannot be
  /// said: a name with no tag (written before attribution shipped, a
  /// pre-migration copy, a file renamed by hand), or an unnamed tag while
  /// this device's own id is unknown, since that tag may well be this
  /// device's.
  BackupOrigin? originOf(String filename) {
    final tag = backupDeviceTagFromFilename(filename);
    if (tag == null) return null;
    if (tag == _thisTag) return const BackupFromThisDevice();
    final name = _peerNamesByTag[tag];
    if (name != null) return BackupFromNamedDevice(name);
    return _thisTag == null ? null : const BackupFromAnotherDevice();
  }
}
