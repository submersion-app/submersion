/// The browser keeps no downloaded catalogue: the web build never fetches
/// one (GitHub's release download sends no CORS header) and reads the copy
/// bundled with each deploy.
Future<String?> readEquipmentCatalogueCache({String? supportDir}) async => null;

/// Nothing to keep in a browser; see [readEquipmentCatalogueCache].
Future<void> writeEquipmentCatalogueCache(
  String json, {
  String? supportDir,
}) async {}
