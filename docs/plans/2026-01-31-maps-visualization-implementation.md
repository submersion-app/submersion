# Maps & Visualization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add offline map tile caching with region downloads and gradient heat map visualizations for dive activity and site coverage.

**Architecture:** Feature module at `lib/features/maps/` with Riverpod providers, custom tile provider for caching via `flutter_map_tile_caching` package, and canvas-based heat map rendering using `CustomPainter`.

**Tech Stack:** Flutter, flutter_map, flutter_map_tile_caching, Riverpod, Drift ORM, CustomPainter

---

## Phase 1: Offline Maps Infrastructure

### Task 1.1: Add flutter_map_tile_caching dependency

**Files:**
- Modify: `pubspec.yaml`

**Step 1: Add the dependency**

Add to `pubspec.yaml` under dependencies:

```yaml
  # Map tile caching for offline use
  flutter_map_tile_caching: ^9.1.0
```

**Step 2: Run pub get**

Run: `flutter pub get`
Expected: Dependencies resolve successfully

**Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat(maps): add flutter_map_tile_caching dependency"
```

---

### Task 1.2: Create CachedRegion entity

**Files:**
- Create: `lib/features/maps/domain/entities/cached_region.dart`

**Step 1: Create the entity file**

```dart
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
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
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
```

**Step 2: Commit**

```bash
git add lib/features/maps/domain/entities/cached_region.dart
git commit -m "feat(maps): add CachedRegion entity"
```

---

### Task 1.3: Add cached_regions table to database

**Files:**
- Modify: `lib/core/database/database.dart`

**Step 1: Add the table definition**

Add after the `DeletionLog` table definition (around line 860):

```dart
/// Cached map regions for offline use
class CachedRegions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get minLat => real()();
  RealColumn get maxLat => real()();
  RealColumn get minLng => real()();
  RealColumn get maxLng => real()();
  IntColumn get minZoom => integer()();
  IntColumn get maxZoom => integer()();
  IntColumn get tileCount => integer()();
  IntColumn get sizeBytes => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get lastAccessedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Step 2: Add table to @DriftDatabase annotation**

Add `CachedRegions` to the tables list in the `@DriftDatabase` annotation.

**Step 3: Increment schema version and add migration**

Change `schemaVersion` from 20 to 21.

Add migration in `onUpgrade`:

```dart
if (from < 21) {
  // Cached map regions for offline maps feature
  await customStatement('''
    CREATE TABLE IF NOT EXISTS cached_regions (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      min_lat REAL NOT NULL,
      max_lat REAL NOT NULL,
      min_lng REAL NOT NULL,
      max_lng REAL NOT NULL,
      min_zoom INTEGER NOT NULL,
      max_zoom INTEGER NOT NULL,
      tile_count INTEGER NOT NULL,
      size_bytes INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      last_accessed_at INTEGER NOT NULL
    )
  ''');
}
```

**Step 4: Run build_runner**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: database.g.dart regenerated successfully

**Step 5: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat(maps): add cached_regions table for offline maps"
```

---

### Task 1.4: Create OfflineMapRepository

**Files:**
- Create: `lib/features/maps/data/repositories/offline_map_repository.dart`

**Step 1: Create the repository**

```dart
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/maps/domain/entities/cached_region.dart';
import 'package:uuid/uuid.dart';

