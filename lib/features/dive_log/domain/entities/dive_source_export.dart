import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// One stored depth series as a backup writes it: its identity columns and
/// its `ProfileSeriesCodec` blob, as stored (issue #3965).
///
/// The blob rather than the samples, since nothing in an export reads them
/// and a logbook of two-computer dives holds millions. It is never decoded on
/// the way out.
class SourceSeriesExport extends Equatable {
  const SourceSeriesExport({
    required this.blob,
    required this.isPrimary,
    this.sourceId,
    this.computerId,
  });

  final Uint8List blob;
  final bool isPrimary;

  /// The row this series names, or null when it names none. A surface filler
  /// a Combine synthesized owns no recording, and a restore must not give it
  /// one, so this can differ from the row holding the series.
  final String? sourceId;
  final String? computerId;

  @override
  List<Object?> get props => [blob, isPrimary, sourceId, computerId];
}

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
    this.profileSeries = const [],
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

  /// The depth series the app shows under this row on a dive with two or more
  /// rows (issue #3965). A backup needs them because `<samples>` holds every
  /// source interleaved; nothing in a UDDF document could take that stream
  /// apart again. Empty on a lone row, which owns every sample anyway.
  final List<SourceSeriesExport> profileSeries;

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
    profileSeries,
  ];
}
