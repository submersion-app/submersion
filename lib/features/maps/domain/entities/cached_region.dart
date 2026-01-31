import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// Represents a downloaded offline map region.
class CachedRegion extends Equatable {
  final String id;
  final String name;
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
  final int minZoom;
  final int maxZoom;
  final int tileCount;
  final int sizeBytes;
  final DateTime createdAt;
  final DateTime lastAccessedAt;

  const CachedRegion({
    required this.id,
    required this.name,
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
    required this.minZoom,
    required this.maxZoom,
    required this.tileCount,
    required this.sizeBytes,
    required this.createdAt,
    required this.lastAccessedAt,
  });

  /// Get the bounds as a LatLngBounds-compatible structure.
  LatLng get southWest => LatLng(minLat, minLng);
  LatLng get northEast => LatLng(maxLat, maxLng);
  LatLng get center => LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

  /// Human-readable size string.
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  CachedRegion copyWith({
    String? id,
    String? name,
    double? minLat,
    double? maxLat,
    double? minLng,
    double? maxLng,
    int? minZoom,
    int? maxZoom,
    int? tileCount,
    int? sizeBytes,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
  }) {
    return CachedRegion(
      id: id ?? this.id,
      name: name ?? this.name,
      minLat: minLat ?? this.minLat,
      maxLat: maxLat ?? this.maxLat,
      minLng: minLng ?? this.minLng,
      maxLng: maxLng ?? this.maxLng,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      tileCount: tileCount ?? this.tileCount,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    minLat,
    maxLat,
    minLng,
    maxLng,
    minZoom,
    maxZoom,
    tileCount,
    sizeBytes,
    createdAt,
    lastAccessedAt,
  ];
}
