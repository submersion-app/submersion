import 'package:equatable/equatable.dart';

class DiveComputerReading extends Equatable {
  final String id;
  final String diveId;
  final String? computerId;
  final bool isPrimary;
  final String? computerModel;
  final String? computerSerial;
  final String? sourceFormat;
  final double? maxDepth;
  final double? avgDepth;
  final int? duration;
  final double? waterTemp;
  final DateTime? entryTime;
  final DateTime? exitTime;
  final double? maxAscentRate;
  final double? maxDescentRate;
  final int? surfaceInterval;
  final double? cns;
  final double? otu;
  final String? decoAlgorithm;
  final int? gradientFactorLow;
  final int? gradientFactorHigh;
  final DateTime importedAt;
  final DateTime createdAt;

  const DiveComputerReading({
    required this.id,
    required this.diveId,
    this.computerId,
    required this.isPrimary,
    this.computerModel,
    this.computerSerial,
    this.sourceFormat,
    this.maxDepth,
    this.avgDepth,
    this.duration,
    this.waterTemp,
    this.entryTime,
    this.exitTime,
    this.maxAscentRate,
    this.maxDescentRate,
    this.surfaceInterval,
    this.cns,
    this.otu,
    this.decoAlgorithm,
    this.gradientFactorLow,
    this.gradientFactorHigh,
    required this.importedAt,
    required this.createdAt,
  });

  /// Display name for the computer (model, or "Unknown Computer").
  String get displayName => computerModel ?? 'Unknown Computer';

  DiveComputerReading copyWith({
    String? id,
    String? diveId,
    String? computerId,
    bool? isPrimary,
    String? computerModel,
    String? computerSerial,
    String? sourceFormat,
    double? maxDepth,
    double? avgDepth,
    int? duration,
    double? waterTemp,
    DateTime? entryTime,
    DateTime? exitTime,
    double? maxAscentRate,
    double? maxDescentRate,
    int? surfaceInterval,
    double? cns,
    double? otu,
    String? decoAlgorithm,
    int? gradientFactorLow,
    int? gradientFactorHigh,
    DateTime? importedAt,
    DateTime? createdAt,
  }) {
    return DiveComputerReading(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      computerId: computerId ?? this.computerId,
      isPrimary: isPrimary ?? this.isPrimary,
      computerModel: computerModel ?? this.computerModel,
      computerSerial: computerSerial ?? this.computerSerial,
      sourceFormat: sourceFormat ?? this.sourceFormat,
      maxDepth: maxDepth ?? this.maxDepth,
      avgDepth: avgDepth ?? this.avgDepth,
      duration: duration ?? this.duration,
      waterTemp: waterTemp ?? this.waterTemp,
      entryTime: entryTime ?? this.entryTime,
      exitTime: exitTime ?? this.exitTime,
      maxAscentRate: maxAscentRate ?? this.maxAscentRate,
      maxDescentRate: maxDescentRate ?? this.maxDescentRate,
      surfaceInterval: surfaceInterval ?? this.surfaceInterval,
      cns: cns ?? this.cns,
      otu: otu ?? this.otu,
      decoAlgorithm: decoAlgorithm ?? this.decoAlgorithm,
      gradientFactorLow: gradientFactorLow ?? this.gradientFactorLow,
      gradientFactorHigh: gradientFactorHigh ?? this.gradientFactorHigh,
      importedAt: importedAt ?? this.importedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveId,
    computerId,
    isPrimary,
    computerModel,
    computerSerial,
    sourceFormat,
    maxDepth,
    avgDepth,
    duration,
    waterTemp,
    entryTime,
    exitTime,
    maxAscentRate,
    maxDescentRate,
    surfaceInterval,
    cns,
    otu,
    decoAlgorithm,
    gradientFactorLow,
    gradientFactorHigh,
    importedAt,
    createdAt,
  ];
}
