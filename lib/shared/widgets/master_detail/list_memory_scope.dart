import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/shared/widgets/master_detail/remembered_selection.dart';

/// Keeps the record lists' memory straight for as long as the app shell
/// lives (#3301).
///
/// Lists return to the record the diver last opened, which each list keeps
/// in its own highlight provider, and remember a details pane the diver
/// emptied (see [closedPaneRecordProvider]).
///
/// - Opening a record, by any of the many ways a highlight moves (a row, the
///   keyboard, the detail page's previous and next, the table, the map),
///   means that list's pane is no longer one the diver emptied, so its
///   closed entry goes. One listener per list does this, rather than every
///   place that sets a highlight.
/// - Switching diver forgets every list's place and emptied pane. Another
///   diver's record is usually just absent from the list, but a site or trip
///   shared between profiles is not, and would bring the previous diver's
///   place back. The first diver id, loaded as the app starts, forgets
///   nothing.
class ListMemoryScope extends ConsumerWidget {
  const ListMemoryScope({super.key, required this.child});

  final Widget child;

  /// Each list's highlight and the section its details pane is keyed by.
  static final _sections = <(StateProvider<String?>, String)>[
    (highlightedDiveIdProvider, RecordListSection.dives),
    (highlightedSiteIdProvider, RecordListSection.sites),
    (highlightedEquipmentIdProvider, RecordListSection.equipment),
    (highlightedBuddyIdProvider, RecordListSection.buddies),
    (highlightedTripIdProvider, RecordListSection.trips),
    (highlightedDiveCenterIdProvider, RecordListSection.diveCenters),
    (highlightedCertificationIdProvider, RecordListSection.certifications),
    (highlightedCourseIdProvider, RecordListSection.courses),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    for (final (highlight, section) in _sections) {
      ref.listen<String?>(highlight, (previous, next) {
        if (next != null && next != previous) forgetClosedPane(ref, section);
      });
    }
    ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous == null || previous == next) return;
      for (final (highlight, _) in _sections) {
        ref.read(highlight.notifier).state = null;
      }
      ref.read(closedPaneRecordProvider.notifier).state = const {};
    });
    return child;
  }
}
