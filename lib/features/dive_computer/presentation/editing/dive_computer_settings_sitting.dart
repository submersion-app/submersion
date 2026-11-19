import 'dart:async';

import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';

/// A dive computer's own settings shown on its gear item's page: whether it
/// is the favourite, whether the passive scan skips it, and its clock sync
/// choice.
typedef DiveComputerSettings = ({
  bool favourite,
  bool autoDownloadDisabled,
  ClockSyncOverride clockSync,
});

/// The settings [computer] has as stored, with [clockSync], its choice on
/// this installation.
DiveComputerSettings storedDiveComputerSettings(
  DiveComputer computer,
  ClockSyncOverride clockSync,
) => (
  favourite: computer.isFavorite,
  autoDownloadDisabled: computer.autoDownloadDisabled,
  clockSync: clockSync,
);

/// A clock sync choice the sitting holds for computer [computerId].
typedef HeldClockSync = ({String computerId, ClockSyncOverride value});

const String _key = 'equipment.diveComputer';
const String _settingsNote = 'equipment.diveComputer.settings';
const String _clockSyncNote = 'equipment.diveComputer.clockSync';

/// The computer's settings the gear item's sitting holds (issue #4527,
/// phase 3, plan 6), or null while it holds none.
DiveComputerSettings? heldDiveComputerSettings(
  EditSession<EquipmentItem> session,
) => session.isDisposed
    ? null
    : session.recall<DiveComputerSettings>(_settingsNote);

/// The clock sync choice the sitting holds, to be written once its Save has
/// committed: it lives in this installation's preferences, not in the
/// database, so it cannot be in the sitting's transaction or its History
/// entry.
HeldClockSync? heldClockSync(EditSession<EquipmentItem> session) =>
    session.isDisposed ? null : session.recall<HeldClockSync>(_clockSyncNote);

/// Holds [next] as [computer]'s settings in the gear item's sitting: they
/// are the computer record's own values, behind the item's lock and written
/// with its Save (decided 2026-11-19). The favourite and the auto-download
/// opt-out are written inside the sitting's transaction; the clock sync
/// choice after the commit ([heldClockSync]). Back to [stored] releases
/// the change. Making [diverId]'s favourite clears their others, as the
/// star does today.
void holdDiveComputerSettings(
  EditSession<EquipmentItem> session, {
  required DiveComputer computer,
  required DiveComputerSettings stored,
  required DiveComputerSettings next,
  String? diverId,
}) {
  if (session.isDisposed || session.isFrozen) return;
  if (next == stored) {
    session
      ..remember(_settingsNote, null)
      ..remember(_clockSyncNote, null)
      ..releaseWrite(_key);
    return;
  }
  session
    ..remember(_settingsNote, next)
    ..remember(
      _clockSyncNote,
      next.clockSync == stored.clockSync
          ? null
          : (computerId: computer.id, value: next.clockSync),
    )
    ..holdChange(
      _key,
      cardId: 'diveComputer',
      write: () async {
        final repository = DiveComputerRepository();
        if (next.favourite && !stored.favourite) {
          await repository.setFavoriteComputer(computer.id, diverId: diverId);
        }
        if (next.autoDownloadDisabled != stored.autoDownloadDisabled) {
          await repository.setAutoDownloadDisabled(
            computer.id,
            next.autoDownloadDisabled,
          );
        }
      },
    );
}

/// What a page that edits its gear item in place hands the computer's
/// setting controls: the settings to show, and how to hold a change, null
/// while they cannot change (the page is locked, or the card is closed).
class DiveComputerSettingsControl {
  const DiveComputerSettingsControl({required this.shown, this.hold});

  final DiveComputerSettings shown;
  final void Function(DiveComputerSettings next)? hold;
}

/// What a page that edits its gear item in place hands the computer's
/// whole-record operations (merge, re-parse all): why they are unavailable
/// now, or null, and the runner that takes them through its sitting.
typedef DiveComputerOperations = ({String? reason, RecordOperationRunner run});

/// Runs [operation], named [task] in the log: through [operations] where
/// the page edits in place, as a whole-record operation; else at once, as
/// today. [operation] answers whether it wrote anything: one the diver gave
/// up on leaves the sitting as it was.
void runDiveComputerOperation(
  DiveComputerOperations? operations,
  Future<bool> Function() operation,
  String task,
) {
  if (operations == null) {
    logFailure(operation(), DiveComputerSettingsControl, task);
    return;
  }
  unawaited(operations.run(operation));
}
