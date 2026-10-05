import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';

/// What the Review step tells the diver about where an import came from
/// (issue #161): which computer, which file, or which account.
///
/// Adapters fill in what they know and leave the rest null. Every field is
/// raw data, never display text: the Review step localizes and formats it,
/// and leaves out anything absent.
class ImportSourceDetails extends Equatable {
  /// The source's own name: the computer's name, the picked file's name, or
  /// a service's brand. Null falls back to the bundle's display name, or to
  /// a file count when [fileCount] says this is a batch.
  final String? title;

  /// The computer's manufacturer and model, e.g. "Shearwater Perdix 2".
  final String? model;

  /// The computer's serial number.
  final String? serialNumber;

  /// The firmware version the computer reported.
  final String? firmwareVersion;

  /// How the computer was connected for this download.
  final DeviceConnectionType? connection;

  /// How many files a batch import read. Null or 1 for a single file.
  final int? fileCount;

  /// The detected file formats, by display name, without repeats.
  final List<String> formats;

  /// The application the files came from, when detection identified one.
  final String? sourceApp;

  /// The total size of the imported files, in bytes.
  final int? sizeBytes;

  /// The signed-in account of a cloud service.
  final String? account;

  /// The first day of the range a HealthKit import read.
  final DateTime? rangeStart;

  /// The last day of the range a HealthKit import read.
  final DateTime? rangeEnd;

  /// The models of the devices that recorded a cloud import's dives.
  final List<String> deviceModels;

  const ImportSourceDetails({
    this.title,
    this.model,
    this.serialNumber,
    this.firmwareVersion,
    this.connection,
    this.fileCount,
    this.formats = const [],
    this.sourceApp,
    this.sizeBytes,
    this.account,
    this.rangeStart,
    this.rangeEnd,
    this.deviceModels = const [],
  });

  ImportSourceDetails copyWith({
    String? title,
    String? model,
    String? serialNumber,
    String? firmwareVersion,
    DeviceConnectionType? connection,
    int? fileCount,
    List<String>? formats,
    String? sourceApp,
    int? sizeBytes,
    String? account,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    List<String>? deviceModels,
  }) => ImportSourceDetails(
    title: title ?? this.title,
    model: model ?? this.model,
    serialNumber: serialNumber ?? this.serialNumber,
    firmwareVersion: firmwareVersion ?? this.firmwareVersion,
    connection: connection ?? this.connection,
    fileCount: fileCount ?? this.fileCount,
    formats: formats ?? this.formats,
    sourceApp: sourceApp ?? this.sourceApp,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    account: account ?? this.account,
    rangeStart: rangeStart ?? this.rangeStart,
    rangeEnd: rangeEnd ?? this.rangeEnd,
    deviceModels: deviceModels ?? this.deviceModels,
  );

  @override
  List<Object?> get props => [
    title,
    model,
    serialNumber,
    firmwareVersion,
    connection,
    fileCount,
    formats,
    sourceApp,
    sizeBytes,
    account,
    rangeStart,
    rangeEnd,
    deviceModels,
  ];
}
