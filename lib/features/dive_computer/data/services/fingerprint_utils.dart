import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
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

/// The fingerprint to save as the next download's resume point once
/// [importedDives] are stored, or null to keep the one already saved.
///
/// The next download stops at the saved fingerprint, so it must never sit
/// above a dive that has not arrived yet. After a complete download every
/// new dive arrived and the newest one is safe. After an interrupted one
/// that only holds when the backend delivers oldest-first, as the patched
/// Shearwater Petrel driver does (issue #480): what arrived is then the
/// oldest run of new dives. A newest-first backend that stopped part way
/// delivered the newest dives and missed older ones, and resuming from the
/// newest of them hid those older dives for good (issue #2902).
String? selectResumeFingerprint(
  List<DownloadedDive> importedDives, {
  required bool downloadComplete,
  required bool deliversOldestFirst,
}) {
  if (!downloadComplete && !deliversOldestFirst) return null;
  return selectNewestFingerprint(importedDives);
}

/// Whether the backend behind [model] delivers dives oldest-first, read
/// from the native descriptor catalog.
///
/// A model that cannot be found counts as newest-first, libdivecomputer's
/// own order. Guessing that wrong only re-offers dives already imported;
/// guessing the other way can skip dives that never arrived.
bool modelDeliversOldestFirst(
  List<pigeon.DeviceDescriptor> descriptors,
  DeviceModel? model,
) {
  if (model == null) return false;
  final dcModel = model.dcModel;
  for (final descriptor in descriptors) {
    if (descriptor.vendor == model.manufacturer &&
        descriptor.product == model.model &&
        (dcModel == null || descriptor.model == dcModel)) {
      return descriptor.deliversOldestFirst;
    }
  }
  return false;
}
