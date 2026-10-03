import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_waypoint.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/editor_context_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/editor_toolbar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_editor_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Page for editing a dive profile's depth data.
///
/// Provides tools for smoothing, outlier removal, range manipulation,
/// and manual drawing via waypoints.
class ProfileEditorPage extends ConsumerStatefulWidget {
  final String diveId;
  final EditorMode? initialMode;

  const ProfileEditorPage({super.key, required this.diveId, this.initialMode});

  @override
  ConsumerState<ProfileEditorPage> createState() => _ProfileEditorPageState();
}

class _ProfileEditorPageState extends ConsumerState<ProfileEditorPage> {
  late StateNotifierProvider<ProfileEditorNotifier, ProfileEditorState>
  _editorProvider;
  List<DiveProfilePoint>? _lastProfile;

  void _initializeProvider(List<DiveProfilePoint> profile) {
    final previous = _lastProfile;
    if (previous != null) {
      // diveProvider re-emits a fresh list on every dive-detail table tick
      // (a sync, a tank edit), so compare contents rather than identity.
      if (listEquals(previous, profile)) return;
      // Never throw away unsaved edits for a profile that changed underneath
      // the editor; the revision selector is disabled while edits are pending.
      if (ref.read(_editorProvider).hasChanges) return;
    }

    _lastProfile = profile;

    _editorProvider =
        StateNotifierProvider.autoDispose<
          ProfileEditorNotifier,
          ProfileEditorState
        >((ref) {
          final notifier = ProfileEditorNotifier(
            originalProfile: profile,
            editingService: ProfileEditingService(),
          );
          if (widget.initialMode != null) {
            notifier.setMode(widget.initialMode!);
          }
          return notifier;
        });
  }

