import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/track_locations.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_shape_thumbnail.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_route_links_sitting.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// The dive detail "Underwater Track" section (spec
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
    // The card reads only (issue #4527): routes are linked and unlinked in
    // the open card. It shows a sitting's routes once it changed them.
    final session = RecordEditScope.maybeOf<Dive>(context)?.session;
    final draft = session == null ? null : sittingRouteDraft(session);
    final routes = draft != null && draft.hasChanges
        ? _withPrimary(draft)
        : routesAsync.value ?? const <NavTrack>[];
    final isExpanded = ref.watch(navTrackSectionExpandedProvider);
    final l10n = context.l10n;

    return CollapsibleCardSection(
      title: l10n.navTrack_section_trackTitle,
      icon: Icons.route,
      collapsedSubtitle: l10n.navTrack_section_trackCount(routes.length),
      // Its pencil, while the dive is unlocked.
      trailing: RecordCardPencil(cardTitle: l10n.navTrack_section_trackTitle),
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

/// [draft]'s routes, with its chosen primary marked as the primary.
List<NavTrack> _withPrimary(DiveRouteLinkDraft draft) {
  final primary = draft.primaryId;
  if (primary == null) return draft.current;
  return [
    for (final r in draft.current) r.copyWith(isPrimary: r.id == primary),
  ];
}

/// A linked route, opened by a tap; its menu offers Open and 3D only, since
/// linking is changed in the open card.
class _RouteRow extends ConsumerWidget {
  const _RouteRow({required this.route});

  final NavTrack route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitFormatterProvider);
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
            if (route.maxSpeed != null) units.formatTrackSpeed(route.maxSpeed!),
            if (route.isPrimary) l10n.navTrack_section_primaryTag,
          ].join(' · '),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'open':
                context.push(underwaterTrackLocation(route.id));
              case '3d':
                context.push(underwaterTrackSeascapeLocation(route.id));
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'open',
              child: Text(l10n.navTrack_section_menuOpenTrack),
            ),
            PopupMenuItem(
              value: '3d',
              child: Text(l10n.navTrack_section_menuOpen3d),
            ),
          ],
        ),
        onTap: () => context.push(underwaterTrackLocation(route.id)),
      ),
    );
  }
}
