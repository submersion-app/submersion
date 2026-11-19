import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_sites/domain/models/new_site_seed.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';

/// Where the old site edit address (`/sites/<id>/edit`) goes (issue #4527,
/// phase 2): the site page opened unlocked, whatever its query: a library
/// reader's suggestion (`?suggest=1`) too, since the page unlocks as the
/// role allows (plan 5).
String siteEditLocation(String siteId) => '/sites/$siteId?mode=edit';

/// The edit route's redirect: [siteEditLocation] for its address.
String? siteEditRedirect(BuildContext context, GoRouterState state) =>
    siteEditLocation(state.pathParameters['siteId']!);

/// The site list pane's edit mode (`&mode=edit`): the site page opened
/// unlocked, back to the site in view mode ([onCancel]) once its sitting
/// ends, as `unlockedDivePane` is for a dive.
Widget unlockedSitePane(
  BuildContext context,
  String id,
  VoidCallback onCancel, {
  VoidCallback? onDeleted,
}) => SiteDetailPage(
  siteId: id,
  embedded: true,
  openUnlocked: true,
  onSittingEnded: onCancel,
  onDeleted: onDeleted,
);

/// The site list's edit pane, as the master-detail scaffold's
/// `editBuilder`: [unlockedSitePane]. [onSaved] is the scaffold's, and
/// unused: a sitting saves in place.
Widget siteEditPane(
  BuildContext context,
  String id,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  VoidCallback? onDeleted,
}) => unlockedSitePane(context, id, onCancel, onDeleted: onDeleted);

/// The dive list pane's site in edit mode (`&site=<id>&mode=edit`): the
/// site page opened unlocked, whose sitting's end returns the site to view
/// mode ([onCancel]) and whose back arrow, on the locked row only (the open
/// sitting's header covers it), returns to the dive ([onClose]).
Widget siteInDivesPane(
  BuildContext context,
  String siteId, {
  required VoidCallback onCancel,
  required VoidCallback onClose,
  required VoidCallback onDeleted,
}) => SiteDetailPage(
  siteId: siteId,
  embedded: true,
  openUnlocked: true,
  onClose: onClose,
  onSittingEnded: onCancel,
  onDeleted: onDeleted,
);

/// The new-site address (`/sites/new`, `?duplicateOf=` for a duplicate),
/// with what the route was handed as [extra] (issue #4527, plan 6): the
/// site page opened unlocked on a new site.
Widget newSitePage(Object? extra, {String? duplicateOfId}) =>
    SiteDetailPage.newSite(
      seed: NewSiteSeed.fromRouteExtra(extra),
      duplicateOfId: duplicateOfId,
    );

/// The site list's new-site pane (`?mode=new`), as the master-detail
/// scaffold's `createBuilder`: the site page on a new site, whose created
/// id is handed to [onSaved], which selects it.
Widget newSitePane(
  BuildContext context,
  void Function(String savedId) onSaved,
  VoidCallback onCancel,
) => SiteDetailPage.newSite(
  embedded: true,
  onCreated: onSaved,
  onCreateCancelled: onCancel,
);

/// Opens a new site on its own page, from an opener that has no place of
/// its own to show it (the list's Add on a phone, its empty state, the
/// map): the site opens, locked, once created (plan 6, Question 1).
Future<void> openNewSite(BuildContext context) async {
  final id = await context.push<String>('/sites/new');
  if (id == null || !context.mounted) return;
  await context.push('/sites/$id');
}

/// The site ids the merge address (`/sites/merge`) was handed as its
/// `extra`: none for anything but a list of ids.
List<String> siteMergeIds(Object? extra) =>
    extra is List ? extra.whereType<String>().toList() : const [];

/// The merge route's redirect: back to the site list when the address was
/// handed fewer than two sites to merge, as a reload or a bookmark is
/// (issue #4527, phase 2, plan 7).
String? siteMergeRedirect(BuildContext context, GoRouterState state) =>
    siteMergeIds(state.extra).length < 2 ? '/sites' : null;
