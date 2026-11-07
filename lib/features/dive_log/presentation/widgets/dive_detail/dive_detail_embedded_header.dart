import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_nav_buttons.dart';
import 'package:submersion/features/dive_log/presentation/widgets/planned_dive_banner.dart';
import 'package:submersion/features/dive_log/presentation/widgets/site_suggestion_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Compact header bar for embedded mode in master-detail layout.
class DiveDetailEmbeddedHeader extends ConsumerWidget {
  const DiveDetailEmbeddedHeader({
    super.key,
    required this.dive,
    required this.menu,
    required this.onNavigate,
    required this.onMarkLogged,
  });

  final Dive dive;

  /// The overflow button at the end of the bar.
  final Widget menu;

  final void Function(String neighborId) onNavigate;
  final VoidCallback onMarkLogged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
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
                      dive.effectiveName ??
                          dive.site?.name ??
                          context.l10n.diveLog_listPage_unknownSite,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
              // Favorite toggle
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
              // Edit button: use query params in master-detail layout
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                visualDensity: VisualDensity.compact,
                tooltip: context.l10n.diveLog_detail_tooltip_edit,
                onPressed: () {
                  final state = GoRouterState.of(context);
                  final currentPath = state.uri.path;
                  context.goInPlace(
                    '$currentPath?selected=${dive.id}&mode=edit',
                  );
                },
              ),
              menu,
            ],
          ),
        ),
        if (dive.isPlanned)
          PlannedDiveBanner(diveId: dive.id, onMarkLogged: onMarkLogged),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SiteSuggestionCard(diveId: dive.id, currentSite: dive.site),
        ),
      ],
    );
  }
}
