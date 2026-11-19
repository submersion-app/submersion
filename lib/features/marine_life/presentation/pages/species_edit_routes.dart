import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

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
