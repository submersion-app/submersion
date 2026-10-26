import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'package:submersion/core/utils/number_utils.dart';

/// Tissue state reported by the dive computer itself, as the import found
/// it. Never computed by the app. Any field the source did not carry is null.
///
/// Stored on `dives.computer_tissue_json` as the JSON [toJson] writes (keys
/// are snake_case). Importers set it on `Dive.computerTissue`; the
/// map-based import pipeline carries it under the dive map key
/// `'computerTissue'` as a [ComputerTissueSnapshot] (a JSON map or JSON text
/// is accepted too, see [from]).
///
/// It holds only what has no dive column (issue #2555). The deco model is
/// `dives.deco_algorithm`, the computer's CNS at dive start and end is
/// `dives.cns_start` / `dives.cns_end` and its OTU is `dives.otu` (and the
/// data source's `cns` / `otu`); importers write those, never this. Older
/// snapshots carried all four; v318 moved them out, sync makes the same move
/// on a dive an older peer sends, and [fromJson] reads past any left (see
/// `LegacyTissueScalars`).
class ComputerTissueSnapshot extends Equatable {
  const ComputerTissueSnapshot({this.start, this.end});

  /// State at dive start (residual loading from earlier dives).
  final ComputerTissueState? start;

  /// State at dive end.
  final ComputerTissueState? end;

  /// Whether the end state (or, failing that, the start state) carries
  /// per-compartment values.
  bool get hasCompartmentData => (end ?? start)?.hasCompartments ?? false;

