import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Whether a check-in recorded a problem. An `ok` row is a deliberate
/// check and is evidence in its own right ("no issue in 12 checked dives").
enum ObservationStatus {
  ok,
  issue;

  String get dbValue => name;

  static ObservationStatus fromDbValue(String? value) {
    for (final s in values) {
      if (s.name == value) return s;
    }
    return ObservationStatus.ok;
  }
}

/// What went wrong. Names are the stored values; the catalog says which
/// tags each equipment type is offered.
enum ObservationTag {
  freeFlow,
  hardBreathing,
  wetBreathing,
  leak,
  hoseDamage,
  inflatorStuck,
  inflatorSlow,
  bladderLeak,
  dumpLeak,
  leakNeck,
  leakWrist,
  leakZip,
  leakBoot,
  leakValve,
  leakSeam,
  tear,
  seamFailure,
  dim,
  died,
  flooded,
  switchFault,
  batteryLow,
  screenFault,
  connectionFault,
  dropout,
  cellWarning,
  loopLeak,
  solenoidFault,
  scrubberBreakthrough,
  slowResponse,
  erratic,
  lowCapacity,
  propFault,
  strapBroke,
  other;

  String get dbValue => name;

  /// Null for a name this build does not know (a newer peer), so the
  /// caller drops it rather than mislabel it.
  static ObservationTag? fromDbValue(String value) {
    for (final t in values) {
      if (t.name == value) return t;
    }
    return null;
  }
}

/// One post-dive (or bench) check-in on one item. Any number may share an
/// item and a dive.
class EquipmentObservation extends Equatable {
  final String id;
  final String? diverId;
  final String equipmentId;

  /// The dive the check-in belongs to; null for a bench observation.
  final String? diveId;
  final DateTime observedAt;
  final ObservationStatus status;
  final List<ObservationTag> issueTags;

  /// Stored tag names this build does not know, written by a newer peer.
  /// They cannot be shown, but an edit here writes them back: dropping
  /// them would delete them on every device, the newer one included.
  final List<String> unrecognizedTags;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EquipmentObservation({
    required this.id,
    this.diverId,
    required this.equipmentId,
    this.diveId,
    required this.observedAt,
    required this.status,
    this.issueTags = const [],
    this.unrecognizedTags = const [],
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isIssue => status == ObservationStatus.issue;

  /// Every tag name the row stores: for an issue, the known tags then the
  /// names a newer peer wrote; an OK check stores none. What an export
  /// writes, so a file never drops tags this build merely cannot read, and
  /// never gives an OK check an issue's tags.
  List<String> get storedTagNames => [
    if (isIssue) ...[for (final t in issueTags) t.dbValue, ...unrecognizedTags],
  ];

  EquipmentObservation copyWith({
    String? id,
    String? diverId,
    String? equipmentId,
    String? diveId,
    bool clearDiveId = false,
    DateTime? observedAt,
    ObservationStatus? status,
    List<ObservationTag>? issueTags,
    List<String>? unrecognizedTags,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => EquipmentObservation(
    id: id ?? this.id,
    diverId: diverId ?? this.diverId,
    equipmentId: equipmentId ?? this.equipmentId,
    diveId: clearDiveId ? null : (diveId ?? this.diveId),
    observedAt: observedAt ?? this.observedAt,
    status: status ?? this.status,
    issueTags: issueTags ?? this.issueTags,
    unrecognizedTags: unrecognizedTags ?? this.unrecognizedTags,
    note: note ?? this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    diverId,
    equipmentId,
    diveId,
    observedAt,
    status,
    issueTags,
    unrecognizedTags,
    note,
    createdAt,
    updatedAt,
  ];
}

/// [tags] then [unrecognized], the names a newer peer wrote that this
/// build carries through unread.
String encodeObservationTags(
  List<ObservationTag> tags, {
  List<String> unrecognized = const [],
}) => jsonEncode([for (final t in tags) t.dbValue, ...unrecognized]);

/// Lenient: the column defaults to `[]`, and a tag a newer build added must
/// not make the row unreadable. Unknown names are dropped here; read them
/// with [decodeUnrecognizedObservationTags].
List<ObservationTag> decodeObservationTags(String json) => [
  for (final name in _tagNames(json)) ?ObservationTag.fromDbValue(name),
];

/// The stored names [decodeObservationTags] drops, in stored order.
List<String> decodeUnrecognizedObservationTags(String json) => [
  for (final name in _tagNames(json))
    if (ObservationTag.fromDbValue(name) == null) name,
];

List<String> _tagNames(String json) {
  if (json.isEmpty) return const [];
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  if (raw is! List) return const [];
  return [
    for (final entry in raw)
      if (entry is String) entry,
  ];
}
