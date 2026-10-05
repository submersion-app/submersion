import 'package:flutter/material.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_comparison.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_device_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/widgets/conflict_difference_list.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The body of one conflict: who changed it when, what differs, what is the
/// same, or the banner for a deletion or a content-identical pair.
class ConflictComparisonView extends StatelessWidget {
  const ConflictComparisonView({
    super.key,
    required this.comparison,
    required this.devices,
    required this.localModified,
    required this.remoteModified,
  });

  final ConflictComparison comparison;
  final ConflictDeviceLabels devices;
  final String localModified;
  final String remoteModified;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final c = comparison;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _modified(context, Icons.phone_android, devices.local, localModified),
        _modified(context, Icons.cloud, devices.remote, remoteModified),
        const SizedBox(height: 12),
        switch (c.state) {
          ConflictComparisonState.differing => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settings_conflict_whatDiffers(c.differences.length),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ConflictDifferenceList(
                differences: c.differences,
                devices: devices,
              ),
            ],
          ),
          ConflictComparisonState.sameContent => _banner(
            context,
            Icons.check_circle_outline,
            l10n.settings_conflict_sameContent,
          ),
          ConflictComparisonState.remoteDeleted => _deleted(
            context,
            l10n.settings_conflict_remoteDeleted(devices.remote),
            devices.local,
          ),
          ConflictComparisonState.localDeleted => _deleted(
            context,
            l10n.settings_conflict_localDeleted(devices.local),
            devices.remote,
          ),
        },
        if (c.unchanged.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text(
              l10n.settings_conflict_sameFields(c.unchanged.length),
              style: theme.textTheme.bodyMedium,
            ),
            children: [for (final f in c.unchanged) _fieldRow(context, f)],
          ),
      ],
    );
  }

  Widget _modified(
    BuildContext context,
    IconData icon,
    String device,
    String time,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.settings_conflict_modifiedBy(device, time),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(BuildContext context, IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(icon, color: scheme.onSecondaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deleted(BuildContext context, String message, String survivor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _banner(context, Icons.delete_outline, message),
        if (comparison.survivingValues.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            context.l10n.settings_conflict_deletedValues(survivor),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          for (final f in comparison.survivingValues) _fieldRow(context, f),
        ],
      ],
    );
  }

  Widget _fieldRow(BuildContext context, ShownField f) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              f.label,
              style: style?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(f.display, style: style)),
        ],
      ),
    );
  }
}
