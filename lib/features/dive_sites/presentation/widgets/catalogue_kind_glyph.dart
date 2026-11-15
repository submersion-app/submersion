import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';

/// The glyph for a built-in catalogue record of [kind], wherever one is
/// drawn: a map pin, the layer menu, a built-in site's page.
///
/// A dive site is the hollow pin built-in sites have always had. A charted
/// wreck or reef is an anchor, so the two layers can be told apart when
/// both are on the map.
IconData catalogueKindIcon(CatalogueKind kind) => switch (kind) {
  CatalogueKind.site => Icons.location_on_outlined,
  CatalogueKind.register => Icons.anchor,
};
