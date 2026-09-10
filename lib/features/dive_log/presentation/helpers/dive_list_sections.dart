import 'dart:math' as math;

import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';

/// One dive in the list, paired with its position in the flat, ungrouped list.
///
/// The flat index is load-bearing: the detailed card falls back to
/// `diveNumber ?? flatIndex + 1` for its leading badge, and the detail page's
/// prev/next walks flat list order. A position within a section would be wrong
/// for both.
class DiveListEntry {
  const DiveListEntry({required this.dive, required this.flatIndex});

  final DiveSummary dive;
  final int flatIndex;
}

/// A run of rows in the dive list: either loose dives or one trip's dives.
sealed class DiveListSection {
  const DiveListSection();

  List<DiveListEntry> get entries;
}

/// Consecutive dives that belong to no trip.
class LooseSection extends DiveListSection {
  const LooseSection(this.entries);

  @override
  final List<DiveListEntry> entries;
}

/// Consecutive dives that belong to the same trip.
///
/// Sections are runs, not sets. A trip interrupted by a loose dive produces
/// two sections for the same trip, both labelled with the trip's real total,
/// so it reads as "this trip, continued". Gathering a trip's dives out of date
/// order would break the chronological sort the list is built on.
class TripSection extends DiveListSection {
  const TripSection({
    required this.tripId,
    required this.tripName,
    required this.startDate,
    required this.endDate,
    required this.entries,
    required this.collapsed,
    required this.totalCount,
  });

  final String tripId;
  final String tripName;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  final List<DiveListEntry> entries;

  final bool collapsed;

  /// Every dive on this trip, filter and pagination independent.
  final int totalCount;

  /// Dives from this trip currently in the list.
  int get loadedCount => entries.length;

  /// True when the list holds fewer of this trip than the trip really has, so
  /// the header reads "6 of 14" rather than a bare count.
  bool get isPartial => loadedCount < totalCount;
}

/// Splits [dives] into loose runs and trip runs for rendering.
///
/// [dives] must already be in list order; this never reorders anything.
///
/// [tripTotals] carries every trip's real dive count, so a trip cut by a page
/// boundary or trimmed by a filter can say how much of itself is missing.
/// [forceExpandedTripId] keeps one trip open regardless of [collapsedTripIds],
/// so the list never folds away the dive the diver is looking at.
List<DiveListSection> buildDiveListSections({
  required List<DiveSummary> dives,
  required bool groupingEnabled,
  required Set<String> collapsedTripIds,
  required Map<String, int> tripTotals,
  String? forceExpandedTripId,
}) {
  final entries = [
    for (var i = 0; i < dives.length; i++)
      DiveListEntry(dive: dives[i], flatIndex: i),
  ];

  if (entries.isEmpty) return const [];
  if (!groupingEnabled) return [LooseSection(entries)];

  final sections = <DiveListSection>[];
  var index = 0;

  while (index < entries.length) {
    final tripId = entries[index].dive.tripId;

    if (tripId == null) {
      final run = <DiveListEntry>[];
      while (index < entries.length && entries[index].dive.tripId == null) {
        run.add(entries[index]);
        index++;
      }
      sections.add(LooseSection(run));
      continue;
    }

    final run = <DiveListEntry>[];
    while (index < entries.length && entries[index].dive.tripId == tripId) {
      run.add(entries[index]);
      index++;
    }
    // Trip identity from the first entry that carries it, not simply the
    // first entry. An optimistic summary built from a Dive that has tripId
    // but no hydrated trip (the updateDive and addDive paths) knows its trip
    // id and nothing else, and heading a run with one blanked the whole
    // header until the next database read.
    final named = run
        .map((e) => e.dive)
        .firstWhere((d) => d.tripName != null, orElse: () => run.first.dive);
    sections.add(
      TripSection(
        tripId: tripId,
        tripName: named.tripName ?? '',
        startDate: named.tripStartDate,
        endDate: named.tripEndDate,
        entries: run,
        collapsed:
            collapsedTripIds.contains(tripId) && tripId != forceExpandedTripId,
        // Never below what is on screen. An unknown total means the counts
        // query has not resolved; a total below the loaded count means it has
        // gone stale behind an optimistic insert. Either way the header must
        // not claim fewer dives than it is showing.
        totalCount: math.max(tripTotals[tripId] ?? 0, run.length),
      ),
    );
  }

  return sections;
}

/// The dives a diver can actually see, in order.
///
/// Dives inside a collapsed trip are excluded, so a shift-range does not sweep
/// up rows that are folded away, and prev/next skips them too.
List<DiveSummary> visibleDivesOf(List<DiveListSection> sections) {
  return [
    for (final section in sections)
      if (section is! TripSection || !section.collapsed)
        for (final entry in section.entries) entry.dive,
  ];
}

/// Whether a scroll to [targetId] should be retried after forcing its trip
/// open.
///
/// A programmatic scroll measures the layout of the build it runs after. If
/// the target is loaded but folded inside a collapsed trip in that build, the
/// measurement finds nothing to scroll to. The list can force the trip open on
/// the next build and try once more, so the answer here is "is that worth
/// doing", kept pure so the awkward cases are testable without a widget tree.
///
/// False when the dive is already visible (nothing to fix), when it is not
/// loaded at all (opening a trip will not conjure it), when it belongs to no
/// trip (there is nothing to open, so a retry would repeat the same failure),
/// and when a retry has already been spent on it.
bool shouldRetryScrollAfterExpanding({
  required String targetId,
  required List<DiveSummary> loadedDives,
  required List<DiveSummary> visibleDives,
  required String? alreadyRetriedFor,
}) {
  if (alreadyRetriedFor == targetId) return false;
  if (visibleDives.any((d) => d.id == targetId)) return false;
  return loadedDives.any((d) => d.id == targetId && d.tripId != null);
}
