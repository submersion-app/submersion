import 'package:path/path.dart' as p;

import 'package:submersion/features/backup/data/services/backup_attribution.dart';

/// Pin markers: how a pin made on one device is seen by the others
/// (issue #3503).
///
/// Pins live in each device's own SharedPreferences ledger, which no other
/// device can read. A device that prunes the shared cloud folder across
/// devices needs to know about every pin, so pinning a backup with a cloud
/// copy also puts an empty marker file beside it.
///
/// One marker per pinning device, never one per backup: when two devices pin
/// the same backup and one unpins it, deleting a shared marker would silently
/// unpin it for the other. The name is fixed once shipped, for the same
/// reason as the device tag: markers already in shared folders have to keep
/// parsing.

/// The extension every marker carries. Not a backup extension, so listings
/// that keep only `.db`/`.sbe` backups never mistake a marker for a backup.
const String pinMarkerExtension = '.pin';

/// Separates the backup's name from the pinning device's tag.
const String _pinnerMarker = '__p';

/// A parsed marker: which backup it pins and which device pinned it.
typedef PinMarker = ({String backupStem, String deviceTag});

/// [filename] without its `.db`/`.sbe` extension. A backup kept locally as
/// `X.db` is uploaded as `X.sbe` when encryption is on, so the stem is what
/// names "this backup" across both.
String backupStem(String filename) => p.basenameWithoutExtension(filename);

/// The marker [pinningDeviceId] writes to pin [backupFilename].
String pinMarkerName({
  required String backupFilename,
  required String pinningDeviceId,
}) =>
    '${backupStem(backupFilename)}$_pinnerMarker'
    '${deviceTag(pinningDeviceId)}$pinMarkerExtension';

/// The marker [name] describes, or null when it is not exactly a marker.
PinMarker? parsePinMarker(String name) {
  if (!name.startsWith(backupFilePrefix)) return null;
  if (!name.endsWith(pinMarkerExtension)) return null;
  final body = name.substring(0, name.length - pinMarkerExtension.length);
  final at = body.lastIndexOf(_pinnerMarker);
  if (at <= backupFilePrefix.length) return null;
  final tag = body.substring(at + _pinnerMarker.length);
  if (!isDeviceTag(tag)) return null;
  return (backupStem: body.substring(0, at), deviceTag: tag);
}
