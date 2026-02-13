import 'package:equatable/equatable.dart';

/// Where a backup is stored
enum BackupLocation { local, cloud, both }

/// A record of a single backup snapshot
class BackupRecord extends Equatable {
  final String id;
  final String filename;
  final DateTime timestamp;
  final int sizeBytes;
  final BackupLocation location;
  final int diveCount;
  final int siteCount;
  final String? cloudFileId;
  final String? localPath;
  final bool isAutomatic;

  const BackupRecord({
    required this.id,
    required this.filename,
    required this.timestamp,
    required this.sizeBytes,
    required this.location,
    required this.diveCount,
    required this.siteCount,
    this.cloudFileId,
    this.localPath,
    this.isAutomatic = false,
  });

  BackupRecord copyWith({
    String? id,
    String? filename,
    DateTime? timestamp,
    int? sizeBytes,
    BackupLocation? location,
    int? diveCount,
    int? siteCount,
    String? cloudFileId,
    String? localPath,
    bool? isAutomatic,
  }) {
    return BackupRecord(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      timestamp: timestamp ?? this.timestamp,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      location: location ?? this.location,
      diveCount: diveCount ?? this.diveCount,
      siteCount: siteCount ?? this.siteCount,
      cloudFileId: cloudFileId ?? this.cloudFileId,
      localPath: localPath ?? this.localPath,
      isAutomatic: isAutomatic ?? this.isAutomatic,
    );
  }

  /// Formatted file size for display (e.g., "2.3 MB")
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'sizeBytes': sizeBytes,
      'location': location.name,
      'diveCount': diveCount,
      'siteCount': siteCount,
      'cloudFileId': cloudFileId,
      'localPath': localPath,
      'isAutomatic': isAutomatic,
    };
  }

  factory BackupRecord.fromJson(Map<String, dynamic> json) {
    return BackupRecord(
      id: json['id'] as String,
      filename: json['filename'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      sizeBytes: json['sizeBytes'] as int,
      location: BackupLocation.values.byName(json['location'] as String),
      diveCount: json['diveCount'] as int,
      siteCount: json['siteCount'] as int,
      cloudFileId: json['cloudFileId'] as String?,
      localPath: json['localPath'] as String?,
      isAutomatic: json['isAutomatic'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    id,
    filename,
    timestamp,
    sizeBytes,
    location,
    diveCount,
    siteCount,
    cloudFileId,
    localPath,
    isAutomatic,
  ];
}
