import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/media_ribbon_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_draft_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/download_target_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/locked_map_scroll_passthrough.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/pre_dive/domain/services/checklist_session_engine.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/defer_until_painted.dart';

// The "only when relevant" panels. Each builds nothing while it has nothing
// to show; the page also leaves it out of the grid then, so no empty box is
// laid out (see DashboardPage).

/// Drafts that ended (an exit time is set) and wait for the dive computer
/// download to fill them in (issue #637).
List<Dive> draftsWaitingForDownload(List<Dive> drafts) => [
  for (final dive in drafts)
    if (dive.exitTime != null) dive,
];

TextStyle? _muted(BuildContext context) => Theme.of(context).textTheme.bodySmall
    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

/// A short row of label and value, for the panels that list a few things.
/// With [onTap] the row is its own tap target, opening its own item.
Widget _line(
  BuildContext context,
  String label,
  String value, {
  VoidCallback? onTap,
}) {
  final row = Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: _muted(context)),
      ],
    ),
  );
  return onTap == null ? row : InkWell(onTap: onTap, child: row);
}

/// A dive logged on this date in an earlier year.
class OnThisDayPanel extends ConsumerWidget {
  const OnThisDayPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dives = ref.watch(onThisDayProvider).value ?? const <Dive>[];
    if (dives.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final dive = dives.first;
    final runtime = dive.measuredRuntime;
    final site = dive.site?.name ?? dive.name ?? '';
    final entry = l10n.dashboard_onThisDay_entry(
      '${dive.effectiveEntryTime.year}',
      site,
    );
    return HomePanel(
      title: l10n.dashboard_onThisDay_title,
      trailing: '${dive.effectiveEntryTime.year}',
      semanticsValue: entry,
      onTap: () => context.push('/dives/${dive.id}'),
      fit: HomePanelFit.clip,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            site,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            [
              units.formatDepth(dive.maxDepth),
              if (runtime != null) "${runtime.inMinutes}'",
            ].join(' · '),
            style: _muted(context),
          ),
          for (final other in dives.skip(1).take(2))
            _line(
              context,
              other.site?.name ?? other.name ?? '',
              '${other.effectiveEntryTime.year}',
              onTap: () => context.push('/dives/${other.id}'),
            ),
        ],
      ),
    );
  }
}

/// Courses in progress with how many requirements are met.
class ActiveCoursePanel extends ConsumerWidget {
  const ActiveCoursePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(activeCoursesProgressProvider).value ?? const [];
    if (courses.isEmpty) return const SizedBox.shrink();
    final first = courses.first;
    return HomePanel(
      title: context.l10n.dashboard_activeCourses_title,
      semanticsValue: first.course.name,
      onTap: () => context.push('/courses/${first.course.id}'),
      fit: HomePanelFit.clip,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in courses.take(2))
            InkWell(
              onTap: () => context.push('/courses/${c.course.id}'),
              child: HomeBarRow(
                label: c.course.name,
                value:
                    '${c.progress.satisfiedCount} / ${c.progress.totalCount}',
                fraction: c.progress.totalCount == 0
                    ? 0
                    : c.progress.satisfiedCount / c.progress.totalCount,
              ),
            ),
        ],
      ),
    );
  }
}

/// Drafts waiting for the dive computer, and the way to download them.
class WaitingForDownloadPanel extends ConsumerWidget {
  const WaitingForDownloadPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = draftsWaitingForDownload(
      ref.watch(draftDivesProvider).value ?? const [],
    );
    if (waiting.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final target = ref.watch(downloadTargetComputerProvider).value;
    final title = l10n.dashboard_waitingForDownload_title(waiting.length);
    return HomePanel(
      title: title,
      semanticsValue: title,
      onTap: () => context.push(downloadRouteFor(target)),
      fit: HomePanelFit.clip,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final dive in waiting.take(2))
            _line(
              context,
              dive.site?.name ?? l10n.diveLog_draft_title,
              units.formatDate(dive.effectiveEntryTime),
              onTap: () => context.push('/dives/${dive.id}'),
            ),
        ],
      ),
    );
  }
}

/// Whether the checklist panel has anything to show: a pre-dive run under
/// way, earlier runs or the diver's own templates, or a trip checklist.
/// The page uses the same rule to leave the panel out.
bool preDivePanelHasContent(WidgetRef ref) {
  final active = ref.watch(preDiveActiveSessionProvider).value;
  final sessions = ref.watch(preDiveSessionsProvider).value ?? const [];
  final templates = ref.watch(preDiveTemplatesProvider).value ?? const [];
  final trip = ref.watch(homeTripChecklistProvider).value;
  return active != null ||
      sessions.isNotEmpty ||
      templates.any((t) => !t.isBuiltIn) ||
      trip != null;
}

