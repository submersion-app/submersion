import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_pairing_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_pairing.dart';
import 'package:submersion/features/cylinder_passports/domain/services/pairing_rules.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

/// The held change of the Twin set card (issue #4527, phase 3): the
/// pairings made, ended and deleted in the sitting, in order. A pairing can
/// end or delete pairings of other cylinders (a replace), and whether it
/// may be made depends on every pairing, so the steps are run again through
/// the repository at Save, which checks them against the pairings stored
/// by then.
const String gearPairingsKey = 'equipment.pairings';

const String _stepsKey = 'equipment.pairings.steps';

const _uuid = Uuid();

/// One change to the twin set pairings, held until Save.
sealed class HeldPairingStep extends Equatable {
  const HeldPairingStep();
}

/// A pairing made in the sitting. [id] names it in the sitting only: the
/// repository gives the stored row its own.
final class HeldPairingCreate extends HeldPairingStep {
  const HeldPairingCreate({
    required this.id,
    required this.cylinderAId,
    required this.cylinderBId,
    required this.pairedOn,
    this.unpairedOn,
    this.replace = false,
  });

  final String id;
  final String cylinderAId;
  final String cylinderBId;

  /// Calendar days, as the repository stores them.
  final DateTime pairedOn;
  final DateTime? unpairedOn;

  /// Whether it ends or deletes the open pairings it overlaps.
  final bool replace;

  @override
  List<Object?> get props => [
    id,
    cylinderAId,
    cylinderBId,
    pairedOn,
    unpairedOn,
    replace,
  ];
}

/// A pairing ended in the sitting, on the calendar day [unpairedOn].
final class HeldPairingEnd extends HeldPairingStep {
  const HeldPairingEnd({required this.pairingId, required this.unpairedOn});

  final String pairingId;
  final DateTime unpairedOn;

  @override
  List<Object?> get props => [pairingId, unpairedOn];
}

/// A pairing deleted in the sitting.
final class HeldPairingDelete extends HeldPairingStep {
  const HeldPairingDelete({required this.pairingId});

  final String pairingId;

  @override
  List<Object?> get props => [pairingId];
}

/// [current] (resolved pairings) once [step] is applied, as the repository
/// would apply it: a clash throws [PairingClash], an end on or before its
/// start throws [ArgumentError], and a replace ends the open pairings it
/// overlaps (or deletes one that started the same day).
List<CylinderPairing> applyPairingStep(
  List<CylinderPairing> current,
  HeldPairingStep step,
) {
  switch (step) {
    case HeldPairingCreate():
      if (step.cylinderAId == step.cylinderBId) {
        throw ArgumentError.value(step.cylinderBId, 'cylinderBId');
      }
      final start = step.pairedOn;
      final end = step.unpairedOn;
      if (end != null && !end.isAfter(start)) {
        throw ArgumentError.value(end, 'unpairedOn', 'not after start');
      }
      final clashes = clashesWith(
        current,
        cylinderAId: step.cylinderAId,
        cylinderBId: step.cylinderBId,
        pairedOn: start,
        unpairedOn: end,
      );
      final replaceable = {
        for (final c in clashes)
          if (isReplaceable(c, start)) c.id,
      };
      if (clashes.isNotEmpty &&
          (!step.replace || replaceable.length != clashes.length)) {
        throw PairingClash(clashes);
      }
      final made = DateTime.now();
      return resolvePairings([
        for (final p in current)
          if (!replaceable.contains(p.id))
            p
          else if (p.pairedOn != start)
            p.copyWith(unpairedOn: start),
        CylinderPairing(
          id: step.id,
          cylinderAId: step.cylinderAId,
          cylinderBId: step.cylinderBId,
          pairedOn: start,
          unpairedOn: end,
          createdAt: made,
          updatedAt: made,
        ),
      ]);
    case HeldPairingEnd():
      final pairing = current.firstWhere((p) => p.id == step.pairingId);
      if (!step.unpairedOn.isAfter(pairing.pairedOn)) {
        throw ArgumentError.value(step.unpairedOn, 'unpairedOn');
      }
      final clashes = clashesWith(
        current,
        cylinderAId: pairing.cylinderAId,
        cylinderBId: pairing.cylinderBId,
        pairedOn: pairing.pairedOn,
        unpairedOn: step.unpairedOn,
        ignoreId: pairing.id,
      );
      if (clashes.isNotEmpty) throw PairingClash(clashes);
      return [
        for (final p in current)
          p.id == pairing.id ? p.copyWith(unpairedOn: step.unpairedOn) : p,
      ];
    case HeldPairingDelete():
      return [
        for (final p in current)
          if (p.id != step.pairingId) p,
      ];
  }
}

/// Every pairing as the sitting has them: [stored] (every pairing, resolved)
/// with [steps] applied in order. A step the stored pairings no longer
/// allow (another device paired a cylinder meanwhile) is left out of the
/// view; Save refuses it.
List<CylinderPairing> pairingsInSitting(
  List<CylinderPairing> stored,
  List<HeldPairingStep> steps,
) {
  var current = stored;
  for (final step in steps) {
    try {
      current = applyPairingStep(current, step);
    } on Object {
      continue;
    }
  }
  return current;
}

