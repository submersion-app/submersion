import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_nearby.dart';
import 'package:submersion/features/dive_sites/presentation/built_in_site_adoption.dart';
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
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
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

  /// Whether this page is the one on top. A page the diver has gone on
  /// from is still built, and still hears that its record became theirs.
  bool get _isOnTop => ModalRoute.of(context)?.isCurrent ?? true;

  /// Replaces this page with the page of the diver's site [siteId].
  ///
  /// Only while this page is on top: the router replaces whichever page
  /// is, and one the diver has gone on to (a nearby site, a form they are
  /// typing in) is not this page's to replace. A covered page waits, and
  /// hands over when the diver comes back to it.
  void _openOwn(String siteId) {
    if (_leaving || !_isOnTop) return;
    _leaving = true;
    // Not during a build, which is where the owner is first noticed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isOnTop) {
        // Covered in the frame between: try again when it is back on top.
        setState(() => _leaving = false);
        return;
      }
      context.pushReplacement('/sites/$siteId');
    });
  }

  Future<void> _add(CatalogueSite site) async {
    if (_adding || _leaving) return;
    setState(() => _adding = true);
    final adoption = await adoptBuiltInSite(
      context,
      ref,
      site,
      // The diver's own new site takes this page's place.
      onAdopted: (adoption) {
        if (mounted) _openOwn(adoption.site.id);
      },
    );
    // Failed, and said so: the page stays, and the diver can try again.
    if (adoption == null && mounted) setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.catalogueId;
    // Watched, so the page is rebuilt, and moves on, whenever the record
    // becomes the diver's: at open, after an add, or by a sync. Read with
    // the route's own state, so a page that was covered at the time is
    // rebuilt, and moves on, when the diver comes back to it.
    final owner = ref.watch(catalogueOwnerSiteIdProvider(id));
    if (owner != null) _openOwn(owner);

    final record = ref.watch(catalogueSiteProvider(id));
    // Settled either way. A read of the diver's sites that failed says
    // nothing against showing the record: the page must not wait on it
    // for ever.
    final sitesSettled = ref.watch(
      sitesWithCountsProvider.select(
        (sites) => sites.hasValue || sites.hasError,
      ),
    );
    final site = record.value;
    // A record the catalogue does not hold while the bundled catalogue is
    // still being imported may only not be there yet.
    final awaitingImport =
        site == null && ref.watch(siteCatalogueImportingProvider);

    // Nothing of the record is drawn until it is known not to be the
    // diver's: their own page is on its way, and the built-in page must
    // not flash by first. A record already on screen stays while it is
    // read again (an import that lands while the page is open).
    if (owner != null ||
        _leaving ||
        !sitesSettled ||
        awaitingImport ||
        (record.isLoading && !record.hasValue)) {
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
    final l10n = context.l10n;
    final nearby =
        ref.watch(catalogueNearbyProvider(site.id)).value ??
        CatalogueNearby.empty;
    final source = ref.watch(catalogueSourceProvider(site.source)).value;
    final location = site.location;
    // Tides for the position, unless the record says fresh water: a quarry
    // or lake has no tides, and a nearby ocean station must not leak in.
    // Few records say (308 of 20,931), so the position is asked as well: a
    // lake the catalogue has no water type for has no tide data, and a card
    // saying only that is left out like any other with nothing to show.
    // While that is still being found out the card holds its place.
    final showTides =
        location != null &&
        site.waterType != WaterType.fresh &&
        ref.watch(hasTideDataProvider(location)).value != false;

    final cards = <Widget>[
      if (location != null) CatalogueSiteMapStrip(site: site),
      CatalogueSiteHeader(site: site, here: nearby.here),
      if (CatalogueAboutCard.hasContent(site, l10n))
        CatalogueAboutCard(site: site),
      if (CatalogueHazardsCard.hasContent(site))
        CatalogueHazardsCard(site: site),
      if (CatalogueLocationCard.hasContent(site))
        CatalogueLocationCard(site: site),
      if (showTides) TideSection(location: location),
      if (location != null)
        ReefSection(location: location, waterType: site.waterType),
      if (!nearby.isEmpty) CatalogueNearbyCard(nearby: nearby),
      if (CatalogueSourceCard.hasContent(site, source))
        CatalogueSourceCard(site: site, source: source),
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
