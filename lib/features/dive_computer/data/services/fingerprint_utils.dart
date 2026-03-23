import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';

/// Select the fingerprint of the newest dive (by startTime) from a list.
///
/// Only considers dives that have a non-null fingerprint.
/// Returns null if the list is empty or no dives have fingerprints.
///
/// IMPORTANT: Call this with only successfully imported dives,
/// not all downloaded dives.
String? selectNewestFingerprint(List<DownloadedDive> dives) {
  if (dives.isEmpty) return null;

  final divesWithFingerprints = dives
      .where((d) => d.fingerprint != null)
      .toList();

  if (divesWithFingerprints.isEmpty) return null;

  divesWithFingerprints.sort((a, b) => b.startTime.compareTo(a.startTime));
  return divesWithFingerprints.first.fingerprint;
}
