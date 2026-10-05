import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_comparison.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_device_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/widgets/conflict_choice_consequence.dart';
import 'package:submersion/features/settings/presentation/conflicts/widgets/conflict_comparison_view.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_reference_labels.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dialog for resolving sync conflicts between local and remote data
class ConflictResolutionDialog extends ConsumerStatefulWidget {
  const ConflictResolutionDialog({super.key});

  @override
  ConsumerState<ConflictResolutionDialog> createState() =>
      _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState
    extends ConsumerState<ConflictResolutionDialog> {
  int _currentIndex = 0;
  final Map<String, ConflictResolution> _resolutions = {};

  /// Below this window width the comparison needs the whole screen.
  static const _fullScreenBelow = 600.0;

  @override
  Widget build(BuildContext context) {
    final conflictsAsync = ref.watch(conflictsProvider);
    final narrow = MediaQuery.sizeOf(context).width < _fullScreenBelow;
    final body = conflictsAsync.when(
      data: (conflicts) => _buildContent(context, conflicts, narrow: narrow),
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            context.l10n.settings_conflict_errorLoading(error.toString()),
          ),
        ),
      ),
    );

    if (narrow) return Dialog.fullscreen(child: SafeArea(child: body));
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: body,
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<SyncConflict> conflicts, {
    required bool narrow,
  }) {
    if (conflicts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(
              child: Icon(Icons.check_circle, size: 64, color: Colors.green),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.settings_conflict_noConflicts_title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(context.l10n.settings_conflict_noConflicts_message),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.settings_conflict_close),
            ),
          ],
        ),
      );
    }

    // The list reloads under an open dialog when the sync service it reads
    // is rebuilt, and can come back shorter than the card being shown.
    if (_currentIndex >= conflicts.length) _currentIndex = conflicts.length - 1;
    final conflict = conflicts[_currentIndex];
    final comparison = buildConflictComparison(
      l10n: context.l10n,
      units: UnitFormatter(ref.watch(settingsProvider)),
      conflict: conflict,
    );
    final localDevice = ref.watch(conflictLocalDeviceProvider).value;
    final devices = conflictDeviceLabels(
      l10n: context.l10n,
      localName: localDevice?.name,
      localDeviceId: localDevice?.id,
      peerNames: ref.watch(peerDeviceNamesProvider).value ?? const {},
      remoteData: conflict.remoteData,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context, conflicts, narrow: narrow),
        Expanded(
          child: SingleChildScrollView(
            // Keyed by conflict so the next one opens at the top, with its
            // unchanged fields collapsed.
            key: ValueKey(_conflictKey(conflict)),
            padding: const EdgeInsets.all(16),
            child: _buildConflictDetails(
              context,
              conflict,
              comparison,
              devices,
            ),
          ),
        ),
        _buildResolutionOptions(context, conflict, comparison, devices),
        _buildFooter(context, conflicts),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    List<SyncConflict> conflicts, {
    required bool narrow,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: narrow
            ? null
            : const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.settings_conflict_title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  context.l10n.settings_conflict_counterLabel(
                    _currentIndex + 1,
                    conflicts.length,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.l10n.settings_conflict_close_tooltip,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictDetails(
    BuildContext context,
    SyncConflict conflict,
    ConflictComparison comparison,
    ConflictDeviceLabels devices,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Item info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  _getEntityIcon(conflict.entityType),
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _conflictTitle(conflict),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        humanizeEntityType(conflict.entityType),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ConflictComparisonView(
          comparison: comparison,
          devices: devices,
          localModified: _formatDateTime(conflict.localModified),
          remoteModified: _formatDateTime(conflict.remoteModified),
        ),
      ],
    );
  }

  /// Names the record a user is being asked about. Junction and relation
  /// entities have no name of their own, so they are named by the records they
  /// point at; only a record that resolved to nothing falls back to its id.
  ///
  /// Either side can supply the name. When the local row is already gone the
  /// remote one is all there is, and an id-based title would be a worse answer
  /// than the name sitting in the version being offered.
  String _conflictTitle(SyncConflict conflict) {
    final own = _ownName(conflict.localData) ?? _ownName(conflict.remoteData);
    if (own != null) return own;
    return conflictReferenceSummary(conflict.localReferences) ??
        conflictReferenceSummary(conflict.remoteReferences) ??
        conflict.displayName;
  }

  String? _ownName(Map<String, dynamic> data) {
    final name = data['name'] as String? ?? data['title'] as String?;
    return (name != null && name.isNotEmpty) ? name : null;
  }

  Widget _buildResolutionOptions(
    BuildContext context,
    SyncConflict conflict,
    ConflictComparison comparison,
    ConflictDeviceLabels devices,
  ) {
    final key = _conflictKey(conflict);
    final selected = _resolutions[key];

    return Container(
      key: const Key('conflict-resolution-options'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(
                  context.l10n.settings_conflict_keepDevice(devices.local),
                ),
                selected: selected == ConflictResolution.keepLocal,
                onSelected: (_) =>
                    _selectResolution(key, ConflictResolution.keepLocal),
                avatar: const Icon(Icons.phone_android, size: 18),
              ),
              ChoiceChip(
                label: Text(
                  context.l10n.settings_conflict_keepDevice(devices.remote),
                ),
                selected: selected == ConflictResolution.keepRemote,
                onSelected: (_) =>
                    _selectResolution(key, ConflictResolution.keepRemote),
                avatar: const Icon(Icons.cloud, size: 18),
              ),
              if (canKeepBoth(comparison, conflict))
                ChoiceChip(
                  label: Text(context.l10n.settings_conflict_keepBoth),
                  selected: selected == ConflictResolution.keepBoth,
                  onSelected: (_) =>
                      _selectResolution(key, ConflictResolution.keepBoth),
                  avatar: const Icon(Icons.copy_all, size: 18),
                ),
            ],
          ),
          ConflictChoiceConsequence(
            text: conflictConsequence(
              l10n: context.l10n,
              comparison: comparison,
              devices: devices,
              choice: selected,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, List<SyncConflict> conflicts) {
    final allResolved = conflicts.every(
      (c) => _resolutions.containsKey(_conflictKey(c)),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Navigation buttons
          IconButton(
            onPressed: _currentIndex > 0
                ? () => setState(() => _currentIndex--)
                : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: context.l10n.settings_conflict_previous_tooltip,
          ),
          IconButton(
            onPressed: _currentIndex < conflicts.length - 1
                ? () => setState(() => _currentIndex++)
                : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: context.l10n.settings_conflict_next_tooltip,
          ),
          // Action buttons. A phone in a long-worded locale cannot fit both
          // beside the arrows, so they wrap rather than overflow.
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.settings_conflict_cancel),
                ),
                FilledButton(
                  onPressed: allResolved
                      ? () => _applyResolutions(conflicts)
                      : null,
                  child: Text(context.l10n.settings_conflict_applyAll),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _selectResolution(String key, ConflictResolution resolution) {
    setState(() {
      _resolutions[key] = resolution;
    });
  }

  String _conflictKey(SyncConflict conflict) {
    return '${conflict.entityType}:${conflict.recordId}';
  }

  Future<void> _applyResolutions(List<SyncConflict> conflicts) async {
    final syncNotifier = ref.read(syncStateProvider.notifier);

    for (final conflict in conflicts) {
      final key = _conflictKey(conflict);
      final resolution = _resolutions[key];
      if (resolution != null) {
        await syncNotifier.resolveConflict(
          conflict.entityType,
          conflict.recordId,
          resolution,
        );
      }
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.settings_conflict_resolved(conflicts.length),
          ),
        ),
      );
    }
  }

  /// Icon for a sync entity type. Matched on the entity type the sync layer
  /// actually uses (camelCase plurals such as `diveSites`), lowercased so the
  /// legacy snake_case spellings keep working.
  IconData _getEntityIcon(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'dive':
      case 'dives':
        return Icons.scuba_diving;
      case 'divesite':
      case 'divesites':
      case 'dive_sites':
        return Icons.place;
      case 'gear':
      case 'equipment':
      case 'equipmentsets':
        return Icons.backpack;
      case 'diver':
      case 'divers':
        return Icons.person;
      case 'buddies':
        return Icons.people;
      case 'trip':
      case 'trips':
        return Icons.card_travel;
      case 'tags':
      case 'divetags':
        return Icons.label;
      case 'media':
        return Icons.photo_library;
      case 'species':
      case 'sightings':
        return Icons.pets;
      case 'qualityfindings':
        return Icons.rule;
      default:
        return Icons.description;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return context.l10n.settings_data_syncTime_justNow;
    } else if (difference.inHours < 1) {
      return context.l10n.settings_data_syncTime_minutesAgo(
        difference.inMinutes,
      );
    } else if (difference.inDays < 1) {
      return context.l10n.settings_data_syncTime_hoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return context.l10n.settings_data_syncTime_daysAgo(difference.inDays);
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
