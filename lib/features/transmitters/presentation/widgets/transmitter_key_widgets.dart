import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
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
/// transmitter, after one confirmation that counts every tank they match.
Future<void> applyTransmitterSetupToExistingDives(
  BuildContext context,
  WidgetRef ref,
  List<Transmitter> keys,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(transmitterRepositoryProvider);
  // Preview the counts with a dry run: the repository's matcher is the same
  // one the write uses, so the numbers cannot disagree.
  var tanks = 0;
  var dives = 0;
  for (final key in keys) {
    final preview = await repo.previewApplyToExistingDives(key);
    tanks += preview.tanksUpdated;
    dives += preview.divesUpdated;
  }
  if (!context.mounted) return;
  if (tanks == 0) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.transmitters_apply_nothing)),
    );
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.transmitters_apply_title),
      content: Text(
        dialogContext.l10n.transmitters_apply_content(tanks, dives),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(dialogContext.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(dialogContext.l10n.common_action_apply),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    var tanksDone = 0;
    var divesDone = 0;
    for (final key in keys) {
      final result = await repo.applyToExistingDives(key);
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
