/// Base interface for all entity extractors.
///
/// Each extractor is responsible for pulling one entity type out of
/// pre-transformed CSV row maps and returning them as plain
/// [Map<String, dynamic>] records ready for correlation and persisting.
abstract class EntityExtractor<T> {
  /// Extract entities from the provided [rows] and return them as maps.
  List<Map<String, dynamic>> extractFromRows(List<Map<String, dynamic>> rows);
}
