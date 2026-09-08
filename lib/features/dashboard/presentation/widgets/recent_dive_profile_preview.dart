import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart_host.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Depth profile of the newest dive, shown beside the recent-dives list on
/// wide windows.
///
/// The list itself is pinned to the width a dive card has on the Dives page,
/// so on a wide desktop window there is a large amount of space left over.
/// This fills it with the one thing a dive list row cannot show: the shape of
/// the dive.
///
/// Draws the real [DiveProfileChart] through [DiveProfileChartHost], not a
/// simplified rendition of it: same curves, same legend, same markers, same
/// gestures. The legend's metric toggles are app-wide session state, so a
/// curve the diver turned on in dive details is already on here.
class RecentDiveProfilePreview extends ConsumerWidget {
  const RecentDiveProfilePreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final divesAsync = ref.watch(recentDivesProvider);
    final newest = divesAsync.valueOrNull?.firstOrNull;
    if (newest == null) return const SizedBox.shrink();

    // Re-read the dive through the detail provider rather than charting the
    // list's copy: that one refreshes on `dives`-table writes only, so a
    // reparse or a sync pull rewriting the samples in place would leave this
    // chart showing the pre-reparse shape.
    final diveAsync = ref.watch(diveProvider(newest.id));
    // A loaded null is "no such dive", the way the detail page reads it: the
    // newest dive was deleted between the list read and this one, and the
    // list is about to drop it too. Collapse the slot, as this widget already
    // does when there is no dive at all. Falling through to "no profile data"
    // would state a different, and untrue, fact about a dive that is gone.
    if (diveAsync case AsyncData(value: null)) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(dive: diveAsync.value ?? newest),
            const SizedBox(height: 8),
            Expanded(
              child: diveAsync.when(
                // The null arm is unreachable, and present only to satisfy
                // the provider's nullable type: AsyncData(value: null)
                // returned above.
                data: (dive) => dive == null || dive.profile.isEmpty
                    ? _Placeholder(
                        icon: Icons.show_chart,
                        message:
                            context.l10n.dashboard_recentDives_noProfileData,
                      )
                    : DiveProfileChartHost(dive: dive),
                loading: () => const Center(child: CircularProgressIndicator()),
                // A failed load and a dive with no samples are different
                // facts. Reporting "no profile data" for a failure hides the
                // error and tells the diver something untrue about the dive.
                error: (_, _) => _Placeholder(
                  icon: Icons.error_outline,
                  message: context.l10n.dashboard_recentDives_profileLoadError,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Title, site and max depth, with the affordances the dive detail page puts
/// above its own chart that still make sense here.
///
/// The card as a whole is deliberately not tappable: the chart under this row
/// has its own pan, zoom, tooltip and range gestures, and an ancestor InkWell
/// would swallow them.
class _Header extends ConsumerWidget {
  const _Header({required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatter = UnitFormatter(ref.watch(settingsProvider));
    final siteName = dive.site?.name;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.push('/dives/${dive.id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.dashboard_recentDives_latestProfileTitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (siteName != null && siteName.isNotEmpty)
                    Text(
                      siteName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (dive.maxDepth != null)
          Text(
            formatter.formatDepth(dive.maxDepth),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        IconButton(
          icon: const Icon(Icons.fullscreen),
          tooltip: context.l10n.diveLog_detail_tooltip_viewFullscreen,
          visualDensity: VisualDensity.compact,
          // Root navigator, not the ShellRoute's: pushing on the shell
          // navigator renders the page inside MainScaffold, leaving the bottom
          // navigation bar painted under a supposedly fullscreen chart (#811).
          onPressed: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => FullscreenProfilePage(diveId: dive.id),
            ),
          ),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
