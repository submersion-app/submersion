import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_sites/presentation/editing/unlock_site_editing_flag.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';

/// Where the old site edit address (`/sites/<id>/edit`) goes (issue #4527,
/// phase 2): with [unlockEditing], the site page opened unlocked, a library
/// reader's suggestion (`?suggest=1`) too, since the page unlocks as the
/// role allows (plan 5); null, keeping the edit form, otherwise.
String? siteEditLocation(
  String siteId,
  Map<String, String> query, {
  bool unlockEditing = kUnlockSiteEditing,
}) {
  if (!unlockEditing) return null;
  return '/sites/$siteId?mode=edit';
}

/// The edit route's redirect: [siteEditLocation] for its address.
String? siteEditRedirect(BuildContext context, GoRouterState state) =>
    siteEditLocation(
      state.pathParameters['siteId']!,
      state.uri.queryParameters,
    );

/// The site list pane's edit mode (`&mode=edit`) with the switch on: the
/// site page opened unlocked, back to the site in view mode ([onCancel])
/// once its sitting ends, as `unlockedDivePane` is for a dive.
Widget unlockedSitePane(
  BuildContext context,
  String id,
  VoidCallback onCancel, {
  VoidCallback? onDeleted,
  bool unlockEditing = kUnlockSiteEditing,
}) => SiteDetailPage(
  siteId: id,
  embedded: true,
  unlockEditing: unlockEditing,
  openUnlocked: true,
  onSittingEnded: onCancel,
  onDeleted: onDeleted,
);

/// The site list's edit pane, as the master-detail scaffold's
/// `editBuilder`: [unlockedSitePane] with [unlockEditing], else the edit
/// form as before.
Widget siteEditPane(
  BuildContext context,
  String id,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  VoidCallback? onDeleted,
  bool unlockEditing = kUnlockSiteEditing,
}) {
  if (unlockEditing) {
    return unlockedSitePane(
      context,
      id,
      onCancel,
      onDeleted: onDeleted,
      unlockEditing: unlockEditing,
    );
  }
  return SiteEditPage(
    siteId: id,
    embedded: true,
    onSaved: onSaved,
    onCancel: onCancel,
    onDeleted: onDeleted,
  );
}

/// The dive list pane's site in edit mode (`&site=<id>&mode=edit`): with
/// [unlockEditing], the site page opened unlocked, whose sitting's end
/// returns the site to view mode ([onCancel]) and whose back arrow, on the
/// locked row only (the open sitting's header covers it), returns to the
/// dive ([onClose]); else the edit form as before.
Widget siteInDivesPane(
  BuildContext context,
  String siteId, {
  required void Function(String savedId) onSaved,
  required VoidCallback onCancel,
  required VoidCallback onClose,
  required VoidCallback onDeleted,
  bool unlockEditing = kUnlockSiteEditing,
}) {
  if (unlockEditing) {
    return SiteDetailPage(
      siteId: siteId,
      embedded: true,
      unlockEditing: unlockEditing,
      openUnlocked: true,
      onClose: onClose,
      onSittingEnded: onCancel,
      onDeleted: onDeleted,
    );
  }
  return SiteEditPage(
    siteId: siteId,
    embedded: true,
    onSaved: onSaved,
    onCancel: onCancel,
    onDeleted: onDeleted,
  );
}
