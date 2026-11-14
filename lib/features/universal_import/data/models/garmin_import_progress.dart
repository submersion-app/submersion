/// The stages of an import from a connected Garmin watch, in order.
enum GarminImportPhase {
  /// Detecting connected watches: mounted drives, then MTP devices.
  lookingForWatch,

  /// Listing the GARMIN/Activity folder of a watch connected over MTP.
  /// The device reports no count while it does this.
  scanning,

  /// Copying the activity files off a watch connected over MTP.
  copying,

  /// Parsing each activity file to keep only the dives.
  checking,
}

/// Where an import from a Garmin watch has got to (issue #4223), so the
/// Import page can say what is happening instead of a bare spinner.
class GarminImportProgress {
  const GarminImportProgress(
    this.phase, {
    this.current = 0,
    this.total = 0,
    this.deviceName,
  });

  final GarminImportPhase phase;

  /// Files handled so far / files in this phase. Both 0 when the phase has
  /// no count ([GarminImportPhase.lookingForWatch], [GarminImportPhase.scanning]).
  final int current;
  final int total;

  /// The watch's name as the user knows it, such as "Garmin Descent G2".
  final String? deviceName;

  /// True when [current] of [total] is a meaningful fraction.
  bool get hasCount => total > 0;

  double get fraction => hasCount ? (current / total).clamp(0.0, 1.0) : 0;
}
