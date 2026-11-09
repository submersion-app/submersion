import 'dart:math';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_slot_matcher.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A computer the apply dialog can match by slot, with the transmitter key
/// whose serial was downloaded on it.
typedef SlotOffer = ({Transmitter key, SlotComputer computer});

/// The slots a Shearwater offers (T1 to T4); more appear if a file names one.
const _shearwaterSlots = 4;

/// Confirms a retroactive apply, and offers to fill the serial-less cylinders
/// a file brought in by the slot the transmitter sat in (issue #4347).
///
/// Pops the chosen slot's cylinder ids by transmitter key id (empty when no
/// slot is chosen), or null on cancel.
class TransmitterApplyDialog extends ConsumerStatefulWidget {
  const TransmitterApplyDialog({
    super.key,
    required this.serialPreview,
    required this.slotOffers,
  });

  final ApplyToExistingResult serialPreview;
  final List<SlotOffer> slotOffers;

  @override
  ConsumerState<TransmitterApplyDialog> createState() =>
      _TransmitterApplyDialogState();
}

class _TransmitterApplyDialogState
    extends ConsumerState<TransmitterApplyDialog> {
  static final _log = LoggerService.forClass(TransmitterApplyDialog);

  /// Resolved candidates by computer id; null until the files are read.
  Map<String, SlotCandidates>? _resolved;
  final _picked = <String, int?>{};

  @override
  void initState() {
    super.initState();
    if (widget.slotOffers.isNotEmpty) _resolve();
  }

  Future<void> _resolve() async {
    final matcher = ref.read(transmitterSlotMatcherProvider);
    final resolved = <String, SlotCandidates>{};
    try {
      final byKey = <String, ({Transmitter key, Set<String> computers})>{};
      for (final offer in widget.slotOffers) {
        byKey
            .putIfAbsent(
              offer.key.id,
              () => (key: offer.key, computers: <String>{}),
            )
            .computers
            .add(offer.computer.computerId);
      }
      for (final entry in byKey.values) {
        for (final candidates in await matcher.resolve(entry.key)) {
          final id = candidates.computer.computerId;
          if (entry.computers.contains(id)) resolved[id] = candidates;
        }
      }
    } catch (e, st) {
      _log.warning(
        'Could not read the imported files for slot matching',
        error: e,
        stackTrace: st,
      );
    }
    if (mounted) setState(() => _resolved = resolved);
  }

  int get _slotDives => widget.slotOffers.fold(0, (sum, offer) {
    final id = offer.computer.computerId;
    final slot = _picked[id];
    final candidates = _resolved?[id];
    return slot == null || candidates == null
        ? sum
        : sum + candidates.divesFor(slot);
  });

  /// The chosen slot's cylinder ids, by the key that offered each computer.
  Map<String, List<String>> _selection() {
    final byKey = <String, List<String>>{};
    for (final offer in widget.slotOffers) {
      final id = offer.computer.computerId;
      final slot = _picked[id];
      final ids = slot == null ? null : _resolved?[id]?.tankIdsBySlot[slot];
      if (ids == null || ids.isEmpty) continue;
      byKey.putIfAbsent(offer.key.id, () => []).addAll(ids);
    }
    return byKey;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final serial = widget.serialPreview;
    final slotDives = _slotDives;
    final canApply = serial.tanksUpdated > 0 || slotDives > 0;
    return AlertDialog(
      title: Text(l10n.transmitters_apply_title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (serial.tanksUpdated > 0)
              Text(
                l10n.transmitters_apply_content(
                  serial.tanksUpdated,
                  serial.divesUpdated,
                ),
              ),
            if (widget.slotOffers.isNotEmpty) ...[
              if (serial.tanksUpdated > 0) const SizedBox(height: 16),
              Text(l10n.transmitters_apply_slot_intro),
              for (final offer in widget.slotOffers) ...[
                const SizedBox(height: 16),
                _slotRow(context, offer),
              ],
            ],
            if (slotDives > 0) ...[
              const SizedBox(height: 16),
              Text(
                l10n.transmitters_apply_summary(serial.divesUpdated, slotDives),
                style: Theme.of(context).textTheme.titleSmall,
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
          onPressed: canApply
              ? () => Navigator.of(context).pop(_selection())
              : null,
          child: Text(l10n.common_action_apply),
        ),
      ],
    );
  }

  Widget _slotRow(BuildContext context, SlotOffer offer) {
    final l10n = context.l10n;
    final label = l10n.transmitters_apply_slot_label(
      offer.computer.computerName,
    );
    final resolved = _resolved;
    if (resolved == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
          const SizedBox(height: 4),
          Text(
            l10n.transmitters_apply_slot_reading,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }
    final id = offer.computer.computerId;
    final candidates = resolved[id];
    final named = candidates?.tankIdsBySlot.keys ?? const <int>[];
    final lastSlot = named.fold(_shearwaterSlots, max);
    return DropdownButtonFormField<int?>(
      initialValue: _picked[id],
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<int?>(child: Text(l10n.transmitters_apply_slot_none)),
        for (var slot = 1; slot <= lastSlot; slot++)
          _slotItem(context, slot, candidates?.divesFor(slot) ?? 0),
      ],
      onChanged: (slot) => setState(() => _picked[id] = slot),
    );
  }

  /// A slot with nothing to fill cannot be picked, and is drawn muted so it
  /// does not read as a choice.
  DropdownMenuItem<int?> _slotItem(BuildContext context, int slot, int dives) {
    final enabled = dives > 0;
    return DropdownMenuItem<int?>(
      value: slot,
      enabled: enabled,
      child: Text(
        context.l10n.transmitters_apply_slot_option(slot, dives),
        style: enabled
            ? null
            : TextStyle(color: Theme.of(context).disabledColor),
      ),
    );
  }
}