  Future<bool> _onWillPop() async {
    final state = ref.read(_editorProvider);
    if (!state.hasChanges) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.forms_discard_title),
        content: Text(context.l10n.diveLog_profileEditor_discardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.forms_discard_discard),
          ),
        ],
      ),
    );
    return shouldDiscard ?? false;
  }

  Future<void> _handleSave() async {
    final state = ref.read(_editorProvider);
    if (!state.hasChanges) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.diveLog_profileEditor_saveTitle),
        content: Text(context.l10n.diveLog_profileEditor_saveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.common_action_save),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final repository = ref.read(diveRepositoryProvider);
      await repository.saveEditedProfileWithKind(
        diveId: widget.diveId,
        editedPoints: state.editedProfile,
        editKind: state.revisionEditKindToken,
      );
      ref.invalidate(diveProvider(widget.diveId));
      ref.invalidate(diveProfileProvider(widget.diveId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveLog_profileEditor_saveFailed('$e')),
          ),
        );
      }
      return;
    }

    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final diveAsync = ref.watch(diveProvider(widget.diveId));

    return diveAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(context.l10n.diveLog_profileEditor_title)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.diveLog_profileEditor_title)),
        body: Center(
          child: Text(
            context.l10n.diveLog_profileEditor_errorLoadingDive('$error'),
          ),
        ),
      ),
      data: (dive) {
        if (dive == null || dive.profile.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.diveLog_profileEditor_title),
            ),
            body: Center(
              child: Text(context.l10n.diveLog_profileEditor_noProfileData),
            ),
          );
        }

        _initializeProvider(dive.profile);

        return _buildEditor();
      },
    );
  }

  Widget _buildEditor() {
    final state = ref.watch(_editorProvider);
    final notifier = ref.read(_editorProvider.notifier);

    return PopScope(
      canPop: !state.hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Text(context.l10n.diveLog_profileEditor_title),
              const SizedBox(width: 12),
              Flexible(
                child: _buildProfileRevisionControl(
                  context,
                  ref,
                  widget.diveId,
                  enabled: !state.hasChanges,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: state.undoStack.isNotEmpty
                  ? () => notifier.undo()
                  : null,
              tooltip: context.l10n.diveLog_profileEditor_undo,
            ),
            FilledButton.icon(
              onPressed: state.hasChanges ? _handleSave : null,
              icon: const Icon(Icons.save, size: 18),
              label: Text(context.l10n.common_action_save),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ProfileEditorChart(
                originalProfile: state.originalProfile,
                editedProfile: state.editedProfile,
                outliers: state.detectedOutliers,
                waypoints: state.waypoints,
                selectedRange: state.selectedRange,
                mode: state.mode,
                onTap: (timestamp, depth) {
                  if (state.mode == EditorMode.draw) {
                    notifier.addWaypoint(
                      ProfileWaypoint(timestamp: timestamp, depth: depth),
                    );
                  }
                },
                onRangeChanged: (start, end) =>
                    notifier.setSelectedRange(start: start, end: end),
              ),
            ),
            EditorToolbar(
              mode: state.mode,
              onModeChanged: (mode) => notifier.setMode(mode),
            ),
            EditorContextPanel(
              mode: state.mode,
              notifier: notifier,
              outlierCount: state.detectedOutliers?.length,
              selectedRange: state.selectedRange,
              hasWaypoints: state.waypoints?.isNotEmpty ?? false,
            ),
          ],
        ),
      ),
    );
  }

  /// Switching revisions reloads the editor, so [enabled] is false while
  /// the session has unsaved edits that the switch would discard.
  Widget _buildProfileRevisionControl(
    BuildContext context,
    WidgetRef ref,
    String diveId, {
    required bool enabled,
  }) {
    final historyAsync = ref.watch(profileSeriesHistoryProvider(diveId));
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    return historyAsync.when(
      loading: () => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) => Icon(
        Icons.history_toggle_off,
        size: 18,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      data: (revisions) {
        if (revisions.isEmpty) {
          return const SizedBox.shrink();
        }

        final active = revisions.firstWhere(
          (r) => r.isActive,
          orElse: () => revisions.first,
        );

        final activeLabel =
            '${_revisionKindLabel(context, active.revisionKind)} · '
            '${_formatRevisionCreatedAt(units, active.createdAt)}';

        return PopupMenuButton<String>(
          tooltip: context.l10n.diveLog_profileEditor_revisionSelectorTooltip,
          enabled: enabled,
          onSelected: (seriesId) async {
            if (seriesId == active.seriesId) return;
            try {
              await ref
                  .read(diveRepositoryProvider)
                  .setActiveProfileSeries(diveId, seriesId);
              // Invalidate profile-related providers to refresh the editor
              ref.invalidate(diveProvider(diveId));
              ref.invalidate(diveProfileProvider(diveId));
              ref.invalidate(profileSeriesHistoryProvider(diveId));
            } catch (_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.l10n.diveLog_profileEditor_revisionSwitchFailed,
                  ),
                ),
              );
            }
          },
          itemBuilder: (_) => [
            for (final revision in revisions)
              CheckedPopupMenuItem<String>(
                value: revision.seriesId,
                checked: revision.isActive,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_revisionKindLabel(context, revision.revisionKind)),
                    Text(
                      _formatRevisionCreatedAt(units, revision.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    activeLabel,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _revisionKindLabel(BuildContext context, String revisionKind) =>
      switch (revisionKind) {
        final String s when _extractEditTypeToken(s) != null =>
          '${context.l10n.diveLog_detail_profileRevision_kind_edit}: '
              '${_revisionEditTypeLabel(context, _extractEditTypeToken(s)!)}',
        'edit' => context.l10n.diveLog_detail_profileRevision_kind_edit,
        'create' => context.l10n.diveLog_detail_profileRevision_kind_create,
        'computer_import' =>
          context.l10n.diveLog_detail_profileRevision_kind_computerImport,
        'legacy' => context.l10n.diveLog_detail_profileRevision_kind_legacy,
        _ => revisionKind,
      };

  String? _extractEditTypeToken(String revisionKind) {
    if (revisionKind.startsWith('Edit: ')) {
      return revisionKind.substring('Edit: '.length).trim();
    }
    if (revisionKind.startsWith('edit:')) {
      return revisionKind.substring('edit:'.length).trim();
    }
    return null;
  }

  String _revisionEditTypeLabel(BuildContext context, String editType) =>
      editType
          .split('+')
          .where((part) => part.trim().isNotEmpty)
          .map((part) => _singleRevisionEditTypeLabel(context, part.trim()))
          .join(', ');

  String _singleRevisionEditTypeLabel(
    BuildContext context,
    String editType,
  ) => switch (editType) {
    'profile_editor' =>
      context.l10n.diveLog_detail_profileRevision_editType_profileEditor,
    'data_quality_repair' =>
      context.l10n.diveLog_detail_profileRevision_editType_dataQualityRepair,
    'smooth_all' =>
      context.l10n.diveLog_detail_profileRevision_editType_smoothAll,
    'smooth_selection' =>
      context.l10n.diveLog_detail_profileRevision_editType_smoothSelection,
    'remove_all_outliers' =>
      context.l10n.diveLog_detail_profileRevision_editType_removeAllOutliers,
    'remove_selected_outliers' =>
      context
          .l10n
          .diveLog_detail_profileRevision_editType_removeSelectedOutliers,
    'shift_depth' =>
      context.l10n.diveLog_detail_profileRevision_editType_shiftDepth,
    'shift_time' =>
      context.l10n.diveLog_detail_profileRevision_editType_shiftTime,
    'delete_segment' =>
      context.l10n.diveLog_detail_profileRevision_editType_deleteSegment,
    'delete_segment_interpolated' =>
      context
          .l10n
          .diveLog_detail_profileRevision_editType_deleteSegmentInterpolated,
    'generate_from_waypoints' =>
      context
          .l10n
          .diveLog_detail_profileRevision_editType_generateFromWaypoints,
    'trim_end_zeros' =>
      context.l10n.diveLog_detail_profileRevision_editType_trimEndZeros,
    _ => editType,
  };

  String _formatRevisionCreatedAt(UnitFormatter units, int createdAtMs) {
    return units.formatDateTimeBullet(
      DateTime.fromMillisecondsSinceEpoch(createdAtMs),
    );
  }
}
