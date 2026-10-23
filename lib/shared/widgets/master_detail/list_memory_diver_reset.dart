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

/// Forgets every list's last-opened record and emptied pane when the active
/// diver changes (#3301).
///
/// Lists return to the record the diver last opened. Another diver's record
/// is usually just absent from the list, but a site or trip shared between
/// profiles is not, and would bring the previous diver's place back. The
/// first diver id, loaded as the app starts, forgets nothing.
class ListMemoryDiverReset extends ConsumerWidget {
  const ListMemoryDiverReset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous == null || previous == next) return;
      ref.read(highlightedDiveIdProvider.notifier).state = null;
      ref.read(highlightedSiteIdProvider.notifier).state = null;
      ref.read(highlightedEquipmentIdProvider.notifier).state = null;
      ref.read(highlightedBuddyIdProvider.notifier).state = null;
      ref.read(highlightedTripIdProvider.notifier).state = null;
      ref.read(highlightedDiveCenterIdProvider.notifier).state = null;
      ref.read(highlightedCertificationIdProvider.notifier).state = null;
      ref.read(highlightedCourseIdProvider.notifier).state = null;
      ref.read(closedPaneRecordProvider.notifier).state = const {};
    });
    return child;
  }
}
