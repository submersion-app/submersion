import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_sites/presentation/editing/unlock_site_editing_flag.dart';

/// Where the old site edit address (`/sites/<id>/edit`) goes (issue #4527,
/// phase 2): with [unlockEditing], the site page opened unlocked; null,
/// keeping the edit form, otherwise and for a library reader's suggestion
/// (`?suggest=1`), which has no sitting yet.
String? siteEditLocation(
  String siteId,
  Map<String, String> query, {
  bool unlockEditing = kUnlockSiteEditing,
}) {
  if (!unlockEditing || query['suggest'] == '1') return null;
  return '/sites/$siteId?mode=edit';
}

/// The edit route's redirect: [siteEditLocation] for its address.
String? siteEditRedirect(BuildContext context, GoRouterState state) =>
    siteEditLocation(
      state.pathParameters['siteId']!,
      state.uri.queryParameters,
    );
