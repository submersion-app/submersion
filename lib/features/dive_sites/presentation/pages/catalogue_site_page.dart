import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_adoption_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_nearby.dart';
import 'package:submersion/features/dive_sites/presentation/providers/catalogue_site_page_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_page/catalogue_about_card.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_page/catalogue_location_card.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_page/catalogue_nearby_card.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_page/catalogue_site_header.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_page/catalogue_site_map_strip.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_page/catalogue_source_card.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_detail_section_list.dart';
import 'package:submersion/features/reef/presentation/widgets/reef_section.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/run_rules_flow.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The widest a built-in site's page lays its content out. On a wide
/// window the content is centred at this width, not stretched.
const double kCatalogueSitePageMaxWidth = 720;

/// One record of the built-in catalogue, to read before diving it: where
/// it is, what the catalogue holds for it, tides and reef for its
/// position, what lies near it, and where the record came from.
///
/// Read-only, with one action: "Add to my sites", through the one adoption
/// path. It is not one of the diver's sites and has none of what belongs
/// to one (notes, a rating, dives, photos).
///
/// A record that is already the diver's never shows this page: the page
/// replaces itself with that site's own page, when it opens and whenever
/// the diver's sites change while it is open.
class CatalogueSitePage extends ConsumerStatefulWidget {
  const CatalogueSitePage({super.key, required this.catalogueId});

  final String catalogueId;

  @override
  ConsumerState<CatalogueSitePage> createState() => _CatalogueSitePageState();
}

class _CatalogueSitePageState extends ConsumerState<CatalogueSitePage> {
  /// An adoption this page started is under way.
  bool _adding = false;

  /// The page has asked to be replaced by the diver's own site page. Set
  /// once: adding a site and noticing that the record is now the diver's
  /// both lead here, and the page must be replaced one time.
  bool _leaving = false;

  /// Replaces this page with the page of the diver's site [siteId].
  void _openOwn(String siteId) {
    if (_leaving) return;
    _leaving = true;
    // Not during a build, which is where the owner is first noticed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pushReplacement('/sites/$siteId');
    });
  }

  Future<void> _add(CatalogueSite site) async {
    if (_adding || _leaving) return;
    // Read now: adding a built-in site is creating a site by hand (#3513),
    // and it gets its rules even though this page is replaced meanwhile.
    final rulesAfterCreate = captureRulesAfterCreate(context, ref);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final errorColor = Theme.of(context).colorScheme.error;
    setState(() => _adding = true);

    final CatalogueAdoption adoption;
    try {
      adoption = await ref.read(catalogueSiteAdopterProvider)(site);
    } catch (_) {
      if (mounted) setState(() => _adding = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.diveSites_map_builtInSites_addError),
          backgroundColor: errorColor,
        ),
      );
      return;
    }
    if (mounted) {
      // The adoption reloads the list's notifier, not this provider, which
      // the map and this page's own "is it mine?" check read.
      ref.invalidate(sitesWithCountsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.diveSites_map_builtInSites_added)),
      );
      _openOwn(adoption.site.id);
    }
    // Only a site this tap created (see CatalogueAdoption.created).
    if (adoption.created) {
      await rulesAfterCreate(
        subject: RuleSubject.sites,
        ids: [adoption.site.id],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.catalogueId;
    ref.listen<String?>(catalogueOwnerSiteIdProvider(id), (_, owner) {
      if (owner != null) _openOwn(owner);
    });
    final owner = ref.watch(catalogueOwnerSiteIdProvider(id));
    if (owner != null) _openOwn(owner);

    final record = ref.watch(catalogueSiteProvider(id));
    final sitesKnown = ref.watch(
      sitesWithCountsProvider.select((sites) => sites.hasValue),
    );
    final site = record.value;

    // Nothing of the record is drawn until it is known not to be the
    // diver's: their own page is on its way, and the built-in page must
    // not flash by first.
    if (owner != null || _leaving || !sitesKnown || record.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(site?.name ?? '')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (site == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.l10n.diveSites_builtInPage_notFound,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final addLabel = context.l10n.diveSites_map_builtInSites_add;
    final onAdd = _adding ? null : () => _add(site);
    return Scaffold(
      appBar: AppBar(
        title: Text(site.name),
        actions: [
          IconButton(
            key: const ValueKey('catalogueAddAction'),
            icon: const Icon(Icons.add_location_alt),
            tooltip: addLabel,
            onPressed: onAdd,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: kCatalogueSitePageMaxWidth,
            ),
            child: _CatalogueSiteContent(
              site: site,
              addLabel: addLabel,
              onAdd: onAdd,
            ),
          ),
        ),
      ),
    );
  }
}

/// The page's cards, in their fixed order. A card with nothing to show
/// for this record is left out, gap and all.
class _CatalogueSiteContent extends ConsumerWidget {
  const _CatalogueSiteContent({
    required this.site,
    required this.addLabel,
    required this.onAdd,
  });

  final CatalogueSite site;
  final String addLabel;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearby =
        ref.watch(catalogueNearbyProvider(site.id)).value ??
        CatalogueNearby.empty;
    final location = site.location;

    final cards = <Widget>[
      if (location != null) CatalogueSiteMapStrip(site: site),
      CatalogueSiteHeader(site: site, here: nearby.here),
      if (CatalogueAboutCard.hasContent(site)) CatalogueAboutCard(site: site),
      if (CatalogueHazardsCard.hasContent(site))
        CatalogueHazardsCard(site: site),
      if (CatalogueLocationCard.hasContent(site))
        CatalogueLocationCard(site: site),
      // A quarry or lake has no tides, and a nearby ocean station must not
      // leak in.
      if (location != null && site.waterType != WaterType.fresh)
        TideSection(location: location),
      if (location != null)
        ReefSection(location: location, waterType: site.waterType),
      if (!nearby.isEmpty) CatalogueNearbyCard(nearby: nearby),
      CatalogueSourceCard(site: site),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const ValueKey('catalogueAddButton'),
          icon: const Icon(Icons.add_location_alt),
          label: Text(addLabel),
          onPressed: onAdd,
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, card) in cards.indexed) ...[
          if (index > 0) const SizedBox(height: kSiteDetailCardGap),
          card,
        ],
      ],
    );
  }
}
