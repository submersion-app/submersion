import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_day_map.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Pushes the day's map fullscreen, the way the dive site page does.
void showTripDayMapPage(
  BuildContext context, {
  required TripStoryDay day,
  required List<TripStoryMapPoint> points,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TripDayMapPage(day: day, points: points),
    ),
  );
}

/// One story day's map on its own page (#2845). Tapping a dive pin docks
/// that dive's row at the bottom; tapping the row opens the dive; tapping the
/// pin again or the map undocks it.
class TripDayMapPage extends ConsumerStatefulWidget {
  final TripStoryDay day;
  final List<TripStoryMapPoint> points;

  const TripDayMapPage({super.key, required this.day, required this.points});

  @override
  ConsumerState<TripDayMapPage> createState() => _TripDayMapPageState();
}

class _TripDayMapPageState extends ConsumerState<TripDayMapPage> {
  String? _dockedDiveId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final day = widget.day;
    final docked = _dockedDiveId == null
        ? null
        : day.dives.firstWhereOrNull((d) => d.id == _dockedDiveId);
    final dockedIndex = docked == null ? -1 : day.dives.indexOf(docked);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${l10n.trips_story_dayLabel(day.dayNumber)} · '
          '${units.formatMonthDay(day.date)}',
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: TripDayMap(
              day: day,
              points: widget.points,
              highlightedDiveId: _dockedDiveId,
              onDiveTap: (id) => setState(() => _dockedDiveId = id),
              onMapTap: () => setState(() => _dockedDiveId = null),
            ),
          ),
          if (docked != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: DiveListItem(
                      summary: DiveSummary.fromDive(docked),
                      diveTypeLabelResolver: watchDiveTypeLabelResolver(
                        ref,
                        l10n,
                      ),
                      diveTypeShortLabelResolver:
                          watchDiveTypeShortLabelResolver(ref, l10n),
                      diveTypeListVisibilityPredicate:
                          watchDiveTypeListVisibilityPredicate(ref),
                      fullDive: docked,
                      diveNumber: docked.diveNumber ?? dockedIndex + 1,
                      isHighlighted: true,
                      onTap: () => context.push('/dives/${docked.id}'),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
