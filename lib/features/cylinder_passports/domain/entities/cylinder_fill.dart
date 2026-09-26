import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// How a fill record reached this database (spec section 10.2).
enum FillSource {
  manual,
  qr,
  nfc,
  file,
  link,
  issued;

  static FillSource fromName(String? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return FillSource.manual;
  }
}

/// One fill of one physical cylinder, keyed by its passport id rather than
/// its equipment row so the history survives a deleted and re-created item
/// and can belong to a cylinder the diver does not own.
///
/// When [signedRecord] is present the analysis fields are copies of the
/// verified payload; the token is the truth. Verification is never stored
/// (spec section 10.2).
class CylinderFill extends Equatable {
  final String id;
  final String? diverId;
  final String passportId;
  final String? equipmentId;
  final DateTime filledAt;
  final double o2Percent;
  final double hePercent;
  final double? pressureBar;
  final double? temperatureC;
  final String? analyzer;
  final String? stationName;
  final String? stationKey;
  final String? signedRecord;
  final FillSource source;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CylinderFill({
    required this.id,
    this.diverId,
    required this.passportId,
    this.equipmentId,
    required this.filledAt,
    required this.o2Percent,
    this.hePercent = 0,
    this.pressureBar,
    this.temperatureC,
    this.analyzer,
    this.stationName,
    this.stationKey,
    this.signedRecord,
    this.source = FillSource.manual,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  GasMix get gasMix => GasMix(o2: o2Percent, he: hePercent);

  bool get isSigned => signedRecord != null && signedRecord!.isNotEmpty;

  CylinderFill copyWith({
    String? id,
    String? diverId,
    bool clearDiverId = false,
    String? passportId,
    String? equipmentId,
    bool clearEquipmentId = false,
    DateTime? filledAt,
    double? o2Percent,
    double? hePercent,
    double? pressureBar,
    bool clearPressureBar = false,
    double? temperatureC,
    bool clearTemperatureC = false,
    String? analyzer,
    bool clearAnalyzer = false,
    String? stationName,
    bool clearStationName = false,
    String? stationKey,
    bool clearStationKey = false,
    String? signedRecord,
    bool clearSignedRecord = false,
    FillSource? source,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CylinderFill(
    id: id ?? this.id,
    diverId: clearDiverId ? null : (diverId ?? this.diverId),
    passportId: passportId ?? this.passportId,
    equipmentId: clearEquipmentId ? null : (equipmentId ?? this.equipmentId),
    filledAt: filledAt ?? this.filledAt,
    o2Percent: o2Percent ?? this.o2Percent,
    hePercent: hePercent ?? this.hePercent,
    pressureBar: clearPressureBar ? null : (pressureBar ?? this.pressureBar),
    temperatureC: clearTemperatureC
        ? null
        : (temperatureC ?? this.temperatureC),
    analyzer: clearAnalyzer ? null : (analyzer ?? this.analyzer),
    stationName: clearStationName ? null : (stationName ?? this.stationName),
    stationKey: clearStationKey ? null : (stationKey ?? this.stationKey),
    signedRecord: clearSignedRecord
        ? null
        : (signedRecord ?? this.signedRecord),
    source: source ?? this.source,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Timestamps are excluded: they churn on every write and would defeat
  /// Riverpod's equality-based rebuild suppression. Mirrors Transmitter.
  @override
  List<Object?> get props => [
    id,
    diverId,
    passportId,
    equipmentId,
    filledAt,
    o2Percent,
    hePercent,
    pressureBar,
    temperatureC,
    analyzer,
    stationName,
    stationKey,
    signedRecord,
    source,
    notes,
  ];
}
