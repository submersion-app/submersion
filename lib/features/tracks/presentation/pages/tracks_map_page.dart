import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/track_locations.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_date_filter_action.dart';
import 'package:submersion/features/tracks/presentation/track_item_location.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_list_pane.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_map_pane.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_overview_map.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_list_scaffold.dart';

/// Every mappable track on one map. At desktop width the Tracks page hosts
/// this same map itself; this page stays for phones, where the landing page
/// is one column, and for deep links.
class TracksMapPage extends ConsumerStatefulWidget {
  const TracksMapPage({super.key});

  @override
  ConsumerState<TracksMapPage> createState() => _TracksMapPageState();
}

class _TracksMapPageState extends ConsumerState<TracksMapPage> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final section = mapListSelectionProvider(kTracksSectionKey);
    final selection = ref.watch(section);
    return MapListScaffold(
      sectionKey: kTracksSectionKey,
      title: context.l10n.gpsTrack_map_title,
      onBackPressed: () => context.go(kTracksLocation),
      actions: const [GpsTrackDateFilterAction()],
      listPane: TracksListPane(
        selectedKey: selection.selectedId,
        showControls: false,
        onTap: (item) => ref.read(section.notifier).select(item.selectionKey),
      ),
      mapPane: TracksMapPane(controller: _mapController),
      infoCard: TracksInfoCard(
        onOpen: (item) => context.push(trackLocationOf(item)),
      ),
    );
  }
}
