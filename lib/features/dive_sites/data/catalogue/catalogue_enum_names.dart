import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The enums a catalogue record names, by name.
///
/// Built once: `asNameMap` makes a new map on every call, and both reading
/// the file and reading a row look one up for every record.
final Map<String, WaterType> waterTypesByName = WaterType.values.asNameMap();
final Map<String, EntryMethod> entryMethodsByName = EntryMethod.values
    .asNameMap();
final Map<String, SiteDifficulty> siteDifficultiesByName = SiteDifficulty.values
    .asNameMap();
final Map<String, CatalogueTrust> catalogueTrustByName = CatalogueTrust.values
    .asNameMap();
final Map<String, CatalogueKind> catalogueKindsByName = CatalogueKind.values
    .asNameMap();
