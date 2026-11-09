import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter_slot_preview.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Confirms "Apply to existing dives": what the transmitter's keys match by
/// serial, and the file-imported tanks it matches by computer slot (issue
/// #4347), with a switch for the slot matches older than the first download
/// that showed the pairing. Pops the slot tank ids to write, or null when
/// cancelled.
class TransmitterApplyDialog extends ConsumerStatefulWidget {
  const TransmitterApplyDialog({
    super.key,
    required this.serialTanks,
    required this.serialDives,
    required this.slots,
  });

  final int serialTanks;
  final int serialDives;
  final TransmitterSlotPreview slots;

  @override
  ConsumerState<TransmitterApplyDialog> createState() =>
      _TransmitterApplyDialogState();
}

class _TransmitterApplyDialogState
    extends ConsumerState<TransmitterApplyDialog> {
  var _includeOlder = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final slots = widget.slots;
    final hasSlots = slots.candidates.isNotEmpty;
    final slotTanks = slots.tankIds(includeOlder: _includeOlder);
    final slotDives = slots.diveIds(includeOlder: _includeOlder);
    final hasOlder = slots.candidates.any((c) => c.olderThanFirstDownload);
    final secondary = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return AlertDialog(
      title: Text(l10n.transmitters_apply_title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.transmitters_apply_content(
                widget.serialTanks + slotTanks.length,
                widget.serialDives + slotDives.length,
              ),
            ),
            if (hasSlots) ...[
              const SizedBox(height: 16),
              if (widget.serialDives > 0)
                Text(l10n.transmitters_apply_bySerial(widget.serialDives)),
              for (final group in _byComputer(slots)) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.transmitters_apply_bySlot(
                    group.dives,
                    slots.computerNames[group.computerId] ?? group.computerId,
                  ),
                ),
                if (group.olderDives > 0)
                  Text(
                    l10n.transmitters_apply_olderNote(
                      group.olderDives,
                      units.formatDate(group.firstDownload),
                    ),
                    style: secondary,
                  ),
              ],
              if (hasOlder)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.transmitters_apply_includeOlder),
                  value: _includeOlder,
                  onChanged: (v) => setState(() => _includeOlder = v),
                ),
            ],
            if (slots.changedHandsDiveIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.transmitters_apply_changedHands(
                  slots.changedHandsDiveIds.length,
                ),
                style: secondary,
              ),
            ],
            if (slots.noSlotDiveIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.transmitters_apply_noSlotInfo(slots.noSlotDiveIds.length),
                style: secondary,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(slotTanks),
          child: Text(l10n.common_action_apply),
        ),
      ],
    );
  }

  /// The slot matches per computer, in the order they first appear.
  List<_ComputerGroup> _byComputer(TransmitterSlotPreview slots) {
    final groups = <String, _ComputerGroup>{};
    for (final c in slots.candidates) {
      final g = groups.putIfAbsent(
        c.computerId,
        () => _ComputerGroup(c.computerId),
      );
      g.diveIds.add(c.diveId);
      if (c.olderThanFirstDownload) {
        g.olderDiveIds.add(c.diveId);
        final first = c.firstDownload;
        if (first != null &&
            (g.firstDownload == null || first.isBefore(g.firstDownload!))) {
          g.firstDownload = first;
        }
      }
    }
    return groups.values.toList();
  }
}

class _ComputerGroup {
  _ComputerGroup(this.computerId);

  final String computerId;
  final diveIds = <String>{};
  final olderDiveIds = <String>{};
  DateTime? firstDownload;

  int get dives => diveIds.length;
  int get olderDives => olderDiveIds.length;
}
