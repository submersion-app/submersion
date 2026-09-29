import 'package:submersion/features/explore/domain/query_model.dart';

/// What a matched label lowers to.
enum NameTarget {
  siteId,
  sitePlace,
  speciesId,
  equipmentId,
  attrChoice,
  buddyId,
  legacyBuddyName,
  tagId,
  centerId,
  tripId,
  computerId,
}

/// One label the diver's data offers for matching, and what it maps to.
class NameEntry {
  final MentionKind kind;
  final String label;

  /// One id for an entity target; every site id under a place; empty for an
  /// attribute choice or a legacy buddy name (the label itself is the value).
  final List<String> ids;
  final NameTarget target;
  final String? attrKey;
  final String? attrChoice;

  /// Match-group order within a kind; lower ranks are tried first.
  final int rank;

  const NameEntry({
    required this.kind,
    required this.label,
    required this.ids,
    required this.target,
    this.rank = 0,
    this.attrKey,
    this.attrChoice,
  });

  /// Identity for deduplication: the same ids under the same target.
  String get identity =>
      '${target.name}:${ids.join(',')}:${attrKey ?? ''}:${attrChoice ?? ''}:'
      '${target == NameTarget.legacyBuddyName ? label : ''}';
}

class NameIndex {
  final List<NameEntry> entries;
  const NameIndex(this.entries);
  static const empty = NameIndex([]);

  Iterable<NameEntry> forKind(MentionKind kind) =>
      entries.where((e) => e.kind == kind);
}
