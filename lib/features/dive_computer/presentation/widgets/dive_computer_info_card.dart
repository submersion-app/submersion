import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';

/// What the device reports about itself: maker, model, serial and firmware,
/// plus the transmitters seen on its dives. Its name and notes are the
/// Equipment item's (issue #3676), so they are not repeated here.
class DiveComputerInfoCard extends StatelessWidget {
  const DiveComputerInfoCard({
    super.key,
    required this.computer,
    required this.icon,
  });

  final DiveComputer computer;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        // Values sit beside their labels in one shared column (#3682).
        child: DetailRowGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      computer.fullName,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _InfoRow(
                label: l10n.diveComputer_detail_labelManufacturer,
                value:
                    computer.manufacturer ?? l10n.diveComputer_detail_unknown,
              ),
              _InfoRow(
                label: l10n.diveComputer_detail_labelModel,
                value: computer.model ?? l10n.diveComputer_detail_unknown,
              ),
              if (computer.serialNumber != null)
                _InfoRow(
                  label: l10n.diveLog_detail_label_serialNumber,
                  value: computer.serialNumber!,
                ),
              if (computer.firmwareVersion != null)
                _InfoRow(
                  label: l10n.diveLog_detail_label_firmwareVersion,
                  value: computer.firmwareVersion!,
                ),
              _TransmittersRow(computerId: computer.id),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DetailRow.text(
      label: label,
      value: value,
      valueStyle: Theme.of(context).textTheme.bodyMedium,
      padding: const EdgeInsets.symmetric(vertical: 4),
    );
  }
}

/// Known versus unassigned transmitter serials seen on this computer's dives,
/// linking to the transmitters list (issue #1365). Absent until the computer
/// has reported a serial.
class _TransmittersRow extends ConsumerWidget {
  const _TransmittersRow({required this.computerId});

  final String computerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // `.value` keeps the last counts through a dependency reload instead of
    // collapsing the row for a frame.
    final summary = ref
        .watch(transmitterComputerSummaryProvider(computerId))
        .value;
    if (summary == null || summary.known + summary.unassigned == 0) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () => context.push('/transmitters'),
      child: DetailRow(
        label: context.l10n.diveComputer_detail_transmitters,
        padding: const EdgeInsets.symmetric(vertical: 4),
        value: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                context.l10n.diveComputer_detail_transmittersSummary(
                  summary.known,
                  summary.unassigned,
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
