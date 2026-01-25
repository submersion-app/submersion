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
  duration('Duration', Icons.timer),
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
  diveCount('Dive Count', Icons.scuba_diving);

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

/// Sort fields for Equipment
enum EquipmentSortField {
  name('Name', Icons.sort_by_alpha),
  type('Type', Icons.category),
  purchaseDate('Purchase Date', Icons.shopping_bag),
  lastServiceDate('Last Service', Icons.build);

  final String displayName;
  final IconData icon;
  const EquipmentSortField(this.displayName, this.icon);
}

/// Sort fields for Buddies
enum BuddySortField {
  name('Name', Icons.sort_by_alpha),
  diveCount('Dive Count', Icons.scuba_diving);

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
