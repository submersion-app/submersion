import 'package:equatable/equatable.dart';

/// Where tapping an observation goes.
sealed class ObservationTarget extends Equatable {
  const ObservationTarget();
}

/// An Insights category page, by its category id ('gas', 'progression').
final class InsightsCategoryTarget extends ObservationTarget {
  final String categoryId;
  const InsightsCategoryTarget(this.categoryId);
  @override
  List<Object?> get props => [categoryId];
}

final class DiveTarget extends ObservationTarget {
  final String diveId;
  const DiveTarget(this.diveId);
  @override
  List<Object?> get props => [diveId];
}

final class SiteTarget extends ObservationTarget {
  final String siteId;
  const SiteTarget(this.siteId);
  @override
  List<Object?> get props => [siteId];
}

final class BuddyTarget extends ObservationTarget {
  final String buddyId;
  const BuddyTarget(this.buddyId);
  @override
  List<Object?> get props => [buddyId];
}

final class DiveLogTarget extends ObservationTarget {
  const DiveLogTarget();
  @override
  List<Object?> get props => const [];
}
