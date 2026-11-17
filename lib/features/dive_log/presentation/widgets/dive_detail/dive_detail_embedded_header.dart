import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_title.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_nav_buttons.dart';
import 'package:submersion/features/dive_log/presentation/widgets/draft_dive_banner.dart';
import 'package:submersion/features/dive_log/presentation/widgets/planned_dive_banner.dart';
import 'package:submersion/features/dive_log/presentation/widgets/site_suggestion_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';

/// Compact header bar for embedded mode in master-detail layout.
class DiveDetailEmbeddedHeader extends ConsumerWidget {
  const DiveDetailEmbeddedHeader({
    super.key,
    required this.dive,
    required this.menu,
    required this.onNavigate,
    required this.onMarkLogged,
    required this.onDownloadDraft,
    this.onSurfaceDraft,
    this.editing,
    this.lock,
    this.history,
    this.unlockedRow,
    this.creating = false,
  });

  /// A new dive not yet created (issue #4527, plan 8): no banner and no
  /// site suggestion, which act on a stored dive.
  final bool creating;

  final Dive dive;

  /// The overflow button at the end of the bar.
  final Widget menu;

  final void Function(String neighborId) onNavigate;
  final VoidCallback onMarkLogged;

  /// A draft's "Download now" and "Surfaced" (issue #637); "Mark as
  /// complete" shares [onMarkLogged].
  final VoidCallback onDownloadDraft;
  final VoidCallback? onSurfaceDraft;

  /// The pane's lock state when it offers unlock-to-edit (issue #4527), or
  /// null when it does not: then the header is as it always was.
  final RecordEditController<Dive>? editing;

  /// The lock, and History beside it, in the locked row.
  final Widget? lock;
  final Widget? history;

  /// Laid over the locked row while the dive is unlocked: Cancel, the
  /// title, the menu and Save. The locked row keeps its place beneath it.
  final Widget? unlockedRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final editing = this.editing;
    // What the banners offer acts on the whole dive at once: on a pane that
    // offers editing, only while unlocked with nothing to save.
    final operationReason = recordOperationReason(
      context.l10n,
      recordOperationBlockOf(editing),
    );

    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Dive number badge
          CircleAvatar(
            radius: 16,
            backgroundColor: colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '#${dive.diveNumber ?? '-'}',
                  maxLines: 1,
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Site name and location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  diveTitle(context, dive),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (dive.effectiveName != null && dive.site != null)
                  Text(
                    dive.site!.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                if (dive.site?.locationString.isNotEmpty == true)
                  Text(
                    dive.site!.locationString,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          DiveNavButtons(diveId: dive.id, onNavigate: onNavigate),
          // With editing offered favourite is a field of the header
          // card, so the pane shows it as a state only (issue #4527).
          if (editing != null)
            if (dive.isFavorite)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 20,
                  semanticLabel: context.l10n.enum_diveField_isFavorite,
                ),
              )
            else
              const SizedBox.shrink()
          else
            IconButton(
              icon: Icon(
                dive.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: dive.isFavorite ? Colors.red : null,
                size: 20,
              ),
              visualDensity: VisualDensity.compact,
              tooltip: dive.isFavorite
                  ? context.l10n.diveLog_detail_tooltip_removeFromFavorites
                  : context.l10n.diveLog_detail_tooltip_addToFavorites,
              onPressed: () {
                ref
                    .read(paginatedDiveListProvider.notifier)
                    .toggleFavorite(dive.id);
              },
            ),
          ?history,
          ?lock,
          menu,
        ],
      ),
    );
    final unlockedRow = this.unlockedRow;
    final unlocked = editing?.isUnlocked == true && unlockedRow != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!unlocked)
          row
        else
          Stack(
            children: [
              Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: row,
              ),
              Positioned.fill(child: unlockedRow),
            ],
          ),
        if (dive.isPlanned && !creating)
          PlannedDiveBanner(
            diveId: dive.id,
            onMarkLogged: onMarkLogged,
            operationReason: operationReason,
          ),
        if (dive.isDraft && !creating)
          DraftDiveBanner(
            dive: dive,
            onMarkComplete: onMarkLogged,
            onDownload: onDownloadDraft,
            onSurfaced: onSurfaceDraft,
            operationReason: operationReason,
          ),
        if (!creating)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SiteSuggestionCard(
              diveId: dive.id,
              currentSite: dive.site,
              editing: siteSuggestionEditingOf(context),
            ),
          ),
      ],
    );
  }
}
