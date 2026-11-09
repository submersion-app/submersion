import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_slot_backfill.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter_slot_preview.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/features/transmitters/presentation/widgets/transmitter_apply_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How a registry key reads: "Transmitter 4A21F" for a serial, or
/// "Perdix, channel 2" for a computer that reports channels only. Channels
/// are shown one-based, matching how Shearwater labels T1 to T4.
class TransmitterKeyLabel extends ConsumerWidget {
  const TransmitterKeyLabel({super.key, required this.entry, this.style});

  final Transmitter entry;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (entry.hasSerial) {
      return Text(
        l10n.transmitters_serial(entry.transmitterSerial!),
        style: style,
      );
    }
    final computerId = entry.diveComputerId;
    final channel = entry.channelIndex;
    if (computerId == null || channel == null) return const SizedBox.shrink();
    // `.value` keeps the computer through a reload, so the label never drops
    // to the raw id while a rename syncs.
    final computer = ref.watch(diveComputerByIdProvider(computerId)).value;
    return Text(
      l10n.transmitters_channel(computer?.name ?? computerId, channel + 1),
      style: style,
    );
  }
}

/// Role, size, working pressure and material, in the diver's units.
String transmitterSpecLine(
  AppLocalizations l10n,
  UnitFormatter units,
  Transmitter entry,
) => [
  entry.role.localizedName(l10n),
  if (entry.volumeL != null)
    units.formatTankVolume(
      entry.volumeL,
      entry.workingPressureBar,
      cuftDecimals: 1,
    ),
  if (entry.workingPressureBar != null)
    units.formatPressure(entry.workingPressureBar),
  if (entry.material != null) entry.material!.localizedName(l10n),
].join(' • ');

/// Fills the dives already logged with the setup of [keys], the keys of one
/// transmitter, after one confirmation that counts every tank they match:
/// by serial, and file-imported tanks with no serial by computer slot (issue
/// #4347), once the transmitter's computers have learned the slots of dives
/// stored before slots were kept.
Future<void> applyTransmitterSetupToExistingDives(
  BuildContext context,
  WidgetRef ref,
  List<Transmitter> keys,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(transmitterRepositoryProvider);
  final computers = <String>{
    for (final key in keys)
      if (normalizeTransmitterSerial(key.transmitterSerial) case final serial?)
        ...await repo.computersForSerial(serial),
  };
  final backfill = ref.read(transmitterSlotBackfillProvider);
  // A Cloud database's dives gain serials from their file, so its computers
  // join the scope even before any of their tanks carries this serial.
  computers.addAll(await backfill.dbImportComputers());
  if (await backfill.pendingCount(computers) > 0 && context.mounted) {
    await _learnSlots(context, backfill, computers);
  }
  // Preview the counts with a dry run: the repository's matchers are the
  // same ones the write uses, so the numbers cannot disagree.
  var tanks = 0;
  var dives = 0;
  final slotsByKey = <String, TransmitterSlotPreview>{};
  for (final key in keys) {
    final preview = await repo.previewApplyToExistingDives(key);
    tanks += preview.tanksUpdated;
    dives += preview.divesUpdated;
    slotsByKey[key.id] = await repo.previewSlotMatches(key);
  }
  final slots = TransmitterSlotPreview.merge(slotsByKey.values);
  if (!context.mounted) return;
  if (tanks == 0 && slots.candidates.isEmpty) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.transmitters_apply_nothing)),
    );
    return;
  }
  final chosen = await showDialog<Set<String>>(
    context: context,
    builder: (_) => TransmitterApplyDialog(
      serialTanks: tanks,
      serialDives: dives,
      slots: slots,
    ),
  );
  if (chosen == null) return;
  try {
    var tanksDone = 0;
    var divesDone = 0;
    for (final key in keys) {
      final result = await repo.applyToExistingDives(
        key,
        slotTankIds: {
          for (final c in slotsByKey[key.id]!.candidates)
            if (chosen.contains(c.tankId)) c.tankId,
        },
      );
      tanksDone += result.tanksUpdated;
      divesDone += result.divesUpdated;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.transmitters_apply_done(tanksDone, divesDone)),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('${l10n.common_label_error}: $e')),
    );
  }
}

/// Runs the slot backfill for [computers] behind a progress dialog. Best
/// effort: a failure leaves the slots it could not learn unmatched.
Future<void> _learnSlots(
  BuildContext context,
  TransmitterSlotBackfill backfill,
  Set<String> computers,
) async {
  // showDialog pushes onto the root navigator, above the app's ShellRoute,
  // so the pop must go there too, not to the page's own navigator.
  final navigator = Navigator.of(context, rootNavigator: true);
  final progress = ValueNotifier<double?>(null);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<double?>(
                valueListenable: progress,
                builder: (_, value, _) => LinearProgressIndicator(value: value),
              ),
              const SizedBox(height: 16),
              Text(dialogContext.l10n.transmitters_apply_reading),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    await backfill.run(
      computers,
      onProgress: (done, total) => progress.value = done / total,
    );
  } catch (e, stackTrace) {
    _log.warning(
      'Transmitter slot backfill failed',
      error: e,
      stackTrace: stackTrace,
    );
  } finally {
    navigator.pop();
    progress.dispose();
  }
}

final _log = LoggerService.forClass(TransmitterApplyDialog);
