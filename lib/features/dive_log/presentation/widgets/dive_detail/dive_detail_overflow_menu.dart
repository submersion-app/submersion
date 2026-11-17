import 'package:flutter/material.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_health_metrics_providers.dart';
import 'package:submersion/features/dive_import/presentation/providers/health_settings_providers.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_resync_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail_properties_menu.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_links.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';
import 'package:submersion/shared/widgets/section_properties_menu.dart';

/// The overflow button on the dive detail page, in the standalone app bar or
/// the compact header of the master-detail pane.
///
/// Whether each entry is offered depends on providers of its own, so this
/// watches them rather than the page: a menu that is not even open has no
/// reason to rebuild the page when one of them resolves.
class DiveDetailOverflowMenu extends ConsumerWidget {
  const DiveDetailOverflowMenu({
    super.key,
    required this.dive,
    required this.embedded,
    required this.menuKey,
    required this.displayOptions,
    required this.onSelected,
    required this.operations,
    this.historyInBar = false,
  });

  final Dive dive;

  /// In the master-detail pane: a smaller button, led by "open full page".
  final bool embedded;

  /// Identifies the button that opened the menu, for the iPad share popover.
  final GlobalKey menuKey;

  /// Opens the display-options panel, which hangs off this button.
  final MenuController displayOptions;

  /// Whether the whole-record operations may run (issue #4527).
  final RecordOperationBlock operations;

  /// The bar shows History beside the lock, so the menu leaves it out.
  final bool historyInBar;

  /// Handed the chosen entry's value, and the pre-dive checklist linked to
  /// this dive for the entries that act on it.
  final void Function(String value, PreDiveSession? linkedPreDive) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A dived dive's plan, while that plan exists (issue #3565); a planned
    // one offers it on its banner.
    final linkedPlanId = dive.isPlanned
        ? null
        : ref.watch(planForLoggedDiveProvider(dive.id)).value;
    // Re-parsing runs the native parser, which a browser lacks (#4121).
    final canReparse =
        ref.watch(deviceCapabilitiesProvider).diveComputerDownload &&
        (ref.watch(diveHasRawDataProvider(dive.id)).valueOrNull ?? false);
    final hasImportedFile =
        ref.watch(diveHasImportedFileProvider(dive.id)).valueOrNull ?? false;
    final linkedPreDive = ref
        .watch(preDiveSessionForDiveProvider(dive.id))
        .value;
    final canLogForBuddy = _hasMirrorCandidates(ref);
    // Health first: off iOS the settings are never read (issue #637).
    final canAddHeartRate =
        ref.watch(diveHealthMetricsServiceProvider) != null &&
        ref.watch(healthSettingsProvider.select((s) => s.metricsDiverId)) ==
            dive.diverId &&
        dive.diverId != null &&
        !(dive.isPlanned && !dive.isDraft) &&
        !(dive.isDraft && dive.exitTime == null);

