import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Suggests a site for a dive from a GPS point (photo or dive computer).
/// Purely presentational: the caller resolves the proposal and wires the
/// actions (see SiteSuggestionCard). Which buttons appear depends on whether
/// the dive already has a (coordinate-less) site and on the match status.
class SiteSuggestionBanner extends StatelessWidget {
  const SiteSuggestionBanner({
    super.key,
    required this.pointSource,
    required this.coordinates,
    required this.status,
    required this.hasSite,
    required this.siteName,
    required this.candidateCount,
    required this.recommendedDistanceMeters,
    required this.onAssign,
    required this.onChooseNearby,
    required this.onCreate,
    required this.onAddLocation,
    required this.onDismiss,
  });

  final PointSource pointSource;

  /// Already formatted with the diver's coordinate format preference.
  final String coordinates;
  final ProposalStatus status;

  /// True when the dive has a site that merely lacks coordinates.
  final bool hasSite;

  /// The current site's name, or the recommended candidate's name.
  final String siteName;
  final int candidateCount;
  final double? recommendedDistanceMeters;
  final VoidCallback? onAssign;
  final VoidCallback? onChooseNearby;
  final VoidCallback? onCreate;
  final VoidCallback? onAddLocation;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pointSource == PointSource.photo
                      ? l10n.siteSuggestion_titlePhoto
                      : l10n.siteSuggestion_titleDiveComputer,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                tooltip: l10n.media_gpsBanner_dismissTooltip,
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.media_gpsBanner_coordinates(coordinates),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 12),
          OverflowBar(spacing: 8, overflowSpacing: 8, children: _actions(l10n)),
        ],
      ),
    );
  }

  List<Widget> _actions(AppLocalizations l10n) {
    final create = OutlinedButton.icon(
      onPressed: onCreate,
      icon: const Icon(Icons.add_location_alt, size: 18),
      label: Text(l10n.media_gpsBanner_createSiteButton),
    );
    Widget choose(int count) => OutlinedButton.icon(
      onPressed: onChooseNearby,
      icon: const Icon(Icons.map_outlined, size: 18),
      label: Text(l10n.siteSuggestion_chooseNearbyButton(count)),
    );
    if (hasSite) {
      final add = FilledButton.icon(
        onPressed: onAddLocation,
        icon: const Icon(Icons.edit_location_alt, size: 18),
        label: Text(l10n.siteSuggestion_addLocationButton(siteName)),
      );
      return switch (status) {
        ProposalStatus.review => [add, choose(candidateCount - 1)],
        _ => [add],
      };
    }
    return switch (status) {
      ProposalStatus.clear => [
        FilledButton.icon(
          onPressed: onAssign,
          icon: const Icon(Icons.push_pin_outlined, size: 18),
          label: Text(
            '${l10n.siteSuggestion_assignButton(siteName)} · '
            '${l10n.siteMatchReview_awayMeters((recommendedDistanceMeters ?? 0).round())}',
          ),
        ),
        create,
      ],
      ProposalStatus.review => [
        FilledButton.icon(
          onPressed: onChooseNearby,
          icon: const Icon(Icons.map_outlined, size: 18),
          label: Text(l10n.siteSuggestion_chooseNearbyButton(candidateCount)),
        ),
        create,
      ],
      ProposalStatus.none => [
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_location_alt, size: 18),
          label: Text(l10n.media_gpsBanner_createSiteButton),
        ),
      ],
    };
  }
}
