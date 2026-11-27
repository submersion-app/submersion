import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/marine_life/presentation/pages/species_detail_page.dart';
import 'package:submersion/shared/widgets/record_editing/open_new_record.dart';

/// Where the old species edit address (`/species/<id>/edit`) goes (issue
/// #4527, phase 3): the species page opened unlocked.
String speciesEditLocation(String speciesId) => '/species/$speciesId?mode=edit';

/// The edit route's redirect: [speciesEditLocation] for its address.
String? speciesEditRedirect(BuildContext context, GoRouterState state) =>
    speciesEditLocation(state.pathParameters['speciesId']!);

/// The new-species address (`/species/new`; issue #4527, phase 3, plan 11):
/// the species page opened unlocked on a new species.
Widget newSpeciesPage() => const SpeciesDetailPage.newSpecies();

/// Opens a new species from the manage page: the species opens, locked,
/// once created, as a new site does (plan 11, Question 3).
Future<void> openNewSpecies(BuildContext context) => openNewRecord(
  context,
  newLocation: '/species/new',
  recordLocation: (id) => '/species/$id',
);
