import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/marine_life/presentation/pages/species_detail_page.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_edit_page.dart';
import 'package:submersion/shared/widgets/record_editing/open_new_record.dart';
import 'package:submersion/shared/widgets/record_editing/unlock_record_editing_flag.dart';

/// Where the old species edit address (`/species/<id>/edit`) goes (issue
/// #4527, phase 3): with [unlockEditing], the species page opened unlocked;
/// null, keeping the edit form, otherwise.
String? speciesEditLocation(
  String speciesId, {
  bool unlockEditing = kUnlockRecordEditing,
}) => unlockEditing ? '/species/$speciesId?mode=edit' : null;

/// The edit route's redirect: [speciesEditLocation] for its address.
String? speciesEditRedirect(BuildContext context, GoRouterState state) =>
    speciesEditLocation(state.pathParameters['speciesId']!);

/// The new-species address (`/species/new`; issue #4527, phase 3, plan 11):
/// with [unlockEditing], the species page opened unlocked on a new species;
/// else the form, as before.
Widget newSpeciesPage({bool unlockEditing = kUnlockRecordEditing}) =>
    unlockEditing
    ? const SpeciesDetailPage.newSpecies()
    : const SpeciesEditPage();

/// Opens a new species from the manage page: with [unlockEditing], the
/// species opens, locked, once created, as a new site does (plan 11,
/// Question 3); else the form, as before.
Future<void> openNewSpecies(
  BuildContext context, {
  bool unlockEditing = kUnlockRecordEditing,
}) {
  if (!unlockEditing) return context.push('/species/new');
  return openNewRecord(
    context,
    newLocation: '/species/new',
    recordLocation: (id) => '/species/$id',
  );
}
