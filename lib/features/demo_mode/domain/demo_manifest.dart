import 'dart:convert';

import 'package:equatable/equatable.dart';

final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

/// One published sample logbook: a zip holding the demo database built at
/// [schemaVersion] and its photos.
class DemoPackage extends Equatable {
  const DemoPackage({
    required this.schemaVersion,
    required this.url,
    required this.sha256,
    required this.size,
    required this.generatedAt,
  });

  final int schemaVersion;
  final Uri url;

  /// Lowercase hex SHA-256 of the zip, checked before the zip is used.
  final String sha256;

  /// Size of the zip in bytes.
  final int size;

  final DateTime generatedAt;

  /// Throws [FormatException] when [json] is not a valid package entry.
  factory DemoPackage.fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'];
    final url = Uri.tryParse(json['url'] as String? ?? '');
    final sha = json['sha256'];
    final size = json['size'];
    final generatedAt = DateTime.tryParse(json['generatedAt'] as String? ?? '');
    if (schemaVersion is! int ||
        url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        sha is! String ||
        !_sha256Pattern.hasMatch(sha) ||
        size is! int ||
        size <= 0 ||
        generatedAt == null) {
      throw FormatException('Invalid demo package: $json');
    }
    return DemoPackage(
      schemaVersion: schemaVersion,
      url: url,
      sha256: sha,
      size: size,
      generatedAt: generatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'url': url.toString(),
    'sha256': sha256,
    'size': size,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
  };

  @override
  List<Object?> get props => [schemaVersion, url, sha256, size, generatedAt];
}

/// The list of published sample logbooks, one per schema version they were
/// built at, served next to them on the `demo-data` release.
class DemoManifest extends Equatable {
  const DemoManifest({required this.formatVersion, required this.packages});

  static const currentFormatVersion = 1;

  final int formatVersion;
  final List<DemoPackage> packages;

  /// Parses [source], returning null for anything malformed or for a format
  /// version this build does not understand.
  static DemoManifest? tryParse(String source) {
    try {
      final json = jsonDecode(source);
      if (json is! Map<String, Object?>) return null;
      if (json['formatVersion'] != currentFormatVersion) return null;
      final raw = json['packages'];
      if (raw is! List) return null;
      final packages = [
        for (final entry in raw)
          DemoPackage.fromJson((entry as Map).cast<String, Object?>()),
      ];
      return DemoManifest(
        formatVersion: currentFormatVersion,
        packages: List.unmodifiable(packages),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// The newest package this app can open: built at a schema no newer than
  /// [appSchemaVersion]. A newer app upgrades an older file through the normal
  /// migrations; an older app can never open a newer file.
  DemoPackage? bestFor(int appSchemaVersion) {
    DemoPackage? best;
    for (final p in packages) {
      if (p.schemaVersion > appSchemaVersion) continue;
      if (best == null || p.schemaVersion > best.schemaVersion) best = p;
    }
    return best;
  }

  @override
  List<Object?> get props => [formatVersion, packages];
}
