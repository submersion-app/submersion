import 'package:xml/xml.dart';

import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';

/// UDDF writer for a site's own features (issue #2200): the diver-placed
/// markers that carry their own coordinates, such as a wreck, a mooring or
/// an entry point.
///
/// Shared by the full backup and the dives-only export so their two `<site>`
/// builders cannot drift apart (the #1735 lesson). UDDF has no standard
/// element for a point inside a site, so `<sitefeatures>` is a Submersion
/// extension written inline in `<site>`, next to `<sitetypes>` and `<tags>`:
/// features are per-site instance data, not shared definitions, so there is
/// nothing for `<applicationdata>` to hold.
class UddfSiteFeatureWriters {
  const UddfSiteFeatureWriters._();

  /// Inside a `<site>`: every feature placed on it. Writes nothing for a
  /// site with no features.
  ///
  /// The type goes out as the raw stored [SiteFeature.typeName] rather than
  /// the parsed enum, so a type written by a newer build survives a round
  /// trip through an older one unchanged.
  static void writeSiteFeatures(
    XmlBuilder builder,
    List<SiteFeature> features,
  ) {
    if (features.isEmpty) return;
    builder.element(
      'sitefeatures',
      nest: () {
        for (final feature in features) {
          builder.element(
            'sitefeature',
            attributes: {'id': 'sitefeature_${feature.id}'},
            nest: () {
              builder.element('type', nest: feature.typeName);
              if (feature.name.isNotEmpty) {
                builder.element('name', nest: feature.name);
              }
              builder.element(
                'geography',
                nest: () {
                  builder.element(
                    'latitude',
                    nest: feature.latitude.toString(),
                  );
                  builder.element(
                    'longitude',
                    nest: feature.longitude.toString(),
                  );
                },
              );
              if (feature.bearingDeg != null) {
                builder.element('bearing', nest: feature.bearingDeg.toString());
              }
              if (feature.depthMeters != null) {
                builder.element('depth', nest: feature.depthMeters.toString());
              }
              if (feature.notes.isNotEmpty) {
                builder.element('notes', nest: feature.notes);
              }
            },
          );
        }
      },
    );
  }
}
