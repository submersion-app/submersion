import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Overflow-menu value of the site detail page's Duplicate action.
const kDuplicateSiteAction = 'duplicate';

/// The Duplicate row of the site detail menus (issue #3575).
PopupMenuItem<String> duplicateSiteMenuItem(BuildContext context) {
  return PopupMenuItem<String>(
    value: kDuplicateSiteAction,
    child: ListTile(
      leading: const Icon(Icons.copy),
      title: Text(context.l10n.diveSites_detail_duplicateMenu_label),
      contentPadding: EdgeInsets.zero,
    ),
  );
}

/// Opens the new-site form filled from [siteId] on top of the current page.
/// Nothing is written until it is saved, and Cancel returns here; once it
/// is saved the copy is shown from here, as this page knows where it is.
Future<void> openDuplicateSite(
  BuildContext context,
  WidgetRef ref,
  String siteId,
) async {
  final copyId = await context.push<String>(
    Uri(
      path: '/sites/new',
      queryParameters: {'duplicateOf': siteId},
    ).toString(),
  );
  if (copyId == null || !context.mounted) return;
  // The copy, not the original, is what the diver goes on to rename and
  // adjust. In the Sites list's own pane, list or table view, it becomes the
  // selected and highlighted row. Anywhere else (a phone page, a site opened
  // from a dive) its page opens on top, so Back returns here (#3292).
  if (GoRouterState.of(context).uri.path == '/sites') {
    ref.read(highlightedSiteIdProvider.notifier).state = copyId;
    context.go('/sites?selected=$copyId');
  } else {
    context.push('/sites/$copyId');
  }
}
