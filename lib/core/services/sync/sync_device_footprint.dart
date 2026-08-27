/// How a device's files on the backend relate to the library in use now.
enum SyncDeviceFootprintState {
  /// Publishing into the epoch this library is on. A working peer.
  active,

  /// Stamped with a DIFFERENT library epoch: left behind by a replace or a
  /// rebuild and inert to every current-epoch device. These are the "shadow
  /// copies" users notice piling up on their cloud folder (issue #1032) --
  /// they consume space and explain nothing, but nothing collects them.
  staleEpoch,

  /// Carries a durable retirement marker. The fleet has fenced it off; its
  /// leftovers are swept opportunistically.
  retired,

  /// Files exist but no manifest could be read -- an interrupted publish, or
  /// an encrypted library this device cannot decrypt. Deliberately NOT called
  /// stale: without a manifest there is no epoch to judge it by, and deleting
  /// on that basis could destroy a publish still in flight.
  unreadable,
}

/// One device's whole footprint on a sync backend: what it published, how much
/// space it holds, and whether it still matters.
///
/// Assembled by listing the sync folder and grouping by the device id encoded
/// in each filename, so it covers devices whose manifest is missing as well as
/// healthy peers.
class SyncDeviceFootprint {
  const SyncDeviceFootprint({
    required this.deviceId,
    required this.state,
    required this.fileCount,
    required this.byteCount,
    this.deviceName,
    this.isSelf = false,
    this.lastModified,
    this.publishedAt,
    this.schemaVersion,
    this.epochId,
  });

  final String deviceId;
  final SyncDeviceFootprintState state;

  /// Files on the backend carrying this device id, retirement marker included.
  final int fileCount;

  /// Summed file sizes. Providers may not report a size, and those count zero,
  /// so treat this as a floor rather than an exact total.
  final int byteCount;

  /// Published display name, absent on legacy manifests and on devices that
  /// nothing identifies by name. Callers fall back to a short id.
  final String? deviceName;

  /// This install's own footprint. Never offered for deletion through the peer
  /// path -- removing your own files is what "Remove this device's cloud
  /// files" does, and it carries no retirement fence.
  final bool isSelf;

  /// Newest backend mtime across the device's files. Survives a missing
  /// manifest, so it is the only freshness signal for an [unreadable]
  /// footprint.
  final DateTime? lastModified;

  /// The publisher's own timestamp from its manifest. Preferred over
  /// [lastModified] when present: it is what the retirement sweep judges by.
  /// Note a liveness heartbeat moves it without any data change.
  final DateTime? publishedAt;

  final int? schemaVersion;
  final String? epochId;

  /// Deleting this device's files cannot lose anything the current library
  /// still depends on.
  bool get isSafeToRemove =>
      !isSelf &&
      (state == SyncDeviceFootprintState.staleEpoch ||
          state == SyncDeviceFootprintState.retired);

  /// Short, stable label for a device with no published name.
  String get shortId =>
      deviceId.length <= 8 ? deviceId : deviceId.substring(0, 8);
}
