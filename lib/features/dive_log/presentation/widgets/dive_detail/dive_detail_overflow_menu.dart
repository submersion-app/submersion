import 'package:flutter/material.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_update.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_resync_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail_properties_menu.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
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
    this.showFavorite = false,
  });

  final Dive dive;

  /// In the master-detail pane: a smaller button, led by "open full page".
  final bool embedded;

  /// Identifies the button that opened the menu, for the iPad share popover.
  final GlobalKey menuKey;

  /// Opens the display-options panel, which hangs off this button.
  final MenuController displayOptions;

  /// Offer the favorite toggle here, for an app bar with no room for its icon.
  final bool showFavorite;

  /// Handed the chosen entry's value, and the pre-dive checklist linked to
  /// this dive for the entries that act on it.
  final void Function(String value, PreDiveSession? linkedPreDive) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkedPlanId = ref.watch(planLinkedToDiveProvider(dive.id)).value;
    final hasRawData =
        ref.watch(diveHasRawDataProvider(dive.id)).valueOrNull ?? false;
    final hasImportedFile =
        ref.watch(diveHasImportedFileProvider(dive.id)).valueOrNull ?? false;
    final linkedPreDive = ref
        .watch(preDiveSessionForDiveProvider(dive.id))
        .value;
    final canLogForBuddy = _hasMirrorCandidates(ref);
    final favoriteLabel = dive.isFavorite
        ? context.l10n.diveLog_detail_tooltip_removeFromFavorites
        : context.l10n.diveLog_detail_tooltip_addToFavorites;

    return DiveDetailPropertiesMenu(
      isGauge: dive.isGauge,
      controller: displayOptions,
      child: PopupMenuButton<String>(
        key: menuKey,
        icon: embedded ? const Icon(Icons.more_vert, size: 20) : null,
        padding: embedded ? EdgeInsets.zero : const EdgeInsets.all(8),
        onSelected: (value) => onSelected(value, linkedPreDive),
        itemBuilder: (context) => [
          changeLogHistoryMenuItem(
            context,
            rootTable: 'dives',
            rootId: dive.id,
          ),
          if (embedded)
            PopupMenuItem(
              value: 'open',
              child: ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(context.l10n.diveLog_detail_menu_openFullPage),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          displayOptionsMenuItem(context, 'displayOptions'),
          if (showFavorite)
            PopupMenuItem(
              value: 'toggleFavorite',
              child: ListTile(
                leading: Icon(
                  dive.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: dive.isFavorite ? Colors.red : null,
                ),
                title: Text(favoriteLabel),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          PopupMenuItem(
            value: 'export',
            child: ListTile(
              leading: const Icon(Icons.download),
              title: Text(context.l10n.diveLog_detail_menu_export),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'logNearMiss',
            child: ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(context.l10n.diveLog_detail_menu_logNearMiss),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (dive.isPlanned)
            PopupMenuItem(
              value: 'markLogged',
              child: ListTile(
                leading: const Icon(Icons.event_available_outlined),
                title: Text(context.l10n.diveLog_detail_menu_markLogged),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (canLogForBuddy)
            PopupMenuItem(
              value: 'logForBuddy',
              child: ListTile(
                leading: const Icon(Icons.people_outline),
                title: Text(context.l10n.diveLog_detail_menu_logForBuddy),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          _preDiveLinkMenuItem(context, linkedPreDive),
          if (hasRawData)
            PopupMenuItem(
              value: 'reparse',
              child: ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(context.l10n.diveLog_detail_menu_reparseRawData),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (hasImportedFile)
            PopupMenuItem(
              value: 'resync',
              child: ListTile(
                leading: const Icon(Icons.sync),
                title: Text(
                  context.l10n.diveLog_detail_menu_resyncImportedFile,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (dive.profile.isNotEmpty)
            PopupMenuItem(
              value: 'whatIf',
              child: ListTile(
                leading: const Icon(Icons.tune),
                title: Text(context.l10n.diveLog_detail_menu_whatIf),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          // A dived plan, only while the plan it came from still exists.
          if (!dive.isPlanned && linkedPlanId != null)
            PopupMenuItem(
              value: 'viewInPlanner',
              child: ListTile(
                leading: const Icon(Icons.route),
                title: Text(context.l10n.diveLog_detail_menu_viewInPlanner),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (!dive.isPlanned)
            PopupMenuItem(
              value: 'planRepetitive',
              child: ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: Text(context.l10n.diveLog_detail_menu_planRepetitive),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(
                context.l10n.diveLog_detail_menu_delete,
                style: const TextStyle(color: Colors.red),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
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
    PreDiveSession? linked,
  ) {
    return PopupMenuItem(
      value: linked == null ? 'linkPreDive' : 'unlinkPreDive',
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
