import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// The site's types, edited on the header block (issue #4527, phase 2).
///
/// Written at Save, after the site, as the difference from what the sitting
/// loaded: a type stored meanwhile (a sync) that the sitting never loaded is
/// kept, since [SiteClassificationRepository.replaceTypes] sets the whole
/// list. Their order is the order they were picked, so the same types in
/// another order are not a change.
final siteTypesList = SittingList<DiveSite, SiteTypeEntity>(
  key: 'site.types',
  cardId: siteHeaderCardId,
  read: (site) => SiteClassificationRepository().getTypesForSite(site.id),
  write: (site, loaded, current) async {
    final repository = SiteClassificationRepository();
    final now = [
      for (final t in await repository.getTypesForSite(site.id)) t.id,
    ];
    final merged = mergedIds(
      stored: now,
      loaded: [for (final t in loaded) t.id],
      current: [for (final t in current) t.id],
    );
    // Nothing to write when a sync made the same change meanwhile: no
    // write, and no library clock that would beat another member's edit.
    if (sameIdSets(merged, now, (id) => id)) return false;
    await repository.replaceTypes(
      site.id,
      merged,
      // Stamped once the sitting has committed, and allowed by the
      // sitting being offered at all.
      notify: false,
    );
    return true;
  },
  same: (a, b) => sameIdSets(a, b, (t) => t.id),
);

/// The site's tags, edited on the Tags card, written as [siteTypesList] is.
final siteTagsList = SittingList<DiveSite, Tag>(
  key: 'site.tags',
  cardId: SiteDetailSectionId.tags.name,
  read: (site) => SiteClassificationRepository().getTagsForSite(site.id),
  write: (site, loaded, current) async {
    final repository = SiteClassificationRepository();
    final now = [
      for (final t in await repository.getTagsForSite(site.id)) t.id,
    ];
    final merged = mergedIds(
      stored: now,
      loaded: [for (final t in loaded) t.id],
      current: [for (final t in current) t.id],
    );
    // Nothing to write when a sync made the same change meanwhile: no
    // write, and no library clock that would beat another member's edit.
    if (sameIdSets(merged, now, (id) => id)) return false;
    await repository.replaceTags(site.id, merged, notify: false);
    return true;
  },
  same: (a, b) => sameIdSets(a, b, (t) => t.id),
);

/// [stored] less what the sitting removed from [loaded], then what it added
/// in [current], in order.
List<String> mergedIds({
  required List<String> stored,
  required List<String> loaded,
  required List<String> current,
}) {
  final kept = current.toSet();
  final removed = {
    for (final id in loaded)
      if (!kept.contains(id)) id,
  };
  final had = loaded.toSet();
  final result = [
    for (final id in stored)
      if (!removed.contains(id)) id,
  ];
  for (final id in current) {
    if (!had.contains(id) && !result.contains(id)) result.add(id);
  }
  return result;
}
