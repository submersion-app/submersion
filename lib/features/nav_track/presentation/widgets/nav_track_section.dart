import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_shape_thumbnail.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The dive detail "Underwater Route" section (spec
/// 2026-09-10-underwater-nav-track-design.md, "Dive detail section"): the
/// routes linked to this dive. The detail page only shows it when at least
/// one route is linked; linking and importing happen on the Dive Edit page
/// (spec 2026-10-02-underwater-route-entry-points-design.md).
class NavTrackSection extends ConsumerWidget {
  const NavTrackSection({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(navTracksForDiveProvider(dive.id));
    final routes = routesAsync.value ?? const <NavTrack>[];
    final isExpanded = ref.watch(navTrackSectionExpandedProvider);
    final l10n = context.l10n;

    return CollapsibleCardSection(
      title: l10n.navTrack_section_title,
      icon: Icons.route,
      collapsedSubtitle: l10n.navTrack_section_routeCount(routes.length),
      isExpanded: isExpanded,
      onToggle: (expanded) =>
          ref.read(navTrackSectionExpandedProvider.notifier).state = expanded,
      contentBuilder: (context) {
        if (!isExpanded || routes.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              for (final route in routes) _RouteRow(route: route),
            ],
          ),
        );
      },
    );
  }
}

class _RouteRow extends ConsumerWidget {
  const _RouteRow({required this.route});

  final NavTrack route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final l10n = context.l10n;
    // navTracksForDiveProvider reads with includePoints: false (a dive can
    // have several linked routes, and this section renders every one of
    // them), so route.points is always empty here. Distance/depth/speed
    // come straight from the persisted summary columns rather than
    // recomputing NavTrackStats.of an empty list, which would silently show
    // zero for every row; only the shape thumbnail actually needs the raw
    // samples, so just that is hydrated per row on demand.
    final hydratedPoints =
        ref.watch(navTrackByIdProvider(route.id)).value?.points ?? const [];
    return Card(
      key: ValueKey('nav-track-row-${route.id}'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: NavTrackShapeThumbnail(points: hydratedPoints),
        title: Text(route.name ?? route.sourceRef ?? route.id),
        subtitle: Text(
          [
            if (route.deviceName != null) route.deviceName!,
            if (route.totalDistance != null)
              units.formatDistance(route.totalDistance!),
            if (route.maxDepth != null) units.formatDepth(route.maxDepth),
            if (route.maxSpeed != null) units.formatSpeed(route.maxSpeed!),
            if (route.isPrimary) l10n.navTrack_section_primaryTag,
          ].join(' · '),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'unlink':
                await ref.read(navTrackRepositoryProvider).unlink(route.id);
              case 'primary':
                await ref.read(navTrackRepositoryProvider).setPrimary(route.id);
              case 'open':
                context.push('/nav-routes/${route.id}');
              case '3d':
                context.push('/nav-routes/${route.id}/3d');
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'open',
              child: Text(l10n.navTrack_section_menuOpen),
            ),
            PopupMenuItem(
              value: '3d',
              child: Text(l10n.navTrack_section_menuOpen3d),
            ),
            PopupMenuItem(
              value: 'unlink',
              child: Text(l10n.navTrack_common_unlink),
            ),
            if (!route.isPrimary)
              PopupMenuItem(
                value: 'primary',
                child: Text(l10n.navTrack_section_menuMakePrimary),
              ),
          ],
        ),
        onTap: () => context.push('/nav-routes/${route.id}'),
      ),
    );
  }
}