  ComputerTissueSnapshot copyWith({
    ComputerTissueState? start,
    ComputerTissueState? end,
  }) {
    return ComputerTissueSnapshot(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  /// JSON object with only the non-null fields.
  Map<String, dynamic> toJson() => {
    if (start != null) 'start': start!.toJson(),
    if (end != null) 'end': end!.toJson(),
  };

  /// Reads [toJson]'s shape. Missing keys and malformed values read as
  /// null, and so does a state left with no value it knows (one an older
  /// snapshot filled with CNS and OTU alone); this never throws on a map.
  factory ComputerTissueSnapshot.fromJson(Map<String, dynamic> json) {
    return ComputerTissueSnapshot(
      start: _stateOf(json['start']),
      end: _stateOf(json['end']),
    );
  }

  static ComputerTissueState? _stateOf(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final state = ComputerTissueState.fromJson(value);
    return state == const ComputerTissueState() ? null : state;
  }

  /// The JSON text the database column stores.
  String encode() => jsonEncode(toJson());

  /// Reads [encode]'s output. Null and blank text read as null (the column
  /// is nullable). Throws [FormatException] when [text] is not a JSON
  /// object; malformed values inside the object read as null.
  static ComputerTissueSnapshot? decode(String? text) {
    final json = decodeObject(text);
    return json == null ? null : ComputerTissueSnapshot.fromJson(json);
  }

  /// The JSON object [text] holds, before [fromJson] reads it: null for
  /// null and blank text, a [FormatException] when it is not a JSON object.
  /// For readers that need the raw keys, such as `LegacyTissueScalars`.
  static Map<String, dynamic>? decodeObject(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw FormatException('computer tissue JSON is malformed: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('computer tissue JSON is not an object');
    }
    return decoded;
  }

  /// [decode] that answers null instead of throwing. For the storage read
  /// path, where one unreadable column must not take the dive with it.
  static ComputerTissueSnapshot? tryDecode(String? text) {
    try {
      return decode(text);
    } on FormatException {
      return null;
    }
  }

  /// Coerces what an import map may hold under `'computerTissue'`: a
  /// snapshot, a JSON object, or JSON text. Anything else is null.
  static ComputerTissueSnapshot? from(Object? value) => switch (value) {
    ComputerTissueSnapshot() => value,
    Map<String, dynamic>() => ComputerTissueSnapshot.fromJson(value),
    String() => tryDecode(value),
    _ => null,
  };

  @override
  List<Object?> get props => [start, end];
}

/// One instant's tissue state as the computer reported it. Every field is
/// optional; a source fills what it has.
class ComputerTissueState extends Equatable {
  const ComputerTissueState({
    this.n2Bar,
    this.heBar,
    this.loadPercent,
    this.n2LoadPercent,
    this.gf99Percent,
    this.surfaceGfPercent,
    this.rgbmNitrogen,
    this.rgbmHelium,
  });

  /// Per-compartment inert N2 tension, bar.
  final List<double>? n2Bar;

  /// Per-compartment He tension, bar.
  final List<double>? heBar;

  /// Per-compartment loading, percent (Ratio iX3M).
  final List<double>? loadPercent;

  /// Aggregate N2 loading, percent (Garmin start_n2 / end_n2).
  final double? n2LoadPercent;

  /// GF99 at that instant, percent (Shearwater EndGF99).
  final double? gf99Percent;

  /// Surface GF, percent (Shearwater startGFS).
  final double? surfaceGfPercent;

  /// Suunto RGBM factors.
  final double? rgbmNitrogen;
  final double? rgbmHelium;

  /// Number of compartments, from the tensions first and the loading
  /// percentages otherwise; null when neither is present.
  int? get compartmentCount => n2Bar?.length ?? loadPercent?.length;

  bool get hasCompartments => (compartmentCount ?? 0) > 0;

  ComputerTissueState copyWith({
    List<double>? n2Bar,
    List<double>? heBar,
    List<double>? loadPercent,
    double? n2LoadPercent,
    double? gf99Percent,
    double? surfaceGfPercent,
    double? rgbmNitrogen,
    double? rgbmHelium,
  }) {
    return ComputerTissueState(
      n2Bar: n2Bar ?? this.n2Bar,
      heBar: heBar ?? this.heBar,
      loadPercent: loadPercent ?? this.loadPercent,
      n2LoadPercent: n2LoadPercent ?? this.n2LoadPercent,
      gf99Percent: gf99Percent ?? this.gf99Percent,
      surfaceGfPercent: surfaceGfPercent ?? this.surfaceGfPercent,
      rgbmNitrogen: rgbmNitrogen ?? this.rgbmNitrogen,
      rgbmHelium: rgbmHelium ?? this.rgbmHelium,
    );
  }

  /// JSON object with only the non-null fields, snake_case keys.
  Map<String, dynamic> toJson() => {
    if (n2Bar != null) 'n2_bar': n2Bar,
    if (heBar != null) 'he_bar': heBar,
    if (loadPercent != null) 'load_percent': loadPercent,
    if (n2LoadPercent != null) 'n2_load_percent': n2LoadPercent,
    if (gf99Percent != null) 'gf99_percent': gf99Percent,
    if (surfaceGfPercent != null) 'surface_gf_percent': surfaceGfPercent,
    if (rgbmNitrogen != null) 'rgbm_nitrogen': rgbmNitrogen,
    if (rgbmHelium != null) 'rgbm_helium': rgbmHelium,
  };

  /// Reads [toJson]'s shape. A missing key or a non-numeric value reads as
  /// null; a list with any non-numeric element reads as null as a whole,
  /// because compartment order is positional and a list with a hole is
  /// not a shorter list. Never throws.
  factory ComputerTissueState.fromJson(Map<String, dynamic> json) {
    return ComputerTissueState(
      n2Bar: _doubleListOf(json['n2_bar']),
      heBar: _doubleListOf(json['he_bar']),
      loadPercent: _doubleListOf(json['load_percent']),
      n2LoadPercent: asDoubleOrNull(json['n2_load_percent']),
      gf99Percent: asDoubleOrNull(json['gf99_percent']),
      surfaceGfPercent: asDoubleOrNull(json['surface_gf_percent']),
      rgbmNitrogen: asDoubleOrNull(json['rgbm_nitrogen']),
      rgbmHelium: asDoubleOrNull(json['rgbm_helium']),
    );
  }

  static List<double>? _doubleListOf(Object? value) {
    if (value is! List) return null;
    final values = <double>[];
    for (final element in value) {
      final number = asDoubleOrNull(element);
      if (number == null) return null;
      values.add(number);
    }
    return List.unmodifiable(values);
  }

  @override
  List<Object?> get props => [
    n2Bar,
    heBar,
    loadPercent,
    n2LoadPercent,
    gf99Percent,
    surfaceGfPercent,
    rgbmNitrogen,
    rgbmHelium,
  ];
}
