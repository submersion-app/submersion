import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_sites/domain/models/new_site_seed.dart';
import 'package:submersion/features/dive_sites/presentation/editing/unlock_site_editing_flag.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';

/// Where the old site edit address (`/sites/<id>/edit`) goes (issue #4527,
/// phase 2): with [unlockEditing], the site page opened unlocked, whatever
/// its query: a library reader's suggestion (`?suggest=1`) too, since the
/// page unlocks as the role allows (plan 5); null, keeping the edit form,
/// otherwise.
String? siteEditLocation(
  String siteId, {
  bool unlockEditing = kUnlockSiteEditing,
}) {
  if (!unlockEditing) return null;
  return '/sites/$siteId?mode=edit';
}

/// The edit route's redirect: [siteEditLocation] for its address.
String? siteEditRedirect(BuildContext context, GoRouterState state) =>
    siteEditLocation(state.pathParameters['siteId']!);

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

/// The new-site address (`/sites/new`, `?duplicateOf=` for a duplicate),
/// with what the route was handed as [extra] (issue #4527, plan 6): with
/// [unlockEditing], the site page opened unlocked on a new site; the form,
/// as today, otherwise.
Widget newSitePage(
  Object? extra, {
  String? duplicateOfId,
  bool unlockEditing = kUnlockSiteEditing,
}) {
  if (!unlockEditing) {
    return SiteEditPage.fromNewSiteExtra(extra, duplicateOfId: duplicateOfId);
  }
  return SiteDetailPage.newSite(
    seed: NewSiteSeed.fromRouteExtra(extra),
    duplicateOfId: duplicateOfId,
  );
}

/// The site list's new-site pane (`?mode=new`), as the master-detail
/// scaffold's `createBuilder`: with [unlockEditing], the site page on a new
/// site, whose created id is handed to [onSaved], which selects it; the
/// form, as today, otherwise.
Widget newSitePane(
  BuildContext context,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  bool unlockEditing = kUnlockSiteEditing,
}) {
  if (!unlockEditing) {
    return SiteEditPage(embedded: true, onSaved: onSaved, onCancel: onCancel);
  }
  return SiteDetailPage.newSite(
    embedded: true,
    onCreated: onSaved,
    onCreateCancelled: onCancel,
  );
}

/// Opens a new site on its own page, from an opener that has no place of
/// its own to show it (the list's Add on a phone, its empty state, the
/// map): with [unlockEditing], the site opens, locked, once created (plan
/// 6, Question 1); as today, the opener is shown again, otherwise.
Future<void> openNewSite(
  BuildContext context, {
  Object? extra,
  bool unlockEditing = kUnlockSiteEditing,
}) async {
  final id = await context.push<String>('/sites/new', extra: extra);
  if (!unlockEditing || id == null || !context.mounted) return;
  await context.push('/sites/$id');
}
