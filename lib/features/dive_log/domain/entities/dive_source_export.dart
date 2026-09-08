import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// One `dive_data_sources` row as the UDDF exporter needs to see it.
///
/// This is the whole row rather than just the bytes. A UDDF `<dive>` carries
/// only the consolidated values, so the per-source snapshot (max depth, cns,
/// deco algorithm, entry and exit) exists nowhere else in the document, and a
/// restore that dropped it would be lossless only about the blob.
///
/// [ordinal] is this row's position among its own dive's rows in the order the
/// repository returned them. It is what pairs a `<source>` entry with its
/// `<divecomputerdump>`, because `<divecomputerdump>` accepts no attributes at
/// all and so cannot carry an id of its own.
class DiveSourceExport extends Equatable {
  const DiveSourceExport({
    required this.id,
    required this.diveId,
    required this.ordinal,
    required this.isPrimary,
    required this.importedAt,
    required this.createdAt,
    this.rawData,
    this.rawFingerprint,
    this.computerId,
    this.computerModel,
    this.computerSerial,
    this.sourceFormat,
    this.sourceFileName,
    this.sourceFileFormat,
    this.sourceUuid,
    this.descriptorVendor,
    this.descriptorProduct,
    this.descriptorModel,
    this.libdivecomputerVersion,
    this.mergeSourceSlot,
    this.timeOffsetSeconds,
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
    this.lastParsedAt,
  });

  final String id;
  final String diveId;
  final int ordinal;
  final bool isPrimary;
  final DateTime importedAt;
  final DateTime createdAt;

  final Uint8List? rawData;
  final Uint8List? rawFingerprint;

  final String? computerId;
  final String? computerModel;
  final String? computerSerial;
  final String? sourceFormat;
  final String? sourceFileName;
  final String? sourceFileFormat;
  final String? sourceUuid;

  final String? descriptorVendor;
  final String? descriptorProduct;
  final int? descriptorModel;
  final String? libdivecomputerVersion;

  final int? mergeSourceSlot;
  final int? timeOffsetSeconds;

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
  final DateTime? lastParsedAt;

  /// Whether this row contributes a `<dcdump>` to the export.
  bool get hasDump => rawData != null && rawData!.isNotEmpty;

  @override
  List<Object?> get props => [
    id,
    diveId,
    ordinal,
    isPrimary,
    importedAt,
    createdAt,
    rawData,
    rawFingerprint,
    computerId,
    computerModel,
    computerSerial,
    sourceFormat,
    sourceFileName,
    sourceFileFormat,
    sourceUuid,
    descriptorVendor,
    descriptorProduct,
    descriptorModel,
    libdivecomputerVersion,
    mergeSourceSlot,
    timeOffsetSeconds,
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
    lastParsedAt,
  ];
}
