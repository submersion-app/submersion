import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_pairing.dart';

/// Rules for twin set pairings (issue #4242). Pure, so the repository, the
/// agent writes and the screens all agree on them.

/// Whether two half-open day ranges share a day. A null end is open.
bool rangesOverlap(
  DateTime aStart,
  DateTime? aEnd,
  DateTime bStart,
  DateTime? bEnd,
) {
  final aStartsBeforeBEnds = bEnd == null || aStart.isBefore(bEnd);
  final bStartsBeforeAEnds = aEnd == null || bStart.isBefore(aEnd);
  return aStartsBeforeBEnds && bStartsBeforeAEnds;
}

bool _overlaps(CylinderPairing a, CylinderPairing b) =>
    rangesOverlap(a.pairedOn, a.unpairedOn, b.pairedOn, b.unpairedOn);

/// The pairings every screen and rule reads, newest first. Writes never let
/// two pairings of one cylinder overlap, but two devices linking offline can
/// each store one; this keeps the newest start (then the smaller id) and
/// drops any row that overlaps a row already kept for either of its
/// cylinders. The order of [all] does not matter, so every device shows the
/// same partner.
List<CylinderPairing> resolvePairings(Iterable<CylinderPairing> all) {
  final sorted = [...all]
    ..sort((a, b) {
      final byStart = b.pairedOn.compareTo(a.pairedOn);
      return byStart != 0 ? byStart : a.id.compareTo(b.id);
    });
  final kept = <CylinderPairing>[];
  for (final candidate in sorted) {
    final clashes = kept.any(
      (k) =>
          (k.involves(candidate.cylinderAId) ||
              k.involves(candidate.cylinderBId)) &&
          _overlaps(k, candidate),
    );
    if (!clashes) kept.add(candidate);
  }
  return kept;
}

/// The pairing [equipmentId] was in on the calendar day of [day], from
/// [resolved] (the output of [resolvePairings]).
CylinderPairing? pairingOn(
  Iterable<CylinderPairing> resolved,
  String equipmentId,
  DateTime day,
) {
  for (final p in resolved) {
    if (p.involves(equipmentId) && p.coversDay(day)) return p;
  }
  return null;
}

/// The open pairing of [equipmentId], if any.
CylinderPairing? currentPairing(
  Iterable<CylinderPairing> resolved,
  String equipmentId,
) {
  for (final p in resolved) {
    if (p.isOpen && p.involves(equipmentId)) return p;
  }
  return null;
}

/// The pairings of either cylinder whose days overlap a candidate pairing of
/// [cylinderAId] and [cylinderBId] from [pairedOn] to [unpairedOn] (open when
/// null). [ignoreId] leaves out the pairing being changed.
List<CylinderPairing> clashesWith(
  Iterable<CylinderPairing> resolved, {
  required String cylinderAId,
  required String cylinderBId,
  required DateTime pairedOn,
  DateTime? unpairedOn,
  String? ignoreId,
}) => [
  for (final p in resolved)
    if (p.id != ignoreId &&
        (p.involves(cylinderAId) || p.involves(cylinderBId)) &&
        rangesOverlap(p.pairedOn, p.unpairedOn, pairedOn, unpairedOn))
      p,
];
