import 'package:flutter/material.dart';

/// Sort direction for list ordering
enum SortDirection {
  ascending('Ascending', Icons.arrow_upward),
  descending('Descending', Icons.arrow_downward);

  final String displayName;
  final IconData icon;
  const SortDirection(this.displayName, this.icon);

  /// Get the opposite direction
  SortDirection get opposite => this == ascending ? descending : ascending;
}

/// Sort fields for Dives
enum DiveSortField {
  date('Date', Icons.calendar_today),
  site('Site', Icons.place),
  depth('Max Depth', Icons.vertical_align_bottom),
  bottomTime('Bottom Time', Icons.timer),
  rating('Rating', Icons.star),
  diveNumber('Dive Number', Icons.tag);

  final String displayName;
  final IconData icon;
  const DiveSortField(this.displayName, this.icon);
}

/// Sort fields for Sites
enum SiteSortField {
  name('Name', Icons.sort_by_alpha),
  rating('Rating', Icons.star),
  difficulty('Difficulty', Icons.trending_up),
  depth('Max Depth', Icons.vertical_align_bottom),
  diveCount('Dive Count', Icons.scuba_diving),
  lastDived('Last Dived', Icons.history);

  final String displayName;
  final IconData icon;
  const SiteSortField(this.displayName, this.icon);
}

/// Sort fields for Trips
enum TripSortField {
  startDate('Start Date', Icons.flight_takeoff),
  endDate('End Date', Icons.flight_land),
  name('Name', Icons.sort_by_alpha);

  final String displayName;
  final IconData icon;
  const TripSortField(this.displayName, this.icon);
}

/// Sort fields for the Equipment page.
///
/// No `type` field: ordering by type is the separate primary axis of the
/// shared `EquipmentArrangement` ("Order types by" in the sort sheet), which
/// the page honours like every other gear surface.
enum EquipmentSortField {
  name('Name', Icons.sort_by_alpha),
  purchaseDate('Purchase Date', Icons.shopping_bag),
  lastServiceDate('Last Service', Icons.build),
  serviceDue('Service Due', Icons.av_timer);

  final String displayName;
  final IconData icon;
  const EquipmentSortField(this.displayName, this.icon);
}

/// Sort fields for the items inside a gear list on a dive.
///
/// Distinct from [EquipmentSortField], which serves the Equipment page and
/// carries a `serviceDue` field needing an urgency map the dive surfaces do
/// not load. Type is absent here because ordering by type is the separate
/// primary axis of an `EquipmentArrangement`.
enum EquipmentItemSortField {
  name('Name', Icons.sort_by_alpha),
  purchaseDate('Purchase Date', Icons.shopping_bag),
  dateAdded('Date Added', Icons.playlist_add),
  lastServiceDate('Last Service', Icons.build);

  final String displayName;
  final IconData icon;
  const EquipmentItemSortField(this.displayName, this.icon);
}

/// Sort fields for Buddies
enum BuddySortField {
  name('Name', Icons.sort_by_alpha),
  diveCount('Dive Count', Icons.scuba_diving),
  lastDive('Last Dive', Icons.history);

  final String displayName;
  final IconData icon;
  const BuddySortField(this.displayName, this.icon);
}

/// Sort fields for Dive Centers
enum DiveCenterSortField {
  name('Name', Icons.sort_by_alpha),
  diveCount('Dive Count', Icons.scuba_diving);

  final String displayName;
  final IconData icon;
  const DiveCenterSortField(this.displayName, this.icon);
}

/// Sort fields for Certifications
enum CertificationSortField {
  name('Name', Icons.sort_by_alpha),
  dateIssued('Date Issued', Icons.calendar_today),
  agency('Agency', Icons.business);

  final String displayName;
  final IconData icon;
  const CertificationSortField(this.displayName, this.icon);
}

/// Sort fields for Courses
enum CourseSortField {
  name('Name', Icons.sort_by_alpha),
  startDate('Start Date', Icons.calendar_today),
  agency('Agency', Icons.business),
  status('Status', Icons.check_circle_outline);

  final String displayName;
  final IconData icon;
  const CourseSortField(this.displayName, this.icon);
}

/// Sort fields for library media. `dateTaken` is the historical default and
/// resolves to COALESCE(taken_at, created_at) in the repository.
enum MediaSortField {
  dateTaken('Date Taken', Icons.calendar_today),
  fileName('File Name', Icons.sort_by_alpha),
  fileSize('File Size', Icons.data_usage);

  final String displayName;
  final IconData icon;
  const MediaSortField(this.displayName, this.icon);
}