    return DiveDetailPropertiesMenu(
      isGauge: dive.isGauge,
      controller: displayOptions,
      child: PopupMenuButton<String>(
        key: menuKey,
        icon: embedded ? const Icon(Icons.more_vert, size: 20) : null,
        padding: embedded ? EdgeInsets.zero : const EdgeInsets.all(8),
        onSelected: (value) => onSelected(value, linkedPreDive),
        itemBuilder: (context) {
          // The whole-record operations follow the items that only read,
          // under one caption while unavailable, and each is enabled only on
          // an unlocked page with nothing to save (issue #4527).
          final free = operations == RecordOperationBlock.none;
          PopupMenuItem<String> item(
            String value,
            IconData icon,
            String label, {
            bool operation = false,
            Color? color,
          }) => PopupMenuItem(
            value: value,
            enabled: !operation || free,
            child: ListTile(
              leading: Icon(icon, color: color),
              title: Text(
                label,
                style: color == null ? null : TextStyle(color: color),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          );
          final l10n = context.l10n;
          final history = changeLogHistoryMenuItem<String>(
            context,
            rootTable: 'dives',
            rootId: dive.id,
          );
          // One sitting per dive (issue #4527): the full page could be
          // unlocked too while the pane holds a sitting, so it waits until
          // the pane is locked again, Save or Cancel.
          final paneUnlocked = operations != RecordOperationBlock.locked;
          final open = PopupMenuItem<String>(
            value: 'open',
            enabled: !paneUnlocked,
            child: ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(l10n.diveLog_detail_menu_openFullPage),
              subtitle: paneUnlocked
                  ? Text(l10n.recordEdit_saveOrCancelFirst)
                  : null,
              contentPadding: EdgeInsets.zero,
            ),
          );
          final export = item(
            'export',
            Icons.download,
            l10n.diveLog_detail_menu_export,
          );
          final nearMiss = item(
            'logNearMiss',
            Icons.flag_outlined,
            l10n.diveLog_detail_menu_logNearMiss,
          );
          final markLogged = item(
            'markLogged',
            Icons.event_available_outlined,
            l10n.diveLog_detail_menu_markLogged,
            operation: true,
          );
          final markComplete = item(
            'markComplete',
            Icons.task_alt,
            l10n.diveLog_draft_markComplete,
            operation: true,
          );
          final heartRate = item(
            'addHeartRate',
            Icons.monitor_heart_outlined,
            l10n.diveLog_detail_menu_addHeartRate,
            operation: true,
          );
          final forBuddy = item(
            'logForBuddy',
            Icons.people_outline,
            l10n.diveLog_detail_menu_logForBuddy,
          );
          final preDive = _preDiveLinkMenuItem(
            context,
            linkedPreDive,
            enabled: free,
          );
          final reparse = item(
            'reparse',
            Icons.refresh,
            l10n.diveLog_detail_menu_reparseRawData,
            operation: true,
          );
          final resync = item(
            'resync',
            Icons.sync,
            l10n.diveLog_detail_menu_resyncImportedFile,
            operation: true,
          );
          final whatIf = item(
            'whatIf',
            Icons.tune,
            l10n.diveLog_detail_menu_whatIf,
          );
          final viewInPlanner = item(
            'viewInPlanner',
            Icons.route,
            l10n.diveLog_detail_menu_viewInPlanner,
          );
          final planRepetitive = item(
            'planRepetitive',
            Icons.add_circle_outline,
            l10n.diveLog_detail_menu_planRepetitive,
          );
          final delete = item(
            'delete',
            Icons.delete,
            l10n.diveLog_detail_menu_delete,
            operation: true,
            color: Colors.red,
          );
          final canMarkLogged = dive.isPlanned;
          // A draft that will never be downloaded (issue #637), once it is
          // out of the water.
          final canMarkComplete = dive.isDraft && dive.exitTime != null;
          final canPlanRepetitive = !dive.isPlanned;
          final reason = recordOperationReason(l10n, operations, plural: true);
          return [
            if (!historyInBar) history,
            if (embedded) open,
            displayOptionsMenuItem(context, 'displayOptions'),
            export,
            nearMiss,
            if (canLogForBuddy) forBuddy,
            if (dive.profile.isNotEmpty) whatIf,
            if (linkedPlanId != null) viewInPlanner,
            if (canPlanRepetitive) planRepetitive,
            const PopupMenuDivider(),
            if (reason != null) recordOperationCaption<String>(context, reason),
            if (canMarkLogged) markLogged,
            if (canMarkComplete) markComplete,
            if (canAddHeartRate) heartRate,
            preDive,
            // Drawn on its own page, for a dive that has none (issue #4527):
            // the old edit form was the only way there.
            if (dive.profile.isEmpty)
              item(
                'drawProfile',
                Icons.draw_outlined,
                l10n.diveLog_edit_profile_draw,
                operation: true,
              ),
            if (canReparse) reparse,
            if (hasImportedFile) resync,
            delete,
          ];
        },
      ),
    );
  }

  /// Overflow entry for the pre-dive checklist link (#1066). PR #913 removed
  /// the dive-detail pre-dive card, and with it the only way to attach a run
  /// completed the evening before, outside the auto-linker's three-hour
  /// window, to the dive it was run for. The label doubles as the indicator:
  /// "Unlink" only appears when something is attached.
  PopupMenuItem<String> _preDiveLinkMenuItem(
    BuildContext context,
    PreDiveSession? linked, {
    bool enabled = true,
  }) {
    return PopupMenuItem(
      value: linked == null ? 'linkPreDive' : 'unlinkPreDive',
      enabled: enabled,
      child: ListTile(
        leading: Icon(
          linked == null ? Icons.fact_check_outlined : Icons.link_off,
        ),
        title: Text(
          linked == null
              ? context.l10n.preDive_link_linkChecklist
              : context.l10n.preDive_link_unlinkChecklist,
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  /// Whether any linked buddy on this dive still lacks a sibling (issue
  /// #2002). Call it from build, never from a menu's itemBuilder: that runs
  /// outside build, so its first read is still loading and the next rebuild
  /// drops the subscription, which disposes the provider before the menu
  /// opens again (issue #2367).
  bool _hasMirrorCandidates(WidgetRef ref) {
    if (dive.isPlanned) return false;
    final candidates = ref.watch(mirrorCandidatesProvider(dive.id)).value;
    return candidates != null && candidates.isNotEmpty;
  }
}