/// Repository for managing cached map regions.
class OfflineMapRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  OfflineMapRepository(this._db);

  /// Get all cached regions.
  Future<List<CachedRegion>> getAllRegions() async {
    final rows = await _db.select(_db.cachedRegions).get();
    return rows.map(_rowToEntity).toList();
  }

  /// Get a cached region by ID.
  Future<CachedRegion?> getRegionById(String id) async {
    final row = await (_db.select(_db.cachedRegions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _rowToEntity(row) : null;
  }

  /// Create a new cached region record.
  Future<CachedRegion> createRegion({
    required String name,
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required int minZoom,
    required int maxZoom,
    required int tileCount,
    required int sizeBytes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();

    await _db.into(_db.cachedRegions).insert(
          CachedRegionsCompanion.insert(
            id: id,
            name: name,
            minLat: minLat,
            maxLat: maxLat,
            minLng: minLng,
            maxLng: maxLng,
            minZoom: minZoom,
            maxZoom: maxZoom,
            tileCount: tileCount,
            sizeBytes: sizeBytes,
            createdAt: now,
            lastAccessedAt: now,
          ),
        );

    return CachedRegion(
      id: id,
      name: name,
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      minZoom: minZoom,
      maxZoom: maxZoom,
      tileCount: tileCount,
      sizeBytes: sizeBytes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      lastAccessedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  /// Update a cached region (e.g., after re-download or size change).
  Future<void> updateRegion(CachedRegion region) async {
    await (_db.update(_db.cachedRegions)
          ..where((t) => t.id.equals(region.id)))
        .write(
      CachedRegionsCompanion(
        name: Value(region.name),
        tileCount: Value(region.tileCount),
        sizeBytes: Value(region.sizeBytes),
        lastAccessedAt: Value(region.lastAccessedAt.millisecondsSinceEpoch),
      ),
    );
  }

  /// Update last accessed timestamp.
  Future<void> touchRegion(String id) async {
    await (_db.update(_db.cachedRegions)..where((t) => t.id.equals(id))).write(
      CachedRegionsCompanion(
        lastAccessedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Delete a cached region record.
  Future<void> deleteRegion(String id) async {
    await (_db.delete(_db.cachedRegions)..where((t) => t.id.equals(id))).go();
  }

  /// Get total size of all cached regions.
  Future<int> getTotalSize() async {
    final regions = await getAllRegions();
    return regions.fold<int>(0, (sum, r) => sum + r.sizeBytes);
  }

  CachedRegion _rowToEntity(CachedRegion row) {
    return CachedRegion(
      id: row.id,
      name: row.name,
      minLat: row.minLat,
      maxLat: row.maxLat,
      minLng: row.minLng,
      maxLng: row.maxLng,
      minZoom: row.minZoom,
      maxZoom: row.maxZoom,
      tileCount: row.tileCount,
      sizeBytes: row.sizeBytes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt.millisecondsSinceEpoch),
      lastAccessedAt: DateTime.fromMillisecondsSinceEpoch(row.lastAccessedAt.millisecondsSinceEpoch),
    );
  }
}
```

Note: The repository will need adjustment after code generation - the Drift generated types will be different from the domain entity.

**Step 2: Commit**

```bash
git add lib/features/maps/data/repositories/offline_map_repository.dart
git commit -m "feat(maps): add OfflineMapRepository"
```

---

### Task 1.5: Create TileCacheService

**Files:**
- Create: `lib/features/maps/data/services/tile_cache_service.dart`

**Step 1: Create the service**

```dart
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

/// Service for managing map tile caching using flutter_map_tile_caching.
class TileCacheService {
  static TileCacheService? _instance;
  static TileCacheService get instance => _instance ??= TileCacheService._();

  TileCacheService._();

  bool _initialized = false;
  FMTCStore? _store;

  /// Initialize the tile cache.
  Future<void> initialize() async {
    if (_initialized) return;

    await FMTCObjectBoxBackend().initialise();
    _store = FMTCStore('submersion_tiles');
    await _store!.manage.create();
    _initialized = true;
  }

  /// Get the tile store for use with flutter_map.
  FMTCStore get store {
    if (!_initialized || _store == null) {
      throw StateError('TileCacheService not initialized. Call initialize() first.');
    }
    return _store!;
  }

  /// Get a tile provider that caches tiles.
  FMTCTileProvider getTileProvider() {
    return store.getTileProvider();
  }

  /// Estimate the number of tiles for a region.
  Future<int> estimateTileCount({
    required LatLng southWest,
    required LatLng northEast,
    required int minZoom,
    required int maxZoom,
  }) async {
    final region = RectangleRegion(
      LatLngBounds(southWest, northEast),
    );

    return store.download.check(region.toDownloadable(
      minZoom: minZoom,
      maxZoom: maxZoom,
      options: TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      ),
    )).then((result) => result.cachedTiles + result.cachedSeaTiles);
  }

  /// Download tiles for a region.
  Stream<DownloadProgress> downloadRegion({
    required LatLng southWest,
    required LatLng northEast,
    required int minZoom,
    required int maxZoom,
  }) {
    final region = RectangleRegion(
      LatLngBounds(southWest, northEast),
    );

    return store.download.startForeground(
      region: region.toDownloadable(
        minZoom: minZoom,
        maxZoom: maxZoom,
        options: TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.submersion.app',
        ),
      ),
    );
  }

  /// Cancel an ongoing download.
  Future<void> cancelDownload() async {
    await store.download.cancel();
  }

  /// Get cache statistics.
  Future<({int tileCount, int sizeBytes})> getCacheStats() async {
    final stats = await store.stats.all;
    return (
      tileCount: stats.hits + stats.misses,
      sizeBytes: stats.size,
    );
  }

  /// Clear all cached tiles.
  Future<void> clearCache() async {
    await store.manage.reset();
  }

  /// Delete tiles for a specific region (approximate - deletes tiles in bounds).
  Future<void> deleteRegionTiles({
    required LatLng southWest,
    required LatLng northEast,
    required int minZoom,
    required int maxZoom,
  }) async {
    // flutter_map_tile_caching doesn't support region-specific deletion directly
    // For now, we track regions in the database and rely on full cache clearing
    // A more sophisticated approach would require custom tile tracking
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/maps/data/services/tile_cache_service.dart
git commit -m "feat(maps): add TileCacheService for tile caching"
```

---

### Task 1.6: Create offline map providers

**Files:**
- Create: `lib/features/maps/presentation/providers/offline_map_providers.dart`

**Step 1: Create the providers file**

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/providers/database_provider.dart';
import 'package:submersion/features/maps/data/repositories/offline_map_repository.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/domain/entities/cached_region.dart';

/// Provider for the offline map repository.
final offlineMapRepositoryProvider = Provider<OfflineMapRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return OfflineMapRepository(db);
});

/// Provider for the tile cache service.
final tileCacheServiceProvider = Provider<TileCacheService>((ref) {
  return TileCacheService.instance;
});

/// Provider for all cached regions.
final cachedRegionsProvider = FutureProvider<List<CachedRegion>>((ref) async {
  final repository = ref.watch(offlineMapRepositoryProvider);
  return repository.getAllRegions();
});

/// Provider for cache statistics.
final cacheStatsProvider = FutureProvider<({int tileCount, int sizeBytes})>((ref) async {
  final service = ref.watch(tileCacheServiceProvider);
  await service.initialize();
  return service.getCacheStats();
});

/// State for region download progress.
class DownloadState {
  final bool isDownloading;
  final double progress;
  final int downloadedTiles;
  final int totalTiles;
  final String? regionName;
  final String? error;

  const DownloadState({
    this.isDownloading = false,
    this.progress = 0.0,
    this.downloadedTiles = 0,
    this.totalTiles = 0,
    this.regionName,
    this.error,
  });

  DownloadState copyWith({
    bool? isDownloading,
    double? progress,
    int? downloadedTiles,
    int? totalTiles,
    String? regionName,
    String? error,
    bool clearError = false,
  }) {
    return DownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      downloadedTiles: downloadedTiles ?? this.downloadedTiles,
      totalTiles: totalTiles ?? this.totalTiles,
      regionName: regionName ?? this.regionName,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for managing region downloads.
class DownloadProgressNotifier extends StateNotifier<DownloadState> {
  final TileCacheService _cacheService;
  final OfflineMapRepository _repository;
  final Ref _ref;

  DownloadProgressNotifier(this._cacheService, this._repository, this._ref)
      : super(const DownloadState());

  Future<void> downloadRegion({
    required String name,
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required int minZoom,
    required int maxZoom,
  }) async {
    try {
      await _cacheService.initialize();

      state = state.copyWith(
        isDownloading: true,
        progress: 0.0,
        regionName: name,
        clearError: true,
      );

      final stream = _cacheService.downloadRegion(
        southWest: LatLng(minLat, minLng),
        northEast: LatLng(maxLat, maxLng),
        minZoom: minZoom,
        maxZoom: maxZoom,
      );

      int totalTiles = 0;
      int downloadedTiles = 0;
      int sizeBytes = 0;

      await for (final progress in stream) {
        totalTiles = progress.maxTiles;
        downloadedTiles = progress.attemptedTiles;
        sizeBytes = progress.estTotalSize?.toInt() ?? 0;

        state = state.copyWith(
          progress: progress.percentageProgress / 100,
          downloadedTiles: downloadedTiles,
          totalTiles: totalTiles,
        );
      }

      // Save region to database
      await _repository.createRegion(
        name: name,
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
        minZoom: minZoom,
        maxZoom: maxZoom,
        tileCount: downloadedTiles,
        sizeBytes: sizeBytes,
      );

      // Refresh the regions list
      _ref.invalidate(cachedRegionsProvider);

      state = const DownloadState();
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> cancelDownload() async {
    await _cacheService.cancelDownload();
    state = const DownloadState();
  }
}

/// Provider for download progress notifier.
final downloadProgressProvider =
    StateNotifierProvider<DownloadProgressNotifier, DownloadState>((ref) {
  final cacheService = ref.watch(tileCacheServiceProvider);
  final repository = ref.watch(offlineMapRepositoryProvider);
  return DownloadProgressNotifier(cacheService, repository, ref);
});
```

Note: This file needs `import 'package:latlong2/latlong.dart';` added.

**Step 2: Commit**

```bash
git add lib/features/maps/presentation/providers/offline_map_providers.dart
git commit -m "feat(maps): add offline map providers"
```

---

## Phase 2: Region Download UI

### Task 2.1: Create RegionSelector widget

**Files:**
- Create: `lib/features/maps/presentation/widgets/region_selector.dart`

**Step 1: Create the widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Callback for when a region is selected.
typedef RegionSelectedCallback = void Function(
  LatLng southWest,
  LatLng northEast,
);

/// Widget for selecting a rectangular region on a map.
class RegionSelector extends StatefulWidget {
  final MapController mapController;
  final RegionSelectedCallback? onRegionSelected;
  final VoidCallback? onCancel;

  const RegionSelector({
    super.key,
    required this.mapController,
    this.onRegionSelected,
    this.onCancel,
  });

  @override
  State<RegionSelector> createState() => _RegionSelectorState();
}

class _RegionSelectorState extends State<RegionSelector> {
  LatLng? _startPoint;
  LatLng? _endPoint;
  bool _isDragging = false;

  LatLng? get _southWest {
    if (_startPoint == null || _endPoint == null) return null;
    return LatLng(
      _startPoint!.latitude < _endPoint!.latitude
          ? _startPoint!.latitude
          : _endPoint!.latitude,
      _startPoint!.longitude < _endPoint!.longitude
          ? _startPoint!.longitude
          : _endPoint!.longitude,
    );
  }

  LatLng? get _northEast {
    if (_startPoint == null || _endPoint == null) return null;
    return LatLng(
      _startPoint!.latitude > _endPoint!.latitude
          ? _startPoint!.latitude
          : _endPoint!.latitude,
      _startPoint!.longitude > _endPoint!.longitude
          ? _startPoint!.longitude
          : _endPoint!.longitude,
    );
  }

  void _onPanStart(DragStartDetails details, LatLng point) {
    setState(() {
      _startPoint = point;
      _endPoint = point;
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details, LatLng point) {
    if (_isDragging) {
      setState(() {
        _endPoint = point;
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
  }

  void _confirmSelection() {
    if (_southWest != null && _northEast != null) {
      widget.onRegionSelected?.call(_southWest!, _northEast!);
    }
  }

  void _clearSelection() {
    setState(() {
      _startPoint = null;
      _endPoint = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSelection = _southWest != null && _northEast != null;

    return Stack(
      children: [
        // Gesture detector for drawing
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (details) {
              final renderBox = context.findRenderObject() as RenderBox;
              final localPos = renderBox.globalToLocal(details.globalPosition);
              final point = widget.mapController.camera.pointToLatLng(
                Point(localPos.dx, localPos.dy),
              );
              _onPanStart(details, point);
            },
            onPanUpdate: (details) {
              final renderBox = context.findRenderObject() as RenderBox;
              final localPos = renderBox.globalToLocal(details.globalPosition);
              final point = widget.mapController.camera.pointToLatLng(
                Point(localPos.dx, localPos.dy),
              );
              _onPanUpdate(details, point);
            },
            onPanEnd: _onPanEnd,
          ),
        ),

        // Selection rectangle overlay
        if (hasSelection)
          Positioned.fill(
            child: CustomPaint(
              painter: _SelectionPainter(
                southWest: _southWest!,
                northEast: _northEast!,
                mapController: widget.mapController,
                color: colorScheme.primary,
              ),
            ),
          ),

        // Instructions overlay
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.touch_app, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasSelection
                          ? 'Drag to adjust selection'
                          : 'Drag on the map to select a region',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Action buttons
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _clearSelection();
                    widget.onCancel?.call();
                  },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: hasSelection ? _confirmSelection : null,
                  child: const Text('Select Region'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Painter for the selection rectangle.
class _SelectionPainter extends CustomPainter {
  final LatLng southWest;
  final LatLng northEast;
  final MapController mapController;
  final Color color;

  _SelectionPainter({
    required this.southWest,
    required this.northEast,
    required this.mapController,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final camera = mapController.camera;

    final swPoint = camera.latLngToScreenPoint(southWest);
    final nePoint = camera.latLngToScreenPoint(northEast);

    final rect = Rect.fromPoints(
      Offset(swPoint.x, nePoint.y),
      Offset(nePoint.x, swPoint.y),
    );

    // Fill
    final fillPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(rect, borderPaint);

    // Corner handles
    final handlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const handleSize = 12.0;

    canvas.drawCircle(rect.topLeft, handleSize / 2, handlePaint);
    canvas.drawCircle(rect.topRight, handleSize / 2, handlePaint);
    canvas.drawCircle(rect.bottomLeft, handleSize / 2, handlePaint);
    canvas.drawCircle(rect.bottomRight, handleSize / 2, handlePaint);
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter oldDelegate) {
    return southWest != oldDelegate.southWest ||
        northEast != oldDelegate.northEast;
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/maps/presentation/widgets/region_selector.dart
git commit -m "feat(maps): add RegionSelector widget for bounding box selection"
```

---

### Task 2.2: Create RegionDownloadDialog

**Files:**
- Create: `lib/features/maps/presentation/widgets/region_download_dialog.dart`

**Step 1: Create the dialog widget**

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/maps/presentation/providers/offline_map_providers.dart';

/// Dialog for configuring and starting a region download.
class RegionDownloadDialog extends ConsumerStatefulWidget {
  final LatLng southWest;
  final LatLng northEast;

  const RegionDownloadDialog({
    super.key,
    required this.southWest,
    required this.northEast,
  });

  @override
  ConsumerState<RegionDownloadDialog> createState() =>
      _RegionDownloadDialogState();
}

class _RegionDownloadDialogState extends ConsumerState<RegionDownloadDialog> {
  final _nameController = TextEditingController();
  int _minZoom = 8;
  int _maxZoom = 16;
  bool _isEstimating = false;
  int? _estimatedTiles;
  String? _suggestedName;

  @override
  void initState() {
    super.initState();
    _estimateTiles();
    _suggestName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _suggestName() async {
    try {
      final center = LatLng(
        (widget.southWest.latitude + widget.northEast.latitude) / 2,
        (widget.southWest.longitude + widget.northEast.longitude) / 2,
      );
      final result = await LocationService.instance.reverseGeocode(
        center.latitude,
        center.longitude,
      );

      final parts = <String>[];
      if (result.locality != null) parts.add(result.locality!);
      if (result.region != null && parts.isEmpty) parts.add(result.region!);
      if (result.country != null) parts.add(result.country!);

      if (mounted && parts.isNotEmpty) {
        setState(() {
          _suggestedName = parts.take(2).join(', ');
          if (_nameController.text.isEmpty) {
            _nameController.text = _suggestedName!;
          }
        });
      }
    } catch (e) {
      // Ignore geocoding errors
    }
  }

  Future<void> _estimateTiles() async {
    setState(() => _isEstimating = true);

    try {
      final service = ref.read(tileCacheServiceProvider);
      await service.initialize();

      final count = await service.estimateTileCount(
        southWest: widget.southWest,
        northEast: widget.northEast,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
      );

      if (mounted) {
        setState(() {
          _estimatedTiles = count;
          _isEstimating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isEstimating = false);
      }
    }
  }

  String _formatEstimatedSize(int tiles) {
    // Rough estimate: ~30KB per tile on average
    final bytes = tiles * 30 * 1024;
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _startDownload() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for this region')),
      );
      return;
    }

    Navigator.of(context).pop();

    await ref.read(downloadProgressProvider.notifier).downloadRegion(
          name: name,
          minLat: widget.southWest.latitude,
          maxLat: widget.northEast.latitude,
          minLng: widget.southWest.longitude,
          maxLng: widget.northEast.longitude,
          minZoom: _minZoom,
          maxZoom: _maxZoom,
        );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Download Region'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Region name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Region Name',
                hintText: _suggestedName ?? 'e.g., Cozumel, Mexico',
                prefixIcon: const Icon(Icons.label),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 24),

            // Zoom range
            Text(
              'Zoom Levels',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Min: $_minZoom'),
                      Slider(
                        value: _minZoom.toDouble(),
                        min: 1,
                        max: 14,
                        divisions: 13,
                        onChanged: (value) {
                          setState(() {
                            _minZoom = value.round();
                            if (_maxZoom < _minZoom) _maxZoom = _minZoom;
                          });
                          _estimateTiles();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Max: $_maxZoom'),
                      Slider(
                        value: _maxZoom.toDouble(),
                        min: 8,
                        max: 18,
                        divisions: 10,
                        onChanged: (value) {
                          setState(() {
                            _maxZoom = value.round();
                            if (_minZoom > _maxZoom) _minZoom = _maxZoom;
                          });
                          _estimateTiles();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Estimate
            Card(
              color: colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.storage, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _isEstimating
                          ? const Text('Estimating...')
                          : _estimatedTiles != null
                              ? Text(
                                  '~$_estimatedTiles tiles (~${_formatEstimatedSize(_estimatedTiles!)})',
                                )
                              : const Text('Unable to estimate'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _startDownload,
          icon: const Icon(Icons.download),
          label: const Text('Download'),
        ),
      ],
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/maps/presentation/widgets/region_download_dialog.dart
git commit -m "feat(maps): add RegionDownloadDialog for download configuration"
```

---

### Task 2.3: Create OfflineMapsPage

**Files:**
- Create: `lib/features/maps/presentation/pages/offline_maps_page.dart`

**Step 1: Create the page**

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/maps/domain/entities/cached_region.dart';
import 'package:submersion/features/maps/presentation/providers/offline_map_providers.dart';

/// Page for managing offline map regions.
class OfflineMapsPage extends ConsumerWidget {
  const OfflineMapsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regionsAsync = ref.watch(cachedRegionsProvider);
    final cacheStatsAsync = ref.watch(cacheStatsProvider);
    final downloadState = ref.watch(downloadProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Maps'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear All Cache',
            onPressed: () => _showClearCacheDialog(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cache statistics
          cacheStatsAsync.when(
            data: (stats) => _buildStatsCard(context, stats),
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading stats: $e'),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Download progress
          if (downloadState.isDownloading) ...[
            _buildDownloadProgressCard(context, downloadState),
            const SizedBox(height: 16),
          ],

          // Downloaded regions header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Downloaded Regions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(cachedRegionsProvider),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Regions list
          regionsAsync.when(
            data: (regions) => regions.isEmpty
                ? _buildEmptyState(context)
                : Column(
                    children: regions
                        .map((r) => _buildRegionTile(context, ref, r))
                        .toList(),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(
    BuildContext context,
    ({int tileCount, int sizeBytes}) stats,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final sizeStr = _formatBytes(stats.sizeBytes);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.storage, color: colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cache Usage',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$sizeStr (${stats.tileCount} tiles)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadProgressCard(
    BuildContext context,
    DownloadState state,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Downloading: ${state.regionName ?? "Region"}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ProviderScope.containerOf(context).read(
                        downloadProgressProvider.notifier,
                      ).cancelDownload(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: state.progress),
            const SizedBox(height: 8),
            Text(
              '${state.downloadedTiles} / ${state.totalTiles} tiles (${(state.progress * 100).toStringAsFixed(1)}%)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.cloud_download_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(
                    0.5,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Downloaded Regions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Download map regions from any map page using the overflow menu',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionTile(
    BuildContext context,
    WidgetRef ref,
    CachedRegion region,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          child: Icon(Icons.map, color: colorScheme.secondary),
        ),
        title: Text(region.name),
        subtitle: Text(
          '${region.formattedSize} - Zoom ${region.minZoom}-${region.maxZoom}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDeleteRegion(context, ref, region),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteRegion(
    BuildContext context,
    WidgetRef ref,
    CachedRegion region,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Region?'),
        content: Text(
          'Delete "${region.name}"? The cached tiles will remain but the region will be removed from your list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(offlineMapRepositoryProvider).deleteRegion(region.id);
      ref.invalidate(cachedRegionsProvider);
    }
  }

  Future<void> _showClearCacheDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Cache?'),
        content: const Text(
          'This will delete all downloaded map tiles and remove all saved regions. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(tileCacheServiceProvider);
      await service.clearCache();

      // Delete all region records
      final repository = ref.read(offlineMapRepositoryProvider);
      final regions = await repository.getAllRegions();
      for (final region in regions) {
        await repository.deleteRegion(region.id);
      }

      ref.invalidate(cachedRegionsProvider);
      ref.invalidate(cacheStatsProvider);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/maps/presentation/pages/offline_maps_page.dart
git commit -m "feat(maps): add OfflineMapsPage for managing cached regions"
```

---

## Phase 3: Heat Map Core

### Task 3.1: Create HeatMapPoint entity

**Files:**
- Create: `lib/features/maps/domain/entities/heat_map_point.dart`

**Step 1: Create the entity**

```dart
import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// A weighted point for heat map visualization.
class HeatMapPoint extends Equatable {
  final LatLng location;
  final double weight;
  final String? label;

  const HeatMapPoint({
    required this.location,
    this.weight = 1.0,
    this.label,
  });

  @override
  List<Object?> get props => [location, weight, label];
}
```

**Step 2: Commit**

```bash
git add lib/features/maps/domain/entities/heat_map_point.dart
git commit -m "feat(maps): add HeatMapPoint entity"
```

---

### Task 3.2: Create heat map providers

**Files:**
- Create: `lib/features/maps/presentation/providers/heat_map_providers.dart`

**Step 1: Create the providers**

```dart
import 'package:latlong2/latlong.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';

/// Provider for dive activity heat map data.
/// Groups dives by site location and weights by dive count.
final diveActivityHeatMapProvider = FutureProvider<List<HeatMapPoint>>((
  ref,
) async {
  final divesAsync = await ref.watch(divesProvider.future);

  // Group dives by site ID and count
  final siteCountMap = <String, int>{};
  final siteLocationMap = <String, LatLng>{};

  for (final dive in divesAsync) {
    if (dive.site == null || !dive.site!.hasCoordinates) continue;

    final siteId = dive.site!.id;
    siteCountMap[siteId] = (siteCountMap[siteId] ?? 0) + 1;

    if (!siteLocationMap.containsKey(siteId)) {
      siteLocationMap[siteId] = LatLng(
        dive.site!.location!.latitude,
        dive.site!.location!.longitude,
      );
    }
  }

  // Convert to heat map points
  return siteCountMap.entries.map((entry) {
    final location = siteLocationMap[entry.key]!;
    return HeatMapPoint(
      location: location,
      weight: entry.value.toDouble(),
    );
  }).toList();
});

/// Provider for site coverage heat map data.
/// Shows all sites with equal weight (or optionally weighted by rating).
final siteCoverageHeatMapProvider = FutureProvider<List<HeatMapPoint>>((
  ref,
) async {
  final sitesWithCounts = await ref.watch(sitesWithCountsProvider.future);

  return sitesWithCounts
      .where((s) => s.site.hasCoordinates)
      .map((s) {
        // Weight by rating if available, otherwise equal weight
        final weight = s.site.rating ?? 1.0;
        return HeatMapPoint(
          location: LatLng(
            s.site.location!.latitude,
            s.site.location!.longitude,
          ),
          weight: weight,
          label: s.site.name,
        );
      })
      .toList();
});

/// State for heat map display settings.
class HeatMapSettings {
  final double opacity;
  final double radius;
  final bool isVisible;

  const HeatMapSettings({
    this.opacity = 0.6,
    this.radius = 30.0,
    this.isVisible = true,
  });

  HeatMapSettings copyWith({
    double? opacity,
    double? radius,
    bool? isVisible,
  }) {
    return HeatMapSettings(
      opacity: opacity ?? this.opacity,
      radius: radius ?? this.radius,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}

/// Provider for heat map display settings.
final heatMapSettingsProvider = StateProvider<HeatMapSettings>((ref) {
  return const HeatMapSettings();
});
```

**Step 2: Commit**

```bash
git add lib/features/maps/presentation/providers/heat_map_providers.dart
git commit -m "feat(maps): add heat map data providers"
```

---

### Task 3.3: Create HeatMapLayer widget

**Files:**
- Create: `lib/features/maps/presentation/widgets/heat_map_layer.dart`

**Step 1: Create the widget with CustomPainter**

```dart
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';

/// A flutter_map layer that displays a heat map visualization.
class HeatMapLayer extends StatelessWidget {
  final List<HeatMapPoint> points;
  final double radius;
  final double opacity;
  final List<Color>? gradient;

  const HeatMapLayer({
    super.key,
    required this.points,
    this.radius = 30.0,
    this.opacity = 0.6,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _HeatMapPainter(
            points: points,
            radius: radius,
            opacity: opacity,
            gradient: gradient ?? _defaultGradient,
            camera: MapCamera.of(context),
          ),
        );
      },
    );
  }

  static const List<Color> _defaultGradient = [
    Color(0xFF3B82F6), // Blue (low)
    Color(0xFF06B6D4), // Cyan
    Color(0xFF22C55E), // Green
    Color(0xFFEAB308), // Yellow
    Color(0xFFF97316), // Orange
    Color(0xFFEF4444), // Red (high)
  ];
}

class _HeatMapPainter extends CustomPainter {
  final List<HeatMapPoint> points;
  final double radius;
  final double opacity;
  final List<Color> gradient;
  final MapCamera camera;

  _HeatMapPainter({
    required this.points,
    required this.radius,
    required this.opacity,
    required this.gradient,
    required this.camera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Find max weight for normalization
    final maxWeight = points.map((p) => p.weight).reduce(math.max);
    if (maxWeight <= 0) return;

    // Create an offscreen buffer for the heat map
    final recorder = ui.PictureRecorder();
    final bufferCanvas = Canvas(recorder);

    // Draw each point as a radial gradient
    for (final point in points) {
      final screenPoint = camera.latLngToScreenPoint(point.location);

      // Skip points outside the visible area (with padding)
      if (screenPoint.x < -radius ||
          screenPoint.x > size.width + radius ||
          screenPoint.y < -radius ||
          screenPoint.y > size.height + radius) {
        continue;
      }

      final normalizedWeight = point.weight / maxWeight;
      final pointRadius = radius * (0.5 + normalizedWeight * 0.5);

      // Create radial gradient for this point
      final gradientShader = RadialGradient(
        colors: [
          _getColorForWeight(normalizedWeight).withOpacity(opacity * normalizedWeight),
          _getColorForWeight(normalizedWeight).withOpacity(0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(screenPoint.x, screenPoint.y),
          radius: pointRadius,
        ),
      );

      final paint = Paint()
        ..shader = gradientShader
        ..blendMode = BlendMode.plus;

      bufferCanvas.drawCircle(
        Offset(screenPoint.x, screenPoint.y),
        pointRadius,
        paint,
      );
    }

    // Draw the buffer to the main canvas
    final picture = recorder.endRecording();
    final image = picture.toImageSync(size.width.ceil(), size.height.ceil());

    canvas.drawImage(image, Offset.zero, Paint());
    image.dispose();
  }

  Color _getColorForWeight(double normalizedWeight) {
    if (gradient.isEmpty) return Colors.red;
    if (gradient.length == 1) return gradient.first;

    // Map weight to gradient position
    final position = normalizedWeight * (gradient.length - 1);
    final lowerIndex = position.floor().clamp(0, gradient.length - 2);
    final upperIndex = (lowerIndex + 1).clamp(0, gradient.length - 1);
    final t = position - lowerIndex;

    return Color.lerp(gradient[lowerIndex], gradient[upperIndex], t)!;
  }

  @override
  bool shouldRepaint(covariant _HeatMapPainter oldDelegate) {
    return points != oldDelegate.points ||
        radius != oldDelegate.radius ||
        opacity != oldDelegate.opacity ||
        camera != oldDelegate.camera;
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/maps/presentation/widgets/heat_map_layer.dart
git commit -m "feat(maps): add HeatMapLayer widget with gradient rendering"
```

---

### Task 3.4: Create HeatMapControls widget

**Files:**
- Create: `lib/features/maps/presentation/widgets/heat_map_controls.dart`

**Step 1: Create the controls widget**

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';

/// Controls for adjusting heat map display settings.
class HeatMapControls extends ConsumerWidget {
  const HeatMapControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(heatMapSettingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Heat Map Settings',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Switch(
                  value: settings.isVisible,
                  onChanged: (value) {
                    ref.read(heatMapSettingsProvider.notifier).state =
                        settings.copyWith(isVisible: value);
                  },
                ),
              ],
            ),
            if (settings.isVisible) ...[
              const SizedBox(height: 16),

              // Opacity slider
              Row(
                children: [
                  Icon(Icons.opacity, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Opacity'),
                  Expanded(
                    child: Slider(
                      value: settings.opacity,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      label: '${(settings.opacity * 100).round()}%',
                      onChanged: (value) {
                        ref.read(heatMapSettingsProvider.notifier).state =
                            settings.copyWith(opacity: value);
                      },
                    ),
                  ),
                ],
              ),

              // Radius slider
              Row(
                children: [
                  Icon(Icons.blur_on, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Spread'),
                  Expanded(
                    child: Slider(
                      value: settings.radius,
                      min: 15,
                      max: 60,
                      divisions: 9,
                      label: '${settings.radius.round()}',
                      onChanged: (value) {
                        ref.read(heatMapSettingsProvider.notifier).state =
                            settings.copyWith(radius: value);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/maps/presentation/widgets/heat_map_controls.dart
git commit -m "feat(maps): add HeatMapControls widget"
```

---

## Phase 4: Integration

### Task 4.1: Add Activity view to SiteMapPage

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_map_page.dart`

**Step 1: Add imports and view state**

Add to imports at top:

```dart
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_controls.dart';
```

**Step 2: Add view mode enum and state**

Add inside the `_SiteMapPageState` class:

```dart
enum SiteMapViewMode { sites, coverage }

// Add as state variable:
SiteMapViewMode _viewMode = SiteMapViewMode.sites;
```

**Step 3: Add segmented button to AppBar**

Replace the AppBar title with:

```dart
title: SegmentedButton<SiteMapViewMode>(
  segments: const [
    ButtonSegment(
      value: SiteMapViewMode.sites,
      label: Text('Sites'),
      icon: Icon(Icons.location_on),
    ),
    ButtonSegment(
      value: SiteMapViewMode.coverage,
      label: Text('Coverage'),
      icon: Icon(Icons.blur_on),
    ),
  ],
  selected: {_viewMode},
  onSelectionChanged: (selection) {
    setState(() => _viewMode = selection.first);
  },
),
```

**Step 4: Add heat map layer conditionally**

In the FlutterMap children list, add after the TileLayer:

```dart
if (_viewMode == SiteMapViewMode.coverage)
  Consumer(
    builder: (context, ref, child) {
      final heatMapAsync = ref.watch(siteCoverageHeatMapProvider);
      final settings = ref.watch(heatMapSettingsProvider);

      if (!settings.isVisible) return const SizedBox.shrink();

      return heatMapAsync.when(
        data: (points) => HeatMapLayer(
          points: points,
          radius: settings.radius,
          opacity: settings.opacity,
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
      );
    },
  ),
```

**Step 5: Add heat map controls overlay**

Add in the Stack children (after the empty state overlay):

```dart
if (_viewMode == SiteMapViewMode.coverage)
  const Positioned(
    bottom: 80,
    left: 0,
    right: 0,
    child: HeatMapControls(),
  ),
```

**Step 6: Commit**

```bash
git add lib/features/dive_sites/presentation/pages/site_map_page.dart
git commit -m "feat(maps): add Coverage heat map view to SiteMapPage"
```

---

### Task 4.2: Create DiveActivityMapPage

**Files:**
- Create: `lib/features/maps/presentation/pages/dive_activity_map_page.dart`

**Step 1: Create the page**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_controls.dart';

/// Page showing heat map of dive activity.
class DiveActivityMapPage extends ConsumerStatefulWidget {
  const DiveActivityMapPage({super.key});

  @override
  ConsumerState<DiveActivityMapPage> createState() =>
      _DiveActivityMapPageState();
}

class _DiveActivityMapPageState extends ConsumerState<DiveActivityMapPage> {
  final MapController _mapController = MapController();

  // Default to a world view
  static const _defaultCenter = LatLng(20.0, 0.0);
  static const _defaultZoom = 2.0;

  @override
  Widget build(BuildContext context) {
    final heatMapAsync = ref.watch(diveActivityHeatMapProvider);
    final settings = ref.watch(heatMapSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dive Activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'List View',
            onPressed: () => context.go('/dives'),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: _defaultZoom,
              minZoom: 2.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.submersion.app',
                maxZoom: 19,
              ),
              if (settings.isVisible)
                heatMapAsync.when(
                  data: (points) => HeatMapLayer(
                    points: points,
                    radius: settings.radius,
                    opacity: settings.opacity,
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
            ],
          ),

          // Heat map controls
          const Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: HeatMapControls(),
          ),

          // Loading indicator
          if (heatMapAsync.isLoading)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),

          // Empty state
          heatMapAsync.when(
            data: (points) {
              if (points.isEmpty) {
                return Center(
                  child: Card(
                    margin: const EdgeInsets.all(32),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.scuba_diving,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No dive activity to display',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Log dives with location data to see your activity on the map',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/maps/presentation/pages/dive_activity_map_page.dart
git commit -m "feat(maps): add DiveActivityMapPage for dive heat map"
```

---

### Task 4.3: Add routes for new pages

**Files:**
- Modify: `lib/core/navigation/app_router.dart`

**Step 1: Add imports**

```dart
import 'package:submersion/features/maps/presentation/pages/dive_activity_map_page.dart';
import 'package:submersion/features/maps/presentation/pages/offline_maps_page.dart';
```

**Step 2: Add routes**

Add routes for the new pages (exact location depends on existing router structure):

```dart
// Dive activity map route (under dives)
GoRoute(
  path: 'activity',
  name: 'diveActivity',
  builder: (context, state) => const DiveActivityMapPage(),
),

// Offline maps route (under settings)
GoRoute(
  path: 'offline-maps',
  name: 'offlineMaps',
  builder: (context, state) => const OfflineMapsPage(),
),
```

**Step 3: Commit**

```bash
git add lib/core/navigation/app_router.dart
git commit -m "feat(maps): add routes for DiveActivityMapPage and OfflineMapsPage"
```

---

### Task 4.4: Add navigation entry points

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart`

**Step 1: Add "Offline Maps" to Settings page**

Add a ListTile in the Storage section:

```dart
ListTile(
  leading: const Icon(Icons.cloud_download),
  title: const Text('Offline Maps'),
  subtitle: const Text('Download maps for offline use'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.push('/settings/offline-maps'),
),
```

**Step 2: Add "Activity Map" action to DiveListContent**

Add to the AppBar actions or overflow menu:

```dart
IconButton(
  icon: const Icon(Icons.map),
  tooltip: 'Activity Map',
  onPressed: () => context.push('/dives/activity'),
),
```

**Step 3: Commit**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart
git add lib/features/dive_log/presentation/widgets/dive_list_content.dart
git commit -m "feat(maps): add navigation to Offline Maps and Activity Map"
```

---

### Task 4.5: Initialize tile cache service at app startup

**Files:**
- Modify: `lib/main.dart`

**Step 1: Add initialization**

In the main function or app initialization, add:

```dart
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';

// In main() or initialization:
await TileCacheService.instance.initialize();
```

**Step 2: Commit**

```bash
git add lib/main.dart
git commit -m "feat(maps): initialize tile cache service at app startup"
```

---

## Phase 5: Testing

### Task 5.1: Write unit tests for heat map point aggregation

**Files:**
- Create: `test/features/maps/heat_map_providers_test.dart`

**Step 1: Create tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';

void main() {
  group('HeatMapPoint', () {
    test('creates point with default weight', () {
      const point = HeatMapPoint(
        location: LatLng(25.0, -80.0),
      );

      expect(point.weight, 1.0);
      expect(point.label, isNull);
    });

    test('creates point with custom weight and label', () {
      const point = HeatMapPoint(
        location: LatLng(25.0, -80.0),
        weight: 5.0,
        label: 'Cozumel',
      );

      expect(point.weight, 5.0);
      expect(point.label, 'Cozumel');
    });

    test('equality based on all properties', () {
      const point1 = HeatMapPoint(
        location: LatLng(25.0, -80.0),
        weight: 5.0,
      );
      const point2 = HeatMapPoint(
        location: LatLng(25.0, -80.0),
        weight: 5.0,
      );
      const point3 = HeatMapPoint(
        location: LatLng(25.0, -80.0),
        weight: 3.0,
      );

      expect(point1, equals(point2));
      expect(point1, isNot(equals(point3)));
    });
  });
}
```

**Step 2: Run tests**

Run: `flutter test test/features/maps/heat_map_providers_test.dart`
Expected: All tests pass

**Step 3: Commit**

```bash
git add test/features/maps/heat_map_providers_test.dart
git commit -m "test(maps): add unit tests for HeatMapPoint"
```

---

### Task 5.2: Write unit tests for CachedRegion entity

**Files:**
- Create: `test/features/maps/cached_region_test.dart`

**Step 1: Create tests**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/maps/domain/entities/cached_region.dart';

void main() {
  group('CachedRegion', () {
    test('formattedSize returns correct units', () {
      final small = CachedRegion(
        id: '1',
        name: 'Test',
        minLat: 0,
        maxLat: 1,
        minLng: 0,
        maxLng: 1,
        minZoom: 8,
        maxZoom: 16,
        tileCount: 100,
        sizeBytes: 500, // bytes
        createdAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
      );
      expect(small.formattedSize, '500 B');

      final medium = small.copyWith(sizeBytes: 1024 * 50); // 50 KB
      expect(medium.formattedSize, '50.0 KB');

      final large = small.copyWith(sizeBytes: 1024 * 1024 * 25); // 25 MB
      expect(large.formattedSize, '25.0 MB');
    });

    test('center calculates correctly', () {
      final region = CachedRegion(
        id: '1',
        name: 'Test',
        minLat: 20.0,
        maxLat: 22.0,
        minLng: -88.0,
        maxLng: -86.0,
        minZoom: 8,
        maxZoom: 16,
        tileCount: 100,
        sizeBytes: 1000,
        createdAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
      );

      expect(region.center.latitude, 21.0);
      expect(region.center.longitude, -87.0);
    });

    test('copyWith preserves unmodified values', () {
      final original = CachedRegion(
        id: '1',
        name: 'Original',
        minLat: 20.0,
        maxLat: 22.0,
        minLng: -88.0,
        maxLng: -86.0,
        minZoom: 8,
        maxZoom: 16,
        tileCount: 100,
        sizeBytes: 1000,
        createdAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
      );

      final modified = original.copyWith(name: 'Modified');

      expect(modified.name, 'Modified');
      expect(modified.id, original.id);
      expect(modified.minLat, original.minLat);
    });
  });
}
```

**Step 2: Run tests**

Run: `flutter test test/features/maps/cached_region_test.dart`
Expected: All tests pass

**Step 3: Commit**

```bash
git add test/features/maps/cached_region_test.dart
git commit -m "test(maps): add unit tests for CachedRegion entity"
```

---

## Summary

This plan implements:

1. **Offline Maps Infrastructure** (Tasks 1.1-1.6)
   - flutter_map_tile_caching integration
   - CachedRegion entity and database table
   - OfflineMapRepository for region management
   - TileCacheService for tile operations
   - Riverpod providers for state management

2. **Region Download UI** (Tasks 2.1-2.3)
   - RegionSelector for bounding box drawing
   - RegionDownloadDialog for configuration
   - OfflineMapsPage for region management

3. **Heat Map Core** (Tasks 3.1-3.4)
   - HeatMapPoint entity
   - Heat map data providers (dive activity + site coverage)
   - HeatMapLayer with gradient CustomPainter
   - HeatMapControls for settings

4. **Integration** (Tasks 4.1-4.5)
   - Coverage view toggle on SiteMapPage
   - DiveActivityMapPage for dives
   - Routes and navigation
   - App startup initialization

5. **Testing** (Tasks 5.1-5.2)
   - Unit tests for entities

---

Plan complete and saved to `docs/plans/2026-01-31-maps-visualization-implementation.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**