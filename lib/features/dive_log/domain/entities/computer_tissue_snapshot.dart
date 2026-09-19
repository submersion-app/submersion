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
class ComputerTissueSnapshot extends Equatable {
  const ComputerTissueSnapshot({this.algorithm, this.start, this.end});

  /// Raw model name from the source, e.g. 'Suunto Fused2 RGBM', 'zhl_16c',
  /// 'buhlmann'. Not normalised.
  final String? algorithm;

  /// State at dive start (residual loading from earlier dives).
  final ComputerTissueState? start;

  /// State at dive end.
  final ComputerTissueState? end;

  /// Whether the end state (or, failing that, the start state) carries
  /// per-compartment values.
  bool get hasCompartmentData => (end ?? start)?.hasCompartments ?? false;

  ComputerTissueSnapshot copyWith({
    String? algorithm,
    ComputerTissueState? start,
    ComputerTissueState? end,
  }) {
    return ComputerTissueSnapshot(
      algorithm: algorithm ?? this.algorithm,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  /// JSON object with only the non-null fields.
  Map<String, dynamic> toJson() => {
    if (algorithm != null) 'algorithm': algorithm,
    if (start != null) 'start': start!.toJson(),
    if (end != null) 'end': end!.toJson(),
  };

  /// Reads [toJson]'s shape. Missing keys and malformed values read as
  /// null; this never throws on a map.
  factory ComputerTissueSnapshot.fromJson(Map<String, dynamic> json) {
    final algorithm = json['algorithm'];
    return ComputerTissueSnapshot(
      algorithm: algorithm is String ? algorithm : null,
      start: _stateOf(json['start']),
      end: _stateOf(json['end']),
    );
  }

  static ComputerTissueState? _stateOf(Object? value) =>
      value is Map<String, dynamic>
      ? ComputerTissueState.fromJson(value)
      : null;

  /// The JSON text the database column stores.
  String encode() => jsonEncode(toJson());

  /// Reads [encode]'s output. Null and blank text read as null (the column
  /// is nullable). Throws [FormatException] when [text] is not a JSON
  /// object; malformed values inside the object read as null.
  static ComputerTissueSnapshot? decode(String? text) {
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
    return ComputerTissueSnapshot.fromJson(decoded);
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
  List<Object?> get props => [algorithm, start, end];
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
    this.cnsPercent,
    this.otu,
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

  final double? cnsPercent;
  final double? otu;

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
    double? cnsPercent,
    double? otu,
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
      cnsPercent: cnsPercent ?? this.cnsPercent,
      otu: otu ?? this.otu,
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
    if (cnsPercent != null) 'cns_percent': cnsPercent,
    if (otu != null) 'otu': otu,
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
      cnsPercent: asDoubleOrNull(json['cns_percent']),
      otu: asDoubleOrNull(json['otu']),
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
    cnsPercent,
    otu,
    rgbmNitrogen,
    rgbmHelium,
  ];
}
