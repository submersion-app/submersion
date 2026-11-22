import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_stats.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_dive_label.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The underwater track page's cards (issue #4022, #4023), shared by the
/// page as it is and as it edits in place (issue #4527, plan 5).

/// The track's name (or source file, or a default), as the first, most
/// prominent card in the body (#4022) rather than the AppBar title: with
/// the three action icons and the overflow menu, a long name had no room
/// left in the toolbar row. Styled like [NavTrackStatsCard]'s box, just with
/// emphasized text, mirroring the equipment set detail page's header card.
class NavTrackTitleCard extends StatelessWidget {
  const NavTrackTitleCard({super.key, required this.title, this.pencil});

  final String title;

  /// The card's pencil (issue #4527).
  final Widget? pencil;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        // Restores what AppBar.title gives its text, lost by moving the
        // title out of the AppBar (#4022): the heading landmark, and the
        // route name where AppBar sets one.
        child: Semantics(
          header: true,
          namesRoute: switch (defaultTargetPlatform) {
            TargetPlatform.iOS || TargetPlatform.macOS => null,
            _ => true,
          },
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              ?pencil,
            ],
          ),
        ),
      ),
    );
  }
}

class NavTrackStatsCard extends ConsumerWidget {
  const NavTrackStatsCard({
    super.key,
    required this.stats,
    required this.units,
  });

  final NavTrackStats stats;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = Duration(seconds: stats.durationSeconds);
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.navTrack_detail_distance(
                units.formatDistance(stats.totalDistance),
              ),
            ),
            Text(
              l10n.navTrack_detail_maxDepth(units.formatDepth(stats.maxDepth)),
            ),
            if (stats.maxSpeed != null)
              Text(
                l10n.navTrack_detail_maxSpeed(
                  units.formatTrackSpeed(stats.maxSpeed!),
                ),
              ),
            if (stats.avgSpeed != null)
              Text(
                l10n.navTrack_detail_avgSpeed(
                  units.formatTrackSpeed(stats.avgSpeed!),
                ),
              ),
            Text(
              l10n.navTrack_detail_duration(
                duration.inHours,
                duration.inMinutes.remainder(60),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavTrackLinkCard extends ConsumerWidget {
  const NavTrackLinkCard({super.key, required this.route, this.pencil});

  final NavTrack route;

  /// The card's pencil.
  final Widget? pencil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final diveId = route.diveId;
    if (diveId == null) {
      return NavTrackActionCard(
        key: const ValueKey('nav-track-no-dive'),
        icon: Icons.link_off,
        label: l10n.navTrack_detail_noDiveLinked,
        pencil: pencil,
      );
    }
    final dive = ref.watch(diveProvider(diveId)).value;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: const ValueKey('nav-track-linked-dive'),
        leading: const Icon(Icons.link),
        title: Text(navTrackDiveLabel(l10n, diveId, dive)),
        trailing: _trailing(pencil, opens: true),
        onTap: () => context.push('/dives/$diveId'),
      ),
    );
  }
}

/// The route's dive site row, built from the same [NavTrackActionCard] as
/// [NavTrackLinkCard]'s "no dive linked" row: a site name or a "no site"
/// placeholder (item 4). The site is changed in the Site card's editor.
class NavTrackSiteCard extends ConsumerWidget {
  const NavTrackSiteCard({super.key, required this.route, this.pencil});

  final NavTrack route;

  /// The card's pencil.
  final Widget? pencil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final siteId = route.siteId;
    final siteName = siteId == null
        ? null
        : ref.watch(siteProvider(siteId)).value?.name;
    return NavTrackActionCard(
      key: const ValueKey('nav-track-site-row'),
      icon: Icons.place_outlined,
      label: siteName ?? l10n.navTrack_detail_noSite,
      onTap: siteId == null ? null : () => context.push('/sites/$siteId'),
      pencil: pencil,
    );
  }
}

/// The route's device/equipment row, built from the same [NavTrackActionCard]
/// as [NavTrackSiteCard]: an equipment or device name, or a "no device"
/// placeholder. Mirrors the site row so the two "set this once at import,
/// change it any time afterward" fields read the same way. The device is
/// changed in the Device card's editor.
class NavTrackEquipmentCard extends ConsumerWidget {
  const NavTrackEquipmentCard({super.key, required this.route, this.pencil});

  final NavTrack route;

  /// The card's pencil.
  final Widget? pencil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final equipmentId = route.equipmentId;
    // A picked equipment item's own name wins over the stored deviceName
    // (set once at import, possibly stale) once equipment has resolved;
    // deviceName alone covers an import that named a device without
    // picking a catalog equipment item.
    final equipmentName = equipmentId == null
        ? null
        : ref.watch(equipmentItemProvider(equipmentId)).value?.name;
    final label = equipmentName ?? route.deviceName;
    return NavTrackActionCard(
      key: const ValueKey('nav-track-equipment-row'),
      icon: Icons.directions_boat_filled_outlined,
      label: label ?? l10n.navTrack_detail_noEquipment,
      onTap: equipmentId == null
          ? null
          : () => context.push('/equipment/$equipmentId'),
      pencil: pencil,
    );
  }
}

/// A card row with an icon, a label, and a text action on its own line
/// below the label. The action sits in the subtitle rather than in
/// trailing: a ListTile measures its trailing widget against the full tile
/// width and gives the title column whatever is left, so a translated
/// action there ("Tauchgang wählen") starves the label down to one fragment
/// per line on a phone (issue #2692, same hazard as #935).
class NavTrackActionCard extends StatelessWidget {
  const NavTrackActionCard({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.pencil,
  });

  final IconData icon;
  final String label;

  /// The card's pencil.
  final Widget? pencil;

  /// Opens whatever this card is about (the site, the equipment item);
  /// null when there is nothing to open yet (#4023), matching the "no dive
  /// linked" state of [NavTrackLinkCard], which has no `onTap` either.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: _trailing(pencil, opens: onTap != null),
        onTap: onTap,
      ),
    );
  }
}

/// A card row's trailing widgets: the pencil, then the chevron of a card
/// that opens what it is about.
Widget? _trailing(Widget? pencil, {required bool opens}) {
  if (pencil == null) return opens ? const Icon(Icons.chevron_right) : null;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [pencil, if (opens) const Icon(Icons.chevron_right)],
  );
}
