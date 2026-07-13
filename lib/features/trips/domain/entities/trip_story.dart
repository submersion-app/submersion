import 'package:equatable/equatable.dart';

import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';

/// Done/total checklist progress plus the next few due items.
class TripStoryChecklistSummary extends Equatable {
  final int done;
  final int total;
  final List<TripChecklistItem> nextDue;

  const TripStoryChecklistSummary({
    required this.done,
    required this.total,
    this.nextDue = const [],
  });

  bool get isEmpty => total == 0;

  @override
  List<Object?> get props => [done, total, nextDue];
}

/// The complete composed story for one trip.
class TripStory extends Equatable {
  final Trip trip;
  final List<TripStoryDay> days;
  final TripStoryChecklistSummary checklist;
  final TripStoryMapGeometry mapGeometry;

  const TripStory({
    required this.trip,
    required this.days,
    required this.checklist,
    required this.mapGeometry,
  });

  /// Index of the day whose kind is [TripStoryDayKind.today], if any.
  int? get todayIndex {
    final index = days.indexWhere((d) => d.kind == TripStoryDayKind.today);
    return index == -1 ? null : index;
  }

  /// True when there is nothing to tell: no dives and no itinerary anywhere.
  bool get isEmpty =>
      days.every((d) => d.dives.isEmpty && d.itineraryDay == null);

  @override
  List<Object?> get props => [trip, days, checklist, mapGeometry];
}
