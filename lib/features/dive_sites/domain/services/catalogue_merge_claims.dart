import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_site_visibility.dart';

/// What merging [mergedAway] into [survivor] leaves the survivor claiming
/// of the built-in catalogue.
///
/// The link is the survivor's own, else the first one among [mergedAway],
/// which is given in merge order, else none. Every other record the sites
/// were linked to or stood for becomes one the survivor stands for, so
/// none of them is offered to the diver again. "Not this site" answers are
/// united, less whatever the survivor now claims; details turned down are
/// kept for the surviving link only.
///
/// Keys a newer build wrote, which this one cannot read, are carried over
/// from every site: the merged rows are deleted, and what they held would
/// go with them. Where two sites hold the same key the survivor's value
/// stands, then the first merged site's. Nothing is blended, since what
/// such a value means is not known here.
///
/// The merge page cannot choose any of this: it builds the merged site
/// from a form that knows nothing of the catalogue.
({String? link, SiteCatalogueAnswers answers}) mergedCatalogueClaims({
  required DiveSite survivor,
  required List<DiveSite> mergedAway,
}) {
  final link =
      survivor.catalogueId ??
      mergedAway.map((site) => site.catalogueId).nonNulls.firstOrNull;
  final merged = [survivor, ...mergedAway];
  final also = {
    for (final id in linkedCatalogueIds(merged))
      if (id != link) id,
  };
  final before = survivor.catalogueAnswers;
  return (
    link: link,
    answers: before.copyWith(
      also: also,
      notSame: {
        for (final site in merged)
          for (final id in site.catalogueAnswers.notSame)
            if (id != link && !also.contains(id)) id,
      },
      declined: link == null ? const {} : {link: ?before.declined[link]},
      unknown: {
        // Last in wins, so the survivor goes last and merge order holds.
        for (final site in merged.reversed) ...site.catalogueAnswers.unknown,
      },
    ),
  );
}
