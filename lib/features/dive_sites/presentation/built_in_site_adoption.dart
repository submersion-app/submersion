import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_adoption_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/run_rules_flow.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Adds the built-in [site] to the diver's sites from a screen that shows
/// it (the Sites maps, the record's own page), and says how it went.
///
/// One flow for every such screen: the one adoption path, a message either
/// way, the diver's sites read again, and the diver's "after creating by
/// hand" rules run on a site this call created (#3513), never on one they
/// already had.
///
/// Everything it needs from the screen is read before the write starts, so
/// it finishes the same way if the diver leaves meanwhile: the site is
/// added, the message shows wherever they went, and the rules still run.
/// [onAdopted] is for what only the screen can do (clear a selection, open
/// the new site); it is called before the rules run, and must itself check
/// that its screen is still there.
///
/// Returns the adoption, or null when it failed (and said so).
Future<CatalogueAdoption?> adoptBuiltInSite(
  BuildContext context,
  WidgetRef ref,
  CatalogueSite site, {
  void Function(CatalogueAdoption adoption)? onAdopted,
}) async {
  final rulesAfterCreate = captureRulesAfterCreate(context, ref);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final errorColor = Theme.of(context).colorScheme.error;
  final container = ProviderScope.containerOf(context, listen: false);
  final adopt = container.read(catalogueSiteAdopterProvider);

  final CatalogueAdoption adoption;
  try {
    adoption = await adopt(site);
  } catch (_) {
    if (messenger.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.diveSites_map_builtInSites_addError),
          backgroundColor: errorColor,
        ),
      );
    }
    return null;
  }
  // The adoption reloads the list's notifier, not this provider, which the
  // maps and the record's page read to know the record is now the diver's.
  container.invalidate(sitesWithCountsProvider);
  if (messenger.mounted) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.diveSites_map_builtInSites_added)),
    );
  }
  onAdopted?.call(adoption);
  // Only a site this call created (see CatalogueAdoption.created).
  if (adoption.created) {
    await rulesAfterCreate(subject: RuleSubject.sites, ids: [adoption.site.id]);
  }
  return adoption;
}
