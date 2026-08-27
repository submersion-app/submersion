import 'package:equatable/equatable.dart';

import 'package:submersion/features/backup/domain/entities/backup_type.dart';

/// Where a backup is stored
enum BackupLocation { local, cloud, both }

/// A record of a single backup snapshot
class BackupRecord extends Equatable {
  final String id;
  final String filename;
  final DateTime timestamp;
  final int sizeBytes;
  final BackupLocation location;
  final int? diveCount;
  final int? siteCount;
  final String? cloudFileId;
  final String? localPath;
  final bool isAutomatic;
  final BackupType type;
  final String? appVersion;
  final int? fromSchemaVersion;
  final int? toSchemaVersion;
  final bool pinned;

  const BackupRecord({
    required this.id,
    required this.filename,
    required this.timestamp,
    required this.sizeBytes,
    required this.location,
    this.diveCount,
    this.siteCount,
    this.cloudFileId,
    this.localPath,
    this.isAutomatic = false,
    this.type = BackupType.manual,
    this.appVersion,
    this.fromSchemaVersion,
    this.toSchemaVersion,
    this.pinned = false,
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
    BackupType? type,
    String? appVersion,
    int? fromSchemaVersion,
    int? toSchemaVersion,
    bool? pinned,
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
      type: type ?? this.type,
      appVersion: appVersion ?? this.appVersion,
      fromSchemaVersion: fromSchemaVersion ?? this.fromSchemaVersion,
      toSchemaVersion: toSchemaVersion ?? this.toSchemaVersion,
      pinned: pinned ?? this.pinned,
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
      'type': type.name,
      'appVersion': appVersion,
      'fromSchemaVersion': fromSchemaVersion,
      'toSchemaVersion': toSchemaVersion,
      'pinned': pinned,
    };
  }

  factory BackupRecord.fromJson(Map<String, dynamic> json) {
    return BackupRecord(
      id: json['id'] as String,
      filename: json['filename'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      sizeBytes: json['sizeBytes'] as int,
      location: BackupLocation.values.byName(json['location'] as String),
      diveCount: json['diveCount'] as int?,
      siteCount: json['siteCount'] as int?,
      cloudFileId: json['cloudFileId'] as String?,
      localPath: json['localPath'] as String?,
      isAutomatic: json['isAutomatic'] as bool? ?? false,
      type: _parseType(json['type'] as String?),
      appVersion: json['appVersion'] as String?,
      fromSchemaVersion: json['fromSchemaVersion'] as int?,
      toSchemaVersion: json['toSchemaVersion'] as int?,
      pinned: json['pinned'] as bool? ?? false,
    );
  }

  static BackupType _parseType(String? value) {
    if (value == null) return BackupType.manual;
    return BackupType.values.asNameMap()[value] ?? BackupType.manual;
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
    type,
    appVersion,
    fromSchemaVersion,
    toSchemaVersion,
    pinned,
  ];
}