/// The pre-dive checklist (resume the run under way, or start one) and the
/// next trip's checklist progress.
class PreDivePanel extends ConsumerWidget {
  const PreDivePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!preDivePanelHasContent(ref)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final active = ref.watch(preDiveActiveSessionProvider).value;
    final trip = ref.watch(homeTripChecklistProvider).value;
    final sessions = ref.watch(preDiveSessionsProvider).value ?? const [];
    final templates = ref.watch(preDiveTemplatesProvider).value ?? const [];
    final showPreDive =
        active != null ||
        sessions.isNotEmpty ||
        templates.any((t) => !t.isBuiltIn);
    final items = active == null
        ? null
        : ref.watch(preDiveSessionItemsProvider(active.id)).value;
    final resolved = items == null
        ? 0
        : ChecklistSessionEngine.resolvedCount(items);
    final preDiveText = active != null
        ? l10n.preDive_dashboard_resume(resolved, items?.length ?? 0)
        : l10n.preDive_dashboard_start;
    return HomePanel(
      title: l10n.dashboard_checklists_title,
      semanticsValue: showPreDive ? preDiveText : '',
      onTap: () => context.push(
        active != null
            ? '/pre-dive-sessions/${active.id}'
            : showPreDive
            ? '/pre-dive-sessions'
            : '/trips/${trip!.trip.id}',
      ),
      fit: HomePanelFit.clip,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPreDive)
            _line(
              context,
              l10n.dashboard_checklists_preDiveLabel,
              preDiveText,
              onTap: () => context.push(
                active != null
                    ? '/pre-dive-sessions/${active.id}'
                    : '/pre-dive-sessions',
              ),
            ),
          if (trip != null)
            InkWell(
              onTap: () => context.push('/trips/${trip.trip.id}'),
              child: HomeBarRow(
                label: l10n.dashboard_checklists_tripLabel(trip.trip.name),
                value: '${trip.done} / ${trip.total}',
                fraction: trip.total == 0 ? 0 : trip.done / trip.total,
              ),
            ),
        ],
      ),
    );
  }
}

/// The newest photos and videos as a grid that fills the panel. A tile
/// opens the viewer on that item.
class PhotosPanel extends ConsumerWidget {
  const PhotosPanel({super.key});

  static const double _tile = 72;
  static const double _gap = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(recentMediaProvider).value ?? const <MediaItem>[];
    if (media.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return HomePanel(
      title: l10n.dashboard_media_title,
      semanticsValue: '${media.length}',
      onTap: () => context.push('/media'),
      child: LayoutBuilder(
        builder: (context, box) {
          final cols = math.max(1, (box.maxWidth + _gap) ~/ (_tile + _gap));
          final rows = math.max(1, (box.maxHeight + _gap) ~/ (_tile + _gap));
          final shown = media.take(cols * rows).toList();
          final w = (box.maxWidth - _gap * (cols - 1)) / cols;
          final h = (box.maxHeight - _gap * (rows - 1)) / rows;
          return Wrap(
            spacing: _gap,
            runSpacing: _gap,
            children: [
              for (final item in shown)
                SizedBox(
                  width: w,
                  height: h,
                  child: _MediaTile(
                    item: item,
                    target: Size.square(math.max(w, h) * dpr),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final MediaItem item;
  final Size target;

  const _MediaTile({required this.item, required this.target});

  @override
  Widget build(BuildContext context) {
    final diveId = item.diveId;
    return InkWell(
      onTap: diveId == null
          ? null
          : () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) =>
                    PhotoViewerPage(diveId: diveId, initialMediaId: item.id),
              ),
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MediaItemView(item: item, thumbnail: true, targetSize: target),
            if (item.isVideo)
              const Positioned(
                right: 3,
                bottom: 3,
                child: Icon(Icons.play_circle, size: 16, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}

/// Key of the placeholder shown until the map's row first paints.
const Key recentSitesPanelPlaceholderKey = Key(
  'recent-sites-panel-placeholder',
);

/// The recent dive sites on a map that fills the panel. The map mounts on
/// its row's first paint, and is keyed by its pins so new pins reframe it.
class RecentSitesPanel extends ConsumerWidget {
  const RecentSitesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pins = ref.watch(recentSitesProvider).value ?? const [];
    if (pins.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final background = scheme.surfaceContainerHighest;
    final points = [for (final p in pins) LatLng(p.latitude, p.longitude)];
    final fit = points.length >= 2
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(28),
            maxZoom: 12,
          )
        : null;
    return HomePanel(
      title: context.l10n.dashboard_recentSites_title,
      semanticsValue: [
        for (final p in pins)
          if (p.siteName?.isNotEmpty ?? false) p.siteName!,
      ].join(', '),
      onTap: () => context.push('/sites'),
      padding: EdgeInsets.zero,
      child: DeferUntilPainted(
        placeholder: ColoredBox(
          key: recentSitesPanelPlaceholderKey,
          color: background,
          child: const SizedBox.expand(),
        ),
        // Not behind an IgnorePointer: the attribution starts folded into
        // an info button, which has to stay tappable for the tile sources'
        // credit to be readable. A tap anywhere else on the locked map opens
        // the sites, as the rest of the panel does.
        child: LockedMapScrollPassthrough(
          child: FlutterMap(
            key: ValueKey(Object.hashAllUnordered(points)),
            options: MapOptions(
              initialCenter: points.first,
              initialZoom: 11,
              initialCameraFit: fit,
              backgroundColor: background,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
              onTap: (_, _) => context.push('/sites'),
            ),
            children: [
              submersionTileLayer(ref),
              MarkerLayer(
                markers: [
                  for (final p in pins)
                    Marker(
                      point: LatLng(p.latitude, p.longitude),
                      width: 14,
                      height: 14,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.error,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const MapAttribution(),
            ],
          ),
        ),
      ),
    );
  }
}
