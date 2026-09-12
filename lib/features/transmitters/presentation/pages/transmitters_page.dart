import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Manage > Transmitters. Follows the dive roles page: extended
/// FAB to add, inline edit and delete icons, no app-bar plus.
class TransmittersPage extends ConsumerWidget {
  const TransmittersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(transmittersProvider);
    final unassigned = ref.watch(unassignedTransmitterSerialsProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.transmitters_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: l10n.common_action_back,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/transmitters/new'),
        tooltip: l10n.transmitters_add,
        icon: const Icon(Icons.add),
        label: Text(l10n.transmitters_add),
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('${l10n.common_label_error}: $e')),
        data: (list) {
          final pending = unassigned.valueOrNull ?? const [];
          if (list.isEmpty && pending.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.transmitters_empty,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            children: [
              if (list.isNotEmpty) ...[
                _header(context, l10n.transmitters_header_assigned),
                ...list.map((t) => _EntryTile(entry: t, units: units)),
              ],
              if (pending.isNotEmpty) ...[
                if (list.isNotEmpty) const Divider(),
                _header(context, l10n.transmitters_header_unassigned),
                ...pending.map((u) => _UnassignedTile(item: u)),
              ],
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry, required this.units});

  final Transmitter entry;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final specs = <String>[
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
    ];
    return ListTile(
      leading: Icon(
        MdiIcons.divingScubaTank,
        color: Theme.of(context).colorScheme.secondary,
      ),
      title: Text(entry.label),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.hasSerial)
            Text(l10n.transmitters_serial(entry.transmitterSerial!))
          else
            _ChannelLabel(entry: entry),
          Text(specs.join(' • ')),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check),
            tooltip: l10n.transmitters_action_apply,
            onPressed: () => _applyToExisting(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.transmitters_action_edit,
            onPressed: () => context.push('/transmitters/${entry.id}/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.transmitters_action_delete,
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _applyToExisting(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(transmitterRepositoryProvider);
    // Preview the counts with a dry run: the repository's matcher is the
    // same one the write uses, so the numbers cannot disagree.
    final preview = await repo.previewApplyToExistingDives(entry);
    if (!context.mounted) return;
    if (preview.tanksUpdated == 0) {
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
          dialogContext.l10n.transmitters_apply_content(
            preview.tanksUpdated,
            preview.divesUpdated,
          ),
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
      final result = await repo.applyToExistingDives(entry);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.transmitters_apply_done(
              result.tanksUpdated,
              result.divesUpdated,
            ),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${l10n.common_label_error}: $e')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.transmitters_delete_title),
        content: Text(
          dialogContext.l10n.transmitters_delete_content(entry.label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(dialogContext.l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(transmitterRepositoryProvider).delete(entry.id);
      // Its transmitter item loses these serials, and with them any stored
      // dropout finding they raised.
      if (entry.transmitterEquipmentId case final item?) {
        scheduleConditionFindingsRefresh([item]);
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${l10n.common_label_error}: $e')),
      );
    }
  }
}

/// "Perdix, channel 2" for a fallback-keyed entry. Channels are shown
/// one-based, matching how Shearwater labels T1 to T4.
class _ChannelLabel extends ConsumerWidget {
  const _ChannelLabel({required this.entry});
  final Transmitter entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final computer = ref
        .watch(diveComputerByIdProvider(entry.diveComputerId!))
        .valueOrNull;
    return Text(
      context.l10n.transmitters_channel(
        computer?.name ?? entry.diveComputerId!,
        entry.channelIndex! + 1,
      ),
    );
  }
}

class _UnassignedTile extends StatelessWidget {
  const _UnassignedTile({required this.item});
  final UnassignedTransmitterSerial item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      leading: const Icon(Icons.sensors),
      title: Text(l10n.transmitters_serial(item.serial)),
      subtitle: Text(l10n.transmitters_dives(item.diveCount)),
      trailing: FilledButton.tonal(
        onPressed: () => context.push(
          Uri(
            path: '/transmitters/new',
            queryParameters: {'serial': item.serial},
          ).toString(),
        ),
        child: Text(l10n.transmitters_action_assign),
      ),
    );
  }
}
