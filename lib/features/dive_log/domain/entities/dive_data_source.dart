import 'package:equatable/equatable.dart';

class DiveDataSource extends Equatable {
  final String id;
  final String diveId;
  final String? computerId;
  final bool isPrimary;
  final String? computerModel;

  /// The linked dive computer's user-assigned friendly name (e.g. "My
  /// Perdix"), resolved live from the registered computer via [computerId].
  /// Null when the source has no linked computer (manual/file imports, or a
  /// since-deleted computer); callers fall back to [computerModel].
  final String? computerName;
  final String? computerSerial;
  final String? sourceFormat;
  final String? sourceFileName;
  final String? sourceFileFormat;
  final double? maxDepth;
  final double? avgDepth;
  final int? duration;
  final double? waterTemp;
  final double? entryLatitude;
  final double? entryLongitude;
  final double? exitLatitude;
  final double? exitLongitude;
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

  const DiveDataSource({
    required this.id,
    required this.diveId,
    this.computerId,
    required this.isPrimary,
    this.computerModel,
    this.computerName,
    this.computerSerial,
    this.sourceFormat,
    this.sourceFileName,
    this.sourceFileFormat,
    this.maxDepth,
    this.avgDepth,
    this.duration,
    this.waterTemp,
    this.entryLatitude,
    this.entryLongitude,
    this.exitLatitude,
    this.exitLongitude,
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

  /// Display name for the data source: the linked computer's friendly name
  /// when known, else the model snapshot, else "Unknown Source".
  String get displayName => computerName ?? computerModel ?? 'Unknown Source';

  /// Label for this source's computer, preferring the friendly name, then the
  /// model, then the serial, then the caller-supplied [unknownLabel]. Used
  /// where a localized "unknown" fallback is needed (e.g. the profile chart's
  /// per-computer legend).
  String computerLabel(String unknownLabel) =>
      computerName ?? computerModel ?? computerSerial ?? unknownLabel;

  DiveDataSource copyWith({
    String? id,
    String? diveId,
    String? computerId,
    bool? isPrimary,
    String? computerModel,
    String? computerName,
    String? computerSerial,
    String? sourceFormat,
    String? sourceFileName,
    String? sourceFileFormat,
    double? maxDepth,
    double? avgDepth,
    int? duration,
    double? waterTemp,
    double? entryLatitude,
    double? entryLongitude,
    double? exitLatitude,
    double? exitLongitude,
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
    return DiveDataSource(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      computerId: computerId ?? this.computerId,
      isPrimary: isPrimary ?? this.isPrimary,
      computerModel: computerModel ?? this.computerModel,
      computerName: computerName ?? this.computerName,
      computerSerial: computerSerial ?? this.computerSerial,
      sourceFormat: sourceFormat ?? this.sourceFormat,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      sourceFileFormat: sourceFileFormat ?? this.sourceFileFormat,
      maxDepth: maxDepth ?? this.maxDepth,
      avgDepth: avgDepth ?? this.avgDepth,
      duration: duration ?? this.duration,
      waterTemp: waterTemp ?? this.waterTemp,
      entryLatitude: entryLatitude ?? this.entryLatitude,
      entryLongitude: entryLongitude ?? this.entryLongitude,
      exitLatitude: exitLatitude ?? this.exitLatitude,
      exitLongitude: exitLongitude ?? this.exitLongitude,
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
    computerName,
    computerSerial,
    sourceFormat,
    sourceFileName,
    sourceFileFormat,
    maxDepth,
    avgDepth,
    duration,
    waterTemp,
    entryLatitude,
    entryLongitude,
    exitLatitude,
    exitLongitude,
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
