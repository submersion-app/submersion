/// The result of matching a single imported non-dive entity against an
/// existing entity in the database.
///
/// Contains pre-formatted display strings for both the existing and incoming
/// entity so the UI can render a side-by-side comparison without needing to
/// know entity-specific field types.
class EntityMatchResult {
  /// The database ID of the matched existing entity.
  final String existingId;

  /// The display name of the matched existing entity.
  final String existingName;

  /// Display fields for the existing entity, keyed by human-readable label.
  ///
  /// Example: `{'Location': '25.0N, -80.1W', 'Max Depth': '30m'}`.
  final Map<String, String?> existingFields;

  /// Display fields for the incoming entity, keyed by the same labels as
  /// [existingFields].
  final Map<String, String?> incomingFields;

  const EntityMatchResult({
    required this.existingId,
    required this.existingName,
    required this.existingFields,
    required this.incomingFields,
  });
}
