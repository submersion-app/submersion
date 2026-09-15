import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _log = LoggerService.forClass(SiteLinks);

/// What a delete of [siteIds] would leave without a site, for its
/// confirmation: a site delete keeps the dives and plans that used it, with
/// the site cleared (issue #1952).
///
/// The counts only inform the confirmation, so a failed read opens it
/// without them rather than blocking the delete.
Future<SiteLinks> readSiteDeleteUsage(
  WidgetRef ref,
  List<String> siteIds,
) async {
  try {
    return await ref.read(siteRepositoryProvider).getSiteLinks(siteIds);
  } catch (e, stackTrace) {
    _log.warning(
      'Could not count the dives and plans a site delete unlinks',
      error: e,
      stackTrace: stackTrace,
    );
    return const SiteLinks();
  }
}

/// [body], then a paragraph for each kind of row [links] leaves without a
/// site.
String withSiteDeleteUsage(
  AppLocalizations l10n,
  String body,
  SiteLinks links,
) => [
  body,
  if (links.diveSiteIds.isNotEmpty)
    l10n.diveSites_deleteDialog_divesKept(links.diveSiteIds.length),
  if (links.planSiteIds.isNotEmpty)
    l10n.diveSites_deleteDialog_plansKept(links.planSiteIds.length),
].join('\n\n');
