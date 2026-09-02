import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/imported_computer_identity.dart';

/// Namespace for deterministic gear-twin ids (v175).
///
/// Frozen: every device must derive the same equipment id for the same
/// registered computer, so changing this would fork one gear item into one per
/// device across a synced fleet.
const String kDiveComputerGearNamespace =
    '9f2b6c41-7d3e-4a58-9c0f-1e5a8d47b2c6';

/// The id of the equipment row representing [computerId] as gear.
///
/// Derived from the registry id, which is stable and synced, rather than from
/// model or serial text, which a user can rename. A minted row cannot use v4:
/// two devices registering the same computer would mint different primary keys
/// and duplicate instead of merging under sync upsert.
String diveComputerGearId(String computerId) => const Uuid().v5(
  kDiveComputerGearNamespace,
  'submersion:dive-computer-gear:$computerId',
);

/// An equipment row reduced to the fields the gear-twin match needs.
///
/// Lets the rule live in one place: the repository builds these from Drift
/// rows, the v175 migration backfill from raw rows.
class GearTwinCandidate {
  const GearTwinCandidate({
    required this.id,
    this.diverId,
    this.brand,
    this.model,
    this.serialNumber,
  });

  final String id;
  final String? diverId;
  final String? brand;
  final String? model;
  final String? serialNumber;
}

/// The existing gear item that already represents this computer, if exactly
/// one does.
///
/// Callers pass only candidates that are active equipment of type `computer`.
///
/// The serial is the strong signal, but libdivecomputer leaves it null for many
/// devices (#1064), so a serial-only rule would be dead for a large share of
/// users. With no serial the rule falls back to brand plus model.
///
/// Returns null when zero or several candidates match. Guessing between two
/// identical computers is worse than minting a second row: a wrong adoption
/// silently attaches one device's service history to another device's dives.
GearTwinCandidate? matchGearTwin({
  required String? manufacturer,
  required String? model,
  required String? serialNumber,
  required String? diverId,
  required Iterable<GearTwinCandidate> candidates,
}) {
  final wantDiver = normalizeComputerIdentityPart(diverId);
  final wantSerial = normalizeComputerIdentityPart(serialNumber);
  final wantBrand = normalizeComputerIdentityPart(manufacturer);
  final wantModel = normalizeComputerIdentityPart(model);

  // With no serial and no model there is no identity to match on, and every
  // blank-identity gear item would collide.
  if (wantSerial.isEmpty && wantModel.isEmpty) return null;

  final matches = candidates.where((c) {
    if (normalizeComputerIdentityPart(c.diverId) != wantDiver) return false;
    if (wantSerial.isNotEmpty) {
      return normalizeComputerIdentityPart(c.serialNumber) == wantSerial;
    }
    return normalizeComputerIdentityPart(c.brand) == wantBrand &&
        normalizeComputerIdentityPart(c.model) == wantModel;
  }).toList();

  return matches.length == 1 ? matches.first : null;
}
