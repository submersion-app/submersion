import 'package:equatable/equatable.dart';

/// One bar of the exposure card's usage chart: the dives and hours an item
/// saw in one calendar month or year.
class UsageBucket extends Equatable {
  /// The first day of the month or year, as a wall-clock-UTC date like the
  /// dive dates it counts.
  final DateTime start;
  final int dives;

  /// Hours as the item's classifier counts them, so a rebreather's bars
  /// carry loop time only, matching its Hours total and service clocks.
  final double hours;

  const UsageBucket({
    required this.start,
    required this.dives,
    required this.hours,
  });

  UsageBucket copyWith({DateTime? start, int? dives, double? hours}) =>
      UsageBucket(
        start: start ?? this.start,
        dives: dives ?? this.dives,
        hours: hours ?? this.hours,
      );

  @override
  List<Object?> get props => [start, dives, hours];
}

/// How long ago an item was last dived, in the coarsest unit that still
/// reads naturally: today, then days, months and years.
enum LastDivedUnit { today, days, months, years }

typedef LastDivedAgo = ({LastDivedUnit unit, int count});

/// When and how often an item was dived, derived on read from its exposure
/// samples (issue #5074). Never stored.
class EquipmentUsageHistory extends Equatable {
  /// Twelve months, oldest first, ending with the current month. Empty only
  /// for an item with no dives.
  final List<UsageBucket> monthly;

  /// One bucket per calendar year from the first dive's year to the current
  /// year, oldest first, empty years included.
  final List<UsageBucket> yearly;

  /// The dives in [monthly], so the caption and the bars never disagree.
  final int divesLast12Months;
  final DateTime? lastDive;
  final LastDivedAgo? lastDivedAgo;

  const EquipmentUsageHistory({
    required this.monthly,
    required this.yearly,
    required this.divesLast12Months,
    this.lastDive,
    this.lastDivedAgo,
  });

  static const empty = EquipmentUsageHistory(
    monthly: [],
    yearly: [],
    divesLast12Months: 0,
  );

  bool get isEmpty => lastDive == null;

  EquipmentUsageHistory copyWith({
    List<UsageBucket>? monthly,
    List<UsageBucket>? yearly,
    int? divesLast12Months,
    DateTime? lastDive,
    LastDivedAgo? lastDivedAgo,
  }) => EquipmentUsageHistory(
    monthly: monthly ?? this.monthly,
    yearly: yearly ?? this.yearly,
    divesLast12Months: divesLast12Months ?? this.divesLast12Months,
    lastDive: lastDive ?? this.lastDive,
    lastDivedAgo: lastDivedAgo ?? this.lastDivedAgo,
  );

  @override
  List<Object?> get props => [
    monthly,
    yearly,
    divesLast12Months,
    lastDive,
    lastDivedAgo,
  ];
}
