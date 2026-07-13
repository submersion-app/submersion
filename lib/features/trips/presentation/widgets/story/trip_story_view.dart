import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/checklists/presentation/widgets/trip_checklist_section.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_hero.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_map_header.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_vessel_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const double _wideBreakpoint = 900;
const double _mapHeaderMaxExtent = 260;
const Duration _scrollThrottle = Duration(milliseconds: 100);

/// The assembled trip story: pinned map + hero + day chapters.
class TripStoryView extends ConsumerStatefulWidget {
  final TripStory story;
  final TripWithStats stats;
  final VoidCallback? onScanForDives;

  const TripStoryView({
    super.key,
    required this.story,
    required this.stats,
    this.onScanForDives,
  });

  @override
  ConsumerState<TripStoryView> createState() => _TripStoryViewState();
}

class _TripStoryViewState extends ConsumerState<TripStoryView>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late MapCameraAnimator _cameraAnimator;
  late List<GlobalKey> _dayKeys;
  int _activeDayIndex = 0;
  DateTime _lastResolve = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _cameraAnimator = MapCameraAnimator(
      vsync: this,
      controller: _mapController,
    );
    _buildKeys();
  }

  @override
  void didUpdateWidget(TripStoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.story.days.length != widget.story.days.length) _buildKeys();
  }

  void _buildKeys() {
    _dayKeys = List.generate(widget.story.days.length, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _cameraAnimator.dispose();
    super.dispose();
  }

  void _selectDay(int index, {bool animateMap = true}) {
    if (index == _activeDayIndex) return;
    setState(() => _activeDayIndex = index);
    if (!animateMap) return;
    final points = widget.story.mapGeometry.pointsForDay(index);
    if (points.isEmpty) return;
    _cameraAnimator.animateTo(
      center: LatLng(points.first.latitude, points.first.longitude),
      zoom: _mapController.camera.zoom,
    );
  }

  bool _onScroll(ScrollUpdateNotification notification) {
    final now = DateTime.now();
    if (now.difference(_lastResolve) < _scrollThrottle) return false;
    _lastResolve = now;

    final viewportHeight = notification.metrics.viewportDimension;
    final threshold = viewportHeight / 3;
    for (var i = _dayKeys.length - 1; i >= 0; i--) {
      final keyContext = _dayKeys[i].currentContext;
      if (keyContext == null) continue;
      final box = keyContext.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= threshold) {
        _selectDay(i);
        return false;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        if (!wide) {
          return NotificationListener<ScrollUpdateNotification>(
            onNotification: _onScroll,
            child: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _mapHeaderDelegate(),
                ),
                ..._contentSlivers(),
              ],
            ),
          );
        }
        return Row(
          key: const Key('trip-story-wide-layout'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 380,
              child: _mapHeaderDelegate().build(context, 0, false),
            ),
            Expanded(
              child: NotificationListener<ScrollUpdateNotification>(
                onNotification: _onScroll,
                child: CustomScrollView(slivers: _contentSlivers()),
              ),
            ),
          ],
        );
      },
    );
  }

  TripStoryMapHeaderDelegate _mapHeaderDelegate() {
    return TripStoryMapHeaderDelegate(
      geometry: widget.story.mapGeometry,
      stats: widget.stats,
      activeDayIndex: _activeDayIndex,
      mapController: _mapController,
      onDaySelected: (i) => _selectDay(i, animateMap: false),
      maxExtentValue: _mapHeaderMaxExtent,
    );
  }

  List<Widget> _contentSlivers() {
    final story = widget.story;
    final trip = story.trip;
    final todayIndex = story.todayIndex;
    final showChecklistAtEnd =
        !trip.isUpcoming && !trip.isLiveaboard && !story.checklist.isEmpty;

    return [
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverToBoxAdapter(
          child: TripStoryHero(
            story: story,
            onScanForDives: widget.onScanForDives,
          ),
        ),
      ),
      if (trip.isLiveaboard)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(child: TripVesselSection(tripId: trip.id)),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        sliver: SliverList.builder(
          itemCount: story.days.length,
          itemBuilder: (context, index) {
            final day = story.days[index];
            final showTodayDivider = todayIndex != null && index == todayIndex;
            return Column(
              key: _dayKeys[index],
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showTodayDivider) const _TodayDivider(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TripStoryDayCard(day: day, tripId: trip.id),
                ),
              ],
            );
          },
        ),
      ),
      if (trip.notes.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverToBoxAdapter(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.trips_detail_sectionTitle_notes,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(trip.notes),
                  ],
                ),
              ),
            ),
          ),
        ),
      if (showChecklistAtEnd)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverToBoxAdapter(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                title: Text(
                  context.l10n.trips_story_checklistProgress(
                    story.checklist.done,
                    story.checklist.total,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TripChecklistSection(trip: trip),
                  ),
                ],
              ),
            ),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }
}

class _TodayDivider extends StatelessWidget {
  const _TodayDivider();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: colorScheme.primary)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              context.l10n.trips_story_today,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Divider(color: colorScheme.primary)),
        ],
      ),
    );
  }
}
