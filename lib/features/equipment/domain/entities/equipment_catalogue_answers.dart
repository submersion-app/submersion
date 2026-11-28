import 'dart:convert';

import 'package:equatable/equatable.dart';

/// What a diver has settled about equipment catalogue records for one item,
/// stored as JSON in `equipment.catalogue_answers` (issue #5118). The shape
/// follows the site catalogue's `SiteCatalogueAnswers`.
///
/// The item's link (`catalogueId`) says which record it is. This holds the
/// rest: records the diver said are not this item, and the fields of a
/// record the diver left empty when it was offered.
class EquipmentCatalogueAnswers extends Equatable {
  const EquipmentCatalogueAnswers({
    this.notSame = const {},
    this.declined = const {},
    this.unknown = const {},
  });

  static const empty = EquipmentCatalogueAnswers();

  static const _notKey = 'not';
  static const _declinedKey = 'declined';

  /// Record ids the diver said are not this item ("Not this model").
  final Set<String> notSame;

  /// For a record id, the names of the fields the diver left unticked when
  /// the item had them empty. They are not offered again from that record.
  /// The names are stored, so they are never renamed: `brand`, `model` or
  /// an attribute key.
  final Map<String, Set<String>> declined;

  /// Keys a newer build wrote that this one does not know. Kept as read, so
  /// rewriting the value here does not drop them.
  final Map<String, Object?> unknown;

  bool get isEmpty =>
      notSame.isEmpty &&
      declined.values.every((fields) => fields.isEmpty) &&
      unknown.isEmpty;

  /// Reads the stored text. Never throws: text that is missing, is not
  /// JSON, or is JSON of another shape reads as no answers, and a part of
  /// the wrong shape is skipped.
  factory EquipmentCatalogueAnswers.decode(String? text) {
    if (text == null || text.trim().isEmpty) return empty;
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return empty;
    }
    if (json is! Map) return empty;
    final declined = <String, Set<String>>{};
    if (json[_declinedKey] case final Map<dynamic, dynamic> raw) {
      for (final MapEntry(:key, :value) in raw.entries) {
        final fields = _strings(value);
        if (key is String && fields.isNotEmpty) declined[key] = fields;
      }
    }
    return EquipmentCatalogueAnswers(
      notSame: _strings(json[_notKey]),
      declined: declined,
      unknown: {
        for (final MapEntry(:key, :value) in json.entries)
          if (key is String && key != _notKey && key != _declinedKey)
            key: value,
      },
    );
  }

  static Set<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toSet() : const {};

  /// The text to store, or null when there is nothing to remember. Sorted,
  /// so equal answers are always written alike and a rewrite that changes
  /// nothing does not look like an edit.
  String? encode() {
    if (isEmpty) return null;
    final kept = {
      for (final MapEntry(:key, :value) in declined.entries)
        if (value.isNotEmpty) key: value.toList()..sort(),
    };
    return jsonEncode({
      if (kept.isNotEmpty)
        _declinedKey: {
          for (final key in kept.keys.toList()..sort()) key: kept[key],
        },
      if (notSame.isNotEmpty) _notKey: notSame.toList()..sort(),
      for (final key in unknown.keys.toList()..sort()) key: unknown[key],
    });
  }

  EquipmentCatalogueAnswers copyWith({
    Set<String>? notSame,
    Map<String, Set<String>>? declined,
    Map<String, Object?>? unknown,
  }) => EquipmentCatalogueAnswers(
    notSame: notSame ?? this.notSame,
    declined: declined ?? this.declined,
    unknown: unknown ?? this.unknown,
  );

  /// With [recordId] remembered as not this item.
  EquipmentCatalogueAnswers withNotSame(String recordId) =>
      copyWith(notSame: {...notSame, recordId});

  /// With [fieldNames] left empty for [recordId], added to any before.
  EquipmentCatalogueAnswers withDeclined(
    String recordId,
    Iterable<String> fieldNames,
  ) {
    final fields = {...?declined[recordId], ...fieldNames};
    if (fields.isEmpty) return this;
    return copyWith(declined: {...declined, recordId: fields});
  }

  @override
  List<Object?> get props => [notSame, declined, unknown];
}
