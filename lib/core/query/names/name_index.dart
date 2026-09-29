import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/syntax/query_suggestions.dart';

/// What a label lowers to when a sentence or a typed query names it
/// (#2365). The names are stored inside pinned identities, so they never
/// change.
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
  siteTypeId,
  courseId,
  diveTypeId;

  /// Whether the entry names one row a typed ref can hold. A place, an
  /// attribute choice and a legacy buddy name are for sentences only.
  bool get isRow => switch (this) {
    sitePlace || attrChoice || legacyBuddyName => false,
    _ => true,
  };
}

/// The row target for a ref subject.
NameTarget rowTargetFor(QuerySubject subject) => switch (subject) {
  QuerySubject.sites => NameTarget.siteId,
  QuerySubject.species => NameTarget.speciesId,
  QuerySubject.equipment => NameTarget.equipmentId,
  QuerySubject.buddies => NameTarget.buddyId,
  QuerySubject.tags => NameTarget.tagId,
  QuerySubject.centers => NameTarget.centerId,
  QuerySubject.trips => NameTarget.tripId,
  QuerySubject.computers => NameTarget.computerId,
  QuerySubject.siteTypes => NameTarget.siteTypeId,
  QuerySubject.courses => NameTarget.courseId,
  QuerySubject.diveTypes => NameTarget.diveTypeId,
  _ => throw ArgumentError.value(subject, 'subject', 'not a ref subject'),
};

/// One label the diver's data offers, and what it maps to.
class NameEntry {
  const NameEntry({
    required this.subject,
    required this.label,
    required this.ids,
    required this.target,
    this.rank = 0,
    this.primary = false,
    this.attrKey,
    this.attrChoice,
    this.placeFields = const [],
  });

  final QuerySubject subject;
  final String label;

  /// One id for a row target; every site id under a place; empty for an
  /// attribute choice or a legacy buddy name (the label is the value).
  final List<String> ids;
  final NameTarget target;

  /// Match-group order for sentences; lower ranks are tried first.
  final int rank;

  /// The one label a typed ref prints for its row: the registry name.
  final bool primary;
  final String? attrKey;
  final String? attrChoice;

  /// The site columns a place label came from, in the order country,
  /// region, island, city.
  final List<String> placeFields;

  /// Identity for deduplication and for a pinned pick. Its format is
  /// stored in recent queries; never change it.
  String get identity =>
      '${target.name}:${ids.join(',')}:${attrKey ?? ''}:${attrChoice ?? ''}:'
      '${target == NameTarget.legacyBuddyName ? label : ''}';
}

/// A snapshot of every name the diver's data offers (#2365): the typed
/// parser resolves `site = "Salt Pier"` through [resolve], the builder's
/// pickers list [refs], a saved query checks its ids through [labelOf],
/// and Explore's resolver matches sentences against [forSubject].
class NameIndex implements NameResolver, NameEntries {
  NameIndex(Iterable<NameEntry> entries)
    : entries = List.unmodifiable(entries) {
    for (final e in this.entries) {
      _bySubject.putIfAbsent(e.subject, () => []).add(e);
      if (e.primary && e.target.isRow) {
        final id = e.ids.single;
        _labels.putIfAbsent(e.subject, () => {})[id] = e.label;
        _refs.putIfAbsent(e.subject, () => []).add(RefValue(id, e.label));
      }
    }
    for (final list in _bySubject.values) {
      // Primary names first, then alternates by rank, so another row's
      // alternate never shadows a primary name.
      list.sort((a, b) {
        if (a.primary != b.primary) return a.primary ? -1 : 1;
        return a.rank.compareTo(b.rank);
      });
    }
  }

  /// One primary row per ref, for tests and for callers with bare refs.
  factory NameIndex.fromRefs(Map<QuerySubject, List<RefValue>> refs) =>
      NameIndex([
        for (final e in refs.entries)
          for (final r in e.value)
            NameEntry(
              subject: e.key,
              label: r.label,
              ids: [r.id],
              target: rowTargetFor(e.key),
              primary: true,
            ),
      ]);

  static final NameIndex empty = NameIndex(const []);

  final List<NameEntry> entries;
  final _bySubject = <QuerySubject, List<NameEntry>>{};
  final _labels = <QuerySubject, Map<String, String>>{};
  final _refs = <QuerySubject, List<RefValue>>{};

  Iterable<NameEntry> forSubject(QuerySubject subject) =>
      _bySubject[subject] ?? const [];

  /// Every row of [subject] by its primary label.
  List<RefValue> refs(QuerySubject subject) => _refs[subject] ?? const [];

  @override
  Iterable<RefValue> refEntries(QuerySubject kind) => refs(kind);

  String? labelOf(QuerySubject subject, String id) => _labels[subject]?[id];

  /// An exact, case-insensitive match on any row label, primary names
  /// first. The ref carries the primary label, so printing it and parsing
  /// the print gives back the same ref.
  @override
  RefValue? resolve(QuerySubject kind, String text) {
    final wanted = text.trim().toLowerCase();
    if (wanted.isEmpty) return null;
    for (final e in forSubject(kind)) {
      if (!e.target.isRow) continue;
      if (e.label.trim().toLowerCase() != wanted) continue;
      final id = e.ids.single;
      return RefValue(id, labelOf(kind, id) ?? e.label);
    }
    return null;
  }

  @override
  List<String> candidates(QuerySubject kind, String text) =>
      suggestNames(text, {
        for (final e in forSubject(kind))
          if (e.target.isRow) e.label,
      });
}
