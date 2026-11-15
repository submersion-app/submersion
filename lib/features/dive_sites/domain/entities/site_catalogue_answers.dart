import 'dart:convert';

import 'package:equatable/equatable.dart';

/// What a diver has settled about built-in catalogue records for one of
/// their sites, stored as JSON in `dive_sites.catalogue_answers`.
///
/// The site's link (`catalogueId`) says which record the site was adopted
/// from. This holds the rest: records the site also stands for, records the
/// diver said are a different place, and details of a record the diver
/// turned down.
class SiteCatalogueAnswers extends Equatable {
  const SiteCatalogueAnswers({
    this.also = const {},
    this.notSame = const {},
    this.declined = const {},
    this.unknown = const {},
  });

  static const empty = SiteCatalogueAnswers();

  static const _alsoKey = 'also';
  static const _notKey = 'not';
  static const _declinedKey = 'declined';

  /// Record ids this site stands for besides its link: a merge folded a
  /// site adopted from each of them into this one.
  final Set<String> also;

  /// Record ids the diver said are not this site.
  final Set<String> notSame;

  /// For a record id, the names of the offered fields the diver turned
  /// down. They are not offered again from that record.
  final Map<String, Set<String>> declined;

  /// Keys a newer build wrote that this one does not know. Kept as read,
  /// so rewriting the value here does not drop them.
  final Map<String, Object?> unknown;

  bool get isEmpty =>
      also.isEmpty &&
      notSame.isEmpty &&
      declined.values.every((fields) => fields.isEmpty) &&
      unknown.isEmpty;

  /// Reads the stored text. Never throws: text that is missing, is not
  /// JSON, or is JSON of another shape reads as no answers, and a part of
  /// the wrong shape is skipped.
  factory SiteCatalogueAnswers.decode(String? text) {
    if (text == null || text.trim().isEmpty) return empty;
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return empty;
    }
    if (json is! Map) return empty;

    final declined = <String, Set<String>>{};
    final rawDeclined = json[_declinedKey];
    if (rawDeclined is Map) {
      for (final entry in rawDeclined.entries) {
        final key = entry.key;
        final fields = _strings(entry.value);
        if (key is String && fields.isNotEmpty) declined[key] = fields;
      }
    }
    return SiteCatalogueAnswers(
      also: _strings(json[_alsoKey]),
      notSame: _strings(json[_notKey]),
      declined: declined,
      unknown: {
        for (final entry in json.entries)
          if (entry.key is String &&
              entry.key != _alsoKey &&
              entry.key != _notKey &&
              entry.key != _declinedKey)
            entry.key as String: entry.value,
      },
    );
  }

  static Set<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toSet() : const {};

  /// The text to store, or null when there is nothing to remember. Ids and
  /// field names are sorted, so equal answers are always written alike and
  /// a rewrite that changes nothing does not look like an edit.
  String? encode() {
    if (isEmpty) return null;
    final kept = {
      for (final entry in declined.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value.toList()..sort(),
    };
    return jsonEncode({
      if (also.isNotEmpty) _alsoKey: also.toList()..sort(),
      if (kept.isNotEmpty)
        _declinedKey: {
          for (final key in kept.keys.toList()..sort()) key: kept[key],
        },
      if (notSame.isNotEmpty) _notKey: notSame.toList()..sort(),
      for (final key in unknown.keys.toList()..sort()) key: unknown[key],
    });
  }

  SiteCatalogueAnswers copyWith({
    Set<String>? also,
    Set<String>? notSame,
    Map<String, Set<String>>? declined,
    Map<String, Object?>? unknown,
  }) => SiteCatalogueAnswers(
    also: also ?? this.also,
    notSame: notSame ?? this.notSame,
    declined: declined ?? this.declined,
    unknown: unknown ?? this.unknown,
  );

  /// With [recordId] remembered as a different place.
  SiteCatalogueAnswers withNotSame(String recordId) =>
      copyWith(notSame: {...notSame, recordId});

  /// With [fieldNames] turned down for [recordId], added to any turned
  /// down before.
  SiteCatalogueAnswers withDeclined(
    String recordId,
    Iterable<String> fieldNames,
  ) {
    final fields = {...?declined[recordId], ...fieldNames};
    if (fields.isEmpty) return this;
    return copyWith(declined: {...declined, recordId: fields});
  }

  @override
  List<Object?> get props => [also, notSame, declined, unknown];
}