/// The steps the sitting holds, in order.
List<HeldPairingStep> heldPairingSteps(EditSession<EquipmentItem> session) =>
    session.recall<List<HeldPairingStep>>(_stepsKey) ?? const [];

/// Adds [step] to the sitting's pairing steps. Deleting a pairing the
/// sitting made, which ended or deleted no other, takes back the making and
/// its ends; with no step left, the held change is released.
void holdPairingStep(
  EditSession<EquipmentItem> session,
  HeldPairingStep step, {
  required CylinderPairingRepository repository,
}) {
  if (session.isDisposed || session.isFrozen) return;
  var steps = [...heldPairingSteps(session)];
  final deleted = step is HeldPairingDelete ? step.pairingId : null;
  final made = steps.whereType<HeldPairingCreate>().where(
    (c) => c.id == deleted && !c.replace,
  );
  if (made.isNotEmpty) {
    steps = [
      for (final s in steps)
        if (s != made.first && !(s is HeldPairingEnd && s.pairingId == deleted))
          s,
    ];
  } else {
    steps.add(step);
  }
  session.remember(_stepsKey, steps);
  if (steps.isEmpty) {
    session.releaseWrite(gearPairingsKey);
    return;
  }
  session.holdChange(
    gearPairingsKey,
    cardId: GearItemCardId.twinSet.name,
    write: () => _write(heldPairingSteps(session), repository),
  );
}

/// Runs [steps] through the repository, in order, inside the sitting's
/// transaction. A step the pairings stored by now refuse fails the whole
/// Save with today's message.
Future<void> _write(
  List<HeldPairingStep> steps,
  CylinderPairingRepository repository,
) async {
  // The sitting's names for the pairings it made, to the stored ones.
  final ids = <String, String>{};
  try {
    for (final step in steps) {
      switch (step) {
        case HeldPairingCreate():
          final made = await repository.createPairing(
            cylinderAId: step.cylinderAId,
            cylinderBId: step.cylinderBId,
            pairedOn: step.pairedOn,
            unpairedOn: step.unpairedOn,
            replace: step.replace,
          );
          ids[step.id] = made.id;
        case HeldPairingEnd():
          await repository.endPairing(
            ids[step.pairingId] ?? step.pairingId,
            step.unpairedOn,
          );
        case HeldPairingDelete():
          await repository.deletePairing(ids[step.pairingId] ?? step.pairingId);
      }
    }
  } on PairingClash catch (clash) {
    final items = EquipmentRepository();
    Future<String> name(String id) async =>
        (await items.getEquipmentById(id))?.name ?? id;
    final pairs = [
      for (final c in clash.clashes)
        (await name(c.cylinderAId), await name(c.cylinderBId)),
    ];
    throw RecordSittingRefusal(
      (l) => l.twinSet_clashBody(
        pairs.map((p) => l.twinSet_pairNames(p.$1, p.$2)).join('; '),
      ),
    );
  } on ArgumentError {
    throw RecordSittingRefusal((l) => l.twinSet_saveFailed);
  }
}

/// The pairing writes of the Twin set card's flows, held in [session]: each
/// is checked against the sitting's pairings as the repository would check
/// it, so the questions are asked now, and written at Save.
class SittingPairingWrites implements PairingWrites {
  SittingPairingWrites(this.session, this.stored, this.repository);

  final EditSession<EquipmentItem> session;

  /// Every pairing as stored now, resolved: awaited, so a step taken
  /// before they load is still checked against them.
  final Future<List<CylinderPairing>> Function() stored;

  final CylinderPairingRepository repository;

  Future<List<CylinderPairing>> _current() async =>
      pairingsInSitting(await stored(), heldPairingSteps(session));

  Future<void> _hold(HeldPairingStep step) async {
    applyPairingStep(await _current(), step);
    holdPairingStep(session, step, repository: repository);
  }

  @override
  Future<CylinderPairing> createPairing({
    required String cylinderAId,
    required String cylinderBId,
    required DateTime pairedOn,
    DateTime? unpairedOn,
    bool replace = false,
  }) async {
    final step = HeldPairingCreate(
      id: _uuid.v4(),
      cylinderAId: cylinderAId,
      cylinderBId: cylinderBId,
      pairedOn: calendarDay(pairedOn),
      unpairedOn: unpairedOn == null ? null : calendarDay(unpairedOn),
      replace: replace,
    );
    await _hold(step);
    return (await _current()).firstWhere((p) => p.id == step.id);
  }

  @override
  Future<void> endPairing(String id, DateTime unpairedOn) async =>
      _hold(HeldPairingEnd(pairingId: id, unpairedOn: calendarDay(unpairedOn)));

  @override
  Future<void> deletePairing(String id) async =>
      _hold(HeldPairingDelete(pairingId: id));
}
