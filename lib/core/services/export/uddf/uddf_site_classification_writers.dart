import 'package:xml/xml.dart';

import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';

/// UDDF writers for dive site types and site tags (issue #1765), shared by
/// the full backup and the dives-only export so their two `<site>` builders
/// cannot drift apart (the #1735 lesson). UDDF has no standard element for
/// either; both are Submersion extensions the full importer reads back.
class UddfSiteClassificationWriters {
  const UddfSiteClassificationWriters._();

  /// Inside a `<site>`: the site's type slugs and tag references. Writes
  /// nothing for an unclassified site.
  static void writeSiteRefs(
    XmlBuilder builder, {
    required List<String> siteTypeIds,
    required List<String> tagIds,
  }) {
    if (siteTypeIds.isNotEmpty) {
      builder.element(
        'sitetypes',
        nest: () {
          for (final id in siteTypeIds) {
            builder.element('sitetyperef', nest: id);
          }
        },
      );
    }
    if (tagIds.isNotEmpty) {
      builder.element(
        'tags',
        nest: () {
          for (final id in tagIds) {
            builder.element('tagref', nest: 'tag_$id');
          }
        },
      );
    }
  }

  /// Inside `<applicationdata><submersion>`: the custom site types. Built-ins
  /// are referenced by slug and never defined; every install seeds them.
  static void writeCustomSiteTypeDefinitions(
    XmlBuilder builder,
    List<SiteTypeEntity> types,
  ) {
    final custom = types.where((t) => !t.isBuiltIn).toList();
    if (custom.isEmpty) return;
    builder.element(
      'sitetypes',
      nest: () {
        for (final type in custom) {
          builder.element(
            'sitetype',
            attributes: {'id': type.id},
            nest: () {
              builder.element('name', nest: type.name);
              builder.element('sortorder', nest: type.sortOrder.toString());
            },
          );
        }
      },
    );
  }
}
