import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/router/global_search_location.dart';
import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/core/router/track_locations.dart';
import 'package:submersion/core/router/training_locations.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_query_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_query_providers.dart';
import 'package:submersion/features/courses/domain/models/course_filter_state.dart';
import 'package:submersion/features/courses/presentation/providers/course_query_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_query_providers.dart';
import 'package:submersion/features/dive_log/presentation/navigation/open_dive_list.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/global_search/presentation/providers/global_search_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_query_providers.dart';
import 'package:submersion/features/trips/presentation/navigation/open_trip_list.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// The address of the page a result opens.
String globalSearchLocation(GlobalSearchKind kind, String id) => switch (kind) {
  GlobalSearchKind.dives => '/dives/$id',
  GlobalSearchKind.sites => '/sites/$id',
  GlobalSearchKind.trips => '/trips/$id',
  GlobalSearchKind.equipment => '/equipment/$id',
  GlobalSearchKind.equipmentSets => '/equipment/sets/$id',
  GlobalSearchKind.buddies => '/buddies/$id',
  GlobalSearchKind.diveCenters => '/dive-centers/$id',
  GlobalSearchKind.certifications => '/certifications/$id',
  GlobalSearchKind.courses => '/courses/$id',
  GlobalSearchKind.species => '/species/$id',
  GlobalSearchKind.documents => '/documents/$id',
  GlobalSearchKind.divePlans => '/planning/dive-planner/$id',
  GlobalSearchKind.gpsTracks => gpsTrackLocation(id),
  GlobalSearchKind.underwaterRoutes => underwaterTrackLocation(id),
};

/// Opens global search with [text] in its field, searched (#3882): from a
/// list's Search everything row. The page is reused when it is already
/// under the list, so Back from the results lands where it did before.
void openGlobalSearch(BuildContext context, WidgetRef ref, String text) {
  ref.read(globalSearchRequestProvider.notifier).state = GlobalSearchRequest(
    text,
  );
  context.pushOrReturnTo(kGlobalSearchLocation);
}

/// Opens [kind]'s list narrowed to [query], its other filters cleared so its
/// chips show exactly this search.
///
/// Dives and trips use their pushed lists, which put the previous filter
/// back on the way out (#3292, #3350). The others have no such list: their
/// chips stay up, and clear the search there. Back returns to the results
/// unless that list was already under them, in which case the app walks back
/// to it. The Training tabs replace the stack instead: see [_openTrainingTab].
///
/// Only called for a kind with a list; the rest expand in place.
void openGlobalSearchList(
  BuildContext context,
  WidgetRef ref,
  GlobalSearchKind kind,
  QueryNode query,
) {
  void open(String location) => context.pushOrReturnTo(location);
  switch (kind) {
    case GlobalSearchKind.dives:
      openDiveList(context, ref, DiveFilterState(query: query));
    case GlobalSearchKind.trips:
      openTripList(context, ref, TripFilterState(query: query));
    case GlobalSearchKind.sites:
      ref.read(siteFilterProvider.notifier).state = SiteFilterState(
        query: query,
      );
      open('/sites');
    case GlobalSearchKind.equipment:
      // Search finds retired and sold gear, which the list's default view
      // hides, so its count would otherwise disagree with the section's.
      ref.read(equipmentFilterProvider.notifier).state = EquipmentFilterState(
        allStatuses: true,
        query: query,
      );
      open('/equipment');
    case GlobalSearchKind.buddies:
      ref.read(buddyQueryProvider.notifier).state = query;
      open('/buddies');
    case GlobalSearchKind.diveCenters:
      ref.read(diveCenterQueryProvider.notifier).state = query;
      open('/dive-centers');
    case GlobalSearchKind.certifications:
      ref.read(certificationAttentionFilterProvider.notifier).state = false;
      ref.read(certificationQueryProvider.notifier).state = query;
      _openTrainingTab(context, TrainingTab.certifications);
    case GlobalSearchKind.courses:
      ref.read(courseFilterProvider.notifier).state = CourseFilterState(
        query: query,
      );
      _openTrainingTab(context, TrainingTab.courses);
    case GlobalSearchKind.species:
      ref.read(speciesCatalogQueryProvider.notifier).state = query;
      open('/species/manage');
    case GlobalSearchKind.equipmentSets:
    case GlobalSearchKind.documents:
    case GlobalSearchKind.divePlans:
    case GlobalSearchKind.gpsTracks:
    case GlobalSearchKind.underwaterRoutes:
      throw StateError('$kind has no list to open');
  }
}

/// Both Training tabs build one host under one constant page key (#3437), so
/// pushing one over the other would put that key on the stack twice.
void _openTrainingTab(BuildContext context, TrainingTab tab) =>
    context.go(tab.path);
