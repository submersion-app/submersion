import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/computer_serial_identity.dart';
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

/// Namespace for the id of a gear item minted to replace a deleted one
/// (issue #3676). Frozen, for the same reason as [kDiveComputerGearNamespace].
const String kDeviceGearRemintNamespace =
    '1a81efef-c5ee-4fd5-a067-3deda3379ec9';

/// Namespace for the gear item of a transmitter registered from its serial
/// (issue #3676). Frozen.
const String kTransmitterGearNamespace = 'd1e352ea-21fa-4fd9-8cd9-8a3e909f2182';

/// Namespace for a registry row the app creates for a transmitter serial it
/// saw in a download (issue #3676). Frozen.
const String kAutoTransmitterRowNamespace =
    'e9ca8f50-2513-4066-a605-9de42f7249e9';

/// The id of the gear item that replaces [replacedItemId] for the device
/// [deviceKey] stands for.
///
/// A derived id can be deleted, and its tombstone outlives it: a peer that
/// applies the tombstone would delete a new row minted at the same id. So a
/// replacement takes the next id in a chain derived from the one it replaces.
/// Every device holds the same tombstones, so every device walks the same
/// chain and mints the same row.
String nextGearRemintId(String deviceKey, String replacedItemId) =>
    const Uuid().v5(
      kDeviceGearRemintNamespace,
      'submersion:device-gear-remint:$deviceKey:$replacedItemId',
    );

/// The first id of the gear item for the transmitter [normalizedSerial] of
/// [diverId], before any deletion moves it along the [nextGearRemintId] chain.
String transmitterGearSeedId(String? diverId, String normalizedSerial) =>
    const Uuid().v5(
      kTransmitterGearNamespace,
      'submersion:transmitter-gear:${diverId ?? ''}:$normalizedSerial',
    );

/// The id of the registry row the app creates for [normalizedSerial] of
/// [diverId], so two devices that download the same serial converge on one
/// row.
String autoTransmitterRowId(String? diverId, String normalizedSerial) =>
    const Uuid().v5(
      kAutoTransmitterRowNamespace,
      'submersion:auto-transmitter:${diverId ?? ''}:$normalizedSerial',
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
/// Callers pass only candidates that are equipment of type `computer`, of
/// any status except `wanted` (#3676), and not already linked to another
/// computer.
///
/// The serial is the strong signal, but libdivecomputer leaves it null for many
/// devices (#1064), so a serial-only rule would be dead for a large share of
/// users. With no serial the rule falls back to brand plus model.
///
/// Returns null when zero or several candidates match. Guessing between two
/// identical computers is worse than minting a second row: a wrong adoption
/// silently attaches one device's service history to another device's dives.
///
/// Brand plus model is tried field by field first, then by
/// [computerNamesAgree] (#2299). A file import registers its computer with
/// the whole name as the model ("Shearwater Teric") and no manufacturer,
/// while the same logbook's gear row splits it into brand and model, so the
/// field-by-field tier alone minted a second item for the one device. The
/// looser tier runs only when the strict one finds nothing, so a computer
/// that already had a single exact twin keeps adopting it.
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

  var pool = candidates
      .where((c) => normalizeComputerIdentityPart(c.diverId) == wantDiver)
      .toList();

  if (wantSerial.isNotEmpty) {
    // The shared serial rule (#3106): Shearwater hex and decimal are one.
    final bySerial = pool
        .where(
          (c) => computerSerialsMatch(
            serialNumber,
            c.serialNumber,
            shearwater: shearwaterPair(
              manufacturerA: manufacturer,
              modelA: model,
              manufacturerB: c.brand,
              modelB: c.model,
            ),
          ),
        )
        .toList();
    if (bySerial.isNotEmpty) return _single(bySerial);
    // No item carries the serial (#3676): a diver who added the computer by
    // hand rarely typed its serial, so fall back to the name tiers, but only
    // over items with no serial. An item with a different serial is another
    // physical device and is never adopted.
    pool = [
      for (final c in pool)
        if (normalizeComputerIdentityPart(c.serialNumber).isEmpty) c,
    ];
    if (wantModel.isEmpty) return null;
  }

  final exact = pool
      .where(
        (c) =>
            normalizeComputerIdentityPart(c.brand) == wantBrand &&
            normalizeComputerIdentityPart(c.model) == wantModel,
      )
      .toList();
  if (exact.isNotEmpty) return _single(exact);

  return _single(
    pool.where(
      (c) => computerNamesAgree(
        brandA: manufacturer,
        modelA: model,
        brandB: c.brand,
        modelB: c.model,
      ),
    ),
  );
}

GearTwinCandidate? _single(Iterable<GearTwinCandidate> matches) {
  final list = matches.toList();
  return list.length == 1 ? list.first : null;
}

/// The normalized "brand model" name of a device, with the brand left off
/// when the model already starts with it, so "Shearwater" + "Teric" and
/// "Shearwater" + "Shearwater Teric" both read "shearwater teric".
String computerFullName(String? brand, String? model) {
  final b = normalizeComputerIdentityPart(brand);
  final m = normalizeComputerIdentityPart(model);
  if (b.isEmpty) return m;
  if (m.isEmpty) return b;
  if (m == b || m.startsWith('$b ')) return m;
  return '$b $m';
}

/// Whether two brand and model pairs name the same device, however each
/// source split the name between the two fields.
///
/// The full names must agree, except that a side naming no brand may match
/// on model alone: a file that says only "Teric" did not name a different
/// brand, it named none. The same allowance `matchImportedComputer` makes.
/// A side with no model never matches, since a brand alone names no device.
bool computerNamesAgree({
  required String? brandA,
  required String? modelA,
  required String? brandB,
  required String? modelB,
}) {
  final mA = normalizeComputerIdentityPart(modelA);
  final mB = normalizeComputerIdentityPart(modelB);
  if (mA.isEmpty || mB.isEmpty) return false;
  if (computerFullName(brandA, modelA) == computerFullName(brandB, modelB)) {
    return true;
  }
  final noBrand =
      normalizeComputerIdentityPart(brandA).isEmpty ||
      normalizeComputerIdentityPart(brandB).isEmpty;
  return noBrand && mA == mB;
}
