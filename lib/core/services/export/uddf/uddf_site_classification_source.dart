import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// The site types and tags a UDDF export writes for its sites (issue #1765).
class UddfSiteClassificationSource {
  /// Type slugs and tag ids per exported site.
  final Map<String, List<String>> typeIdsBySite;
  final Map<String, List<String>> tagIdsBySite;

  /// Every definition those references need. Built-in types go by slug
  /// alone, so only custom ones are listed.
  final List<SiteTypeEntity> customSiteTypes;
  final List<Tag> siteTags;

  const UddfSiteClassificationSource({
    this.typeIdsBySite = const {},
    this.tagIdsBySite = const {},
    this.customSiteTypes = const [],
    this.siteTags = const [],
  });
}

/// Loads the classification of [siteIds] and resolves each referenced type
/// and tag by id.
///
/// By id, not from the current diver's vocabulary: a shared site can carry
/// another profile's custom type or tag, and a reference written without its
/// definition cannot be resolved on import.
Future<UddfSiteClassificationSource> loadSiteClassificationForExport(
  SiteClassificationRepository classification,
  SiteTypeRepository? siteTypes,
  List<String> siteIds,
) async {
  final typeIdsBySite = await classification.getTypeIdsBySite(siteIds);
  final tagIdsBySite = await classification.getTagIdsBySite(siteIds);
  final tagsBySite = await classification.getTagsBySite();
  final siteTags = <String, Tag>{
    for (final siteId in siteIds)
      for (final tag in tagsBySite[siteId] ?? const <Tag>[]) tag.id: tag,
  };
  final customSiteTypes = <SiteTypeEntity>[];
  for (final typeId in {for (final ids in typeIdsBySite.values) ...ids}) {
    final type = await siteTypes?.getSiteTypeById(typeId);
    if (type != null && !type.isBuiltIn) customSiteTypes.add(type);
  }
  return UddfSiteClassificationSource(
    typeIdsBySite: typeIdsBySite,
    tagIdsBySite: tagIdsBySite,
    customSiteTypes: customSiteTypes,
    siteTags: siteTags.values.toList(),
  );
}

/// [base] plus every item of [extra] whose id it lacks, in that order.
List<T> mergeById<T>(
  List<T> base,
  List<T> extra,
  String Function(T item) idOf,
) {
  final seen = {for (final item in base) idOf(item)};
  return [
    ...base,
    for (final item in extra)
      if (seen.add(idOf(item))) item,
  ];
}
