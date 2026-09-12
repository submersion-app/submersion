import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_parse_error_text.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_import_review_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_import_flow_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_shape_thumbnail.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The dive detail "Underwater Route" section (spec
/// 2026-09-10-underwater-nav-track-design.md, "Dive detail section"):
/// linked routes, a way to link one, and a way to import a file straight to
/// this dive.
class NavTrackSection extends ConsumerWidget {
  const NavTrackSection({super.key, required this.dive});

  final Dive dive;

  Future<void> _linkRoute(BuildContext context, WidgetRef ref) async {
    final unlinked = await ref.read(unlinkedNavTracksProvider.future);
    final sorted = [...unlinked]
      ..sort(
        (a, b) => (a.startTime - dive.effectiveEntryTime.millisecondsSinceEpoch)
            .abs()
            .compareTo(
              (b.startTime - dive.effectiveEntryTime.millisecondsSinceEpoch)
                  .abs(),
            ),
      );
    if (!context.mounted) return;
    final chosen = await showModalBottomSheet<NavTrack>(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final route in sorted)
            ListTile(
              title: Text(route.name ?? route.sourceRef ?? route.id),
              onTap: () => Navigator.of(context).pop(route),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    await ref
        .read(navTrackRepositoryProvider)
        .link(chosen.id, dive.id, linkMode: NavTrackLinkMode.manual);
  }

  Future<void> _importFile(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    final log = LoggerService.forClass(NavTrackSection);

    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();

    final NavTrackImportPreview preview;
    try {
      preview = await ref
          .read(navTrackImportServiceProvider)
          .prepare(bytes, fileName: file.name);
    } on NavTrackParseException catch (e) {
      log.warning('Route import rejected: ${e.message}');
      messenger.showSnackBar(
        SnackBar(content: Text(navTrackParseErrorText(l10n, e))),
      );
      return;
    } catch (e, stackTrace) {
      log.error('Route import failed', error: e, stackTrace: stackTrace);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.navTrack_list_importFailed(e.toString()))),
      );
      return;
    }

    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => NavTrackImportReviewPage(
          bytes: bytes,
          fileName: file.name,
          preview: preview,
          preselectedDiveId: dive.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(navTracksForDiveProvider(dive.id));
    final unlinkedAsync = ref.watch(unlinkedNavTracksProvider);
    final routes = routesAsync.value ?? const <NavTrack>[];
    final isExpanded = ref.watch(navTrackSectionExpandedProvider);
    final l10n = context.l10n;

    final subtitle = routes.isEmpty
        ? l10n.navTrack_section_noRouteLinked
        : l10n.navTrack_section_routeCount(routes.length);

    return CollapsibleCardSection(
      title: l10n.navTrack_section_title,
      icon: Icons.route,
      collapsedSubtitle: subtitle,
      isExpanded: isExpanded,
      onToggle: (expanded) =>
          ref.read(navTrackSectionExpandedProvider.notifier).state = expanded,
      contentBuilder: (context) {
        if (!isExpanded) return const SizedBox.shrink();
        if (routes.isEmpty) {
          final hasUnlinked = (unlinkedAsync.value ?? const []).isNotEmpty;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Text(l10n.navTrack_section_noRouteLinked),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (hasUnlinked)
                      OutlinedButton(
                        key: const ValueKey('nav-track-link-button'),
                        onPressed: () => _linkRoute(context, ref),
                        child: Text(l10n.navTrack_section_linkButton),
                      ),
                    OutlinedButton(
                      key: const ValueKey('nav-track-import-button'),
                      onPressed: () => _importFile(context, ref),
                      child: Text(l10n.navTrack_section_importButton),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
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
