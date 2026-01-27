# Trip Photo Galleries Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add photo gallery functionality to trips, showing aggregated photos from all dives within a trip with auto-scan capability.

**Architecture:** Aggregation-based approach - no schema changes. New providers query existing dive→media relationships and aggregate by trip. New scanner service matches device gallery photos to dive timestamps for bulk linking.

**Tech Stack:** Flutter, Riverpod (FutureProvider.family), photo_manager, go_router

---

## Task 1: Trip Media Providers

**Files:**
- Create: `lib/features/trips/presentation/providers/trip_media_providers.dart`
- Test: `test/features/trips/presentation/providers/trip_media_providers_test.dart`

**Step 1: Write the failing test**

```dart
// test/features/trips/presentation/providers/trip_media_providers_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

void main() {
  group('mediaForTripProvider', () {
    test('returns empty map when trip has no dives', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // This will fail because provider doesn't exist yet
      final result = await container.read(
        mediaForTripProvider('trip-with-no-dives').future,
      );

      expect(result, isEmpty);
    });
  });

  group('mediaCountForTripProvider', () {
    test('returns 0 when trip has no media', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final count = await container.read(
        mediaCountForTripProvider('empty-trip').future,
      );

      expect(count, equals(0));
    });
  });

  group('flatMediaListForTripProvider', () {
    test('returns flat list sorted by takenAt', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        flatMediaListForTripProvider('test-trip').future,
      );

      expect(result, isList);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/presentation/providers/trip_media_providers_test.dart`
Expected: FAIL with compilation error (provider not found)

**Step 3: Write minimal implementation**

```dart
// lib/features/trips/presentation/providers/trip_media_providers.dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// Media for all dives in a trip, grouped by dive
/// Returns Map<Dive, List<MediaItem>> preserving dive context
final mediaForTripProvider = FutureProvider.family<
  Map<Dive, List<MediaItem>>,
  String
>((ref, tripId) async {
  // Get all dives for this trip
  final dives = await ref.watch(divesForTripProvider(tripId).future);

  if (dives.isEmpty) {
    return {};
  }

  // Fetch media for each dive
  final Map<Dive, List<MediaItem>> result = {};

  for (final dive in dives) {
    final media = await ref.watch(mediaForDiveProvider(dive.id).future);
    if (media.isNotEmpty) {
      result[dive] = media;
    }
  }

  return result;
});

/// Total media count for a trip (for badges/headers)
final mediaCountForTripProvider = FutureProvider.family<int, String>((
  ref,
  tripId,
) async {
  final mediaByDive = await ref.watch(mediaForTripProvider(tripId).future);
  return mediaByDive.values.fold(0, (sum, list) => sum + list.length);
});

/// Flat list of all media for trip, sorted by takenAt
/// Used for trip-scoped photo viewer navigation
final flatMediaListForTripProvider = FutureProvider.family<
  List<MediaItem>,
  String
>((ref, tripId) async {
  final mediaByDive = await ref.watch(mediaForTripProvider(tripId).future);

  final allMedia = mediaByDive.values.expand((list) => list).toList();

  // Sort by takenAt (chronological)
  allMedia.sort((a, b) => a.takenAt.compareTo(b.takenAt));

  return allMedia;
});
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/trips/presentation/providers/trip_media_providers_test.dart`
Expected: PASS (3 tests)

**Step 5: Commit**

```bash
git add lib/features/trips/presentation/providers/trip_media_providers.dart test/features/trips/presentation/providers/trip_media_providers_test.dart
git commit -m "feat(trips): add trip media providers for aggregated photo queries"
```

---

## Task 2: Trip Photo Section Widget

**Files:**
- Create: `lib/features/trips/presentation/widgets/trip_photo_section.dart`
- Test: `test/features/trips/presentation/widgets/trip_photo_section_test.dart`

**Step 1: Write the failing test**

```dart
// test/features/trips/presentation/widgets/trip_photo_section_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_photo_section.dart';

void main() {
  group('TripPhotoSection', () {
    testWidgets('shows empty state when no photos', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TripPhotoSection(tripId: 'empty-trip'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No photos yet'), findsOneWidget);
    });

    testWidgets('shows photo count in header', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TripPhotoSection(tripId: 'test-trip'),
            ),
          ),
        ),
      );

      // Should show Photos header
      expect(find.textContaining('Photos'), findsOneWidget);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/presentation/widgets/trip_photo_section_test.dart`
Expected: FAIL (widget not found)

**Step 3: Write minimal implementation**

```dart
// lib/features/trips/presentation/widgets/trip_photo_section.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';

/// Collapsible photo section for trip detail page
/// Shows horizontal row of photo thumbnails with scan action
class TripPhotoSection extends ConsumerWidget {
  final String tripId;
  final VoidCallback? onScanPressed;

  const TripPhotoSection({
    super.key,
    required this.tripId,
    this.onScanPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(mediaCountForTripProvider(tripId));
    final mediaAsync = ref.watch(flatMediaListForTripProvider(tripId));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(Icons.photo_library, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: countAsync.when(
                    data: (count) => Text(
                      'Photos${count > 0 ? ' ($count)' : ''}',
                      style: textTheme.titleMedium,
                    ),
                    loading: () => Text('Photos', style: textTheme.titleMedium),
                    error: (_, __) => Text('Photos', style: textTheme.titleMedium),
                  ),
                ),
                // Scan button
                IconButton(
                  icon: Icon(Icons.photo_camera, color: colorScheme.primary),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Scan for photos',
                  onPressed: onScanPressed,
                ),
                // View all button (only if photos exist)
                countAsync.maybeWhen(
                  data: (count) => count > 0
                      ? TextButton(
                          onPressed: () => context.push('/trips/$tripId/gallery'),
                          child: const Text('View All'),
                        )
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Content
            mediaAsync.when(
              data: (media) {
                if (media.isEmpty) {
                  return _EmptyState(onScanPressed: onScanPressed);
                }
                return _PhotoRow(
                  media: media,
                  tripId: tripId,
                );
              },
              loading: () => const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (error, _) => Text(
                'Error loading photos',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback? onScanPressed;

  const _EmptyState({this.onScanPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'No photos yet',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (onScanPressed != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onScanPressed,
              child: const Text('Scan device gallery'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  final List<MediaItem> media;
  final String tripId;

  const _PhotoRow({required this.media, required this.tripId});

  @override
  Widget build(BuildContext context) {
    // Show first N photos that fit, with +X indicator
    const maxVisible = 5;
    final visibleMedia = media.take(maxVisible).toList();
    final remainingCount = media.length - maxVisible;

    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visibleMedia.length + (remainingCount > 0 ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == visibleMedia.length && remainingCount > 0) {
            // +N indicator
            return _MoreIndicator(
              count: remainingCount,
              onTap: () => context.push('/trips/$tripId/gallery'),
            );
          }
          return _PhotoThumbnail(
            item: visibleMedia[index],
            tripId: tripId,
          );
        },
      ),
    );
  }
}

class _PhotoThumbnail extends ConsumerWidget {
  final MediaItem item;
  final String tripId;

  const _PhotoThumbnail({required this.item, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    if (item.platformAssetId == null) {
      return _buildPlaceholder(colorScheme);
    }

    final thumbnailAsync = ref.watch(
      assetThumbnailProvider(item.platformAssetId!),
    );

    return GestureDetector(
      onTap: () => context.push('/trips/$tripId/gallery?mediaId=${item.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 80,
          height: 80,
          child: thumbnailAsync.when(
            data: (bytes) {
              if (bytes == null) return _buildPlaceholder(colorScheme);
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                cacheWidth: 160,
                cacheHeight: 160,
              );
            },
            loading: () => Container(
              color: colorScheme.surfaceContainerHighest,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, __) => _buildPlaceholder(colorScheme),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.photo, color: colorScheme.onSurfaceVariant),
    );
  }
}

class _MoreIndicator extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _MoreIndicator({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '+$count',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/trips/presentation/widgets/trip_photo_section_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/trips/presentation/widgets/trip_photo_section.dart test/features/trips/presentation/widgets/trip_photo_section_test.dart
git commit -m "feat(trips): add trip photo section widget with preview row"
```

---

## Task 3: Add Photo Section to Trip Detail Page

**Files:**
- Modify: `lib/features/trips/presentation/pages/trip_detail_page.dart`

**Step 1: Read current file and identify insertion point**

Insert after notes section (~line 111), before dives section.

**Step 2: Add import and widget**

Add import at top:
```dart
import 'package:submersion/features/trips/presentation/widgets/trip_photo_section.dart';
```

Add widget in `_TripDetailContent` build method, after notes section:
```dart
          // Notes
          if (trip.notes.isNotEmpty) ...[
            _buildNotesSection(context, trip),
            const SizedBox(height: 24),
          ],

          // Photos (NEW)
          TripPhotoSection(
            tripId: trip.id,
            onScanPressed: () => _showScanDialog(context, ref, trip.id),
          ),
          const SizedBox(height: 24),

          // Dives
          _buildDivesSection(context, ref, divesAsync),
```

Add placeholder scan dialog method to `_TripDetailContent`:
```dart
  void _showScanDialog(BuildContext context, WidgetRef ref, String tripId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo scanning coming soon')),
    );
  }
```

**Step 3: Run the app to verify**

Run: `flutter run -d macos`
Navigate to a trip detail page and verify photo section appears.

**Step 4: Commit**

```bash
git add lib/features/trips/presentation/pages/trip_detail_page.dart
git commit -m "feat(trips): integrate photo section into trip detail page"
```

---

## Task 4: Trip Gallery Page

**Files:**
- Create: `lib/features/trips/presentation/pages/trip_gallery_page.dart`
- Test: `test/features/trips/presentation/pages/trip_gallery_page_test.dart`

**Step 1: Write the failing test**

```dart
// test/features/trips/presentation/pages/trip_gallery_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/trips/presentation/pages/trip_gallery_page.dart';

void main() {
  group('TripGalleryPage', () {
    testWidgets('shows app bar with title', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TripGalleryPage(tripId: 'test-trip'),
          ),
        ),
      );

      expect(find.text('Trip Photos'), findsOneWidget);
    });

    testWidgets('shows loading indicator initially', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TripGalleryPage(tripId: 'test-trip'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/presentation/pages/trip_gallery_page_test.dart`
Expected: FAIL

**Step 3: Write implementation**

```dart
// lib/features/trips/presentation/pages/trip_gallery_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/trip_photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// Full gallery page showing all photos for a trip, grouped by dive
class TripGalleryPage extends ConsumerWidget {
  final String tripId;
  final String? initialMediaId;

  const TripGalleryPage({
    super.key,
    required this.tripId,
    this.initialMediaId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripByIdProvider(tripId));
    final mediaAsync = ref.watch(mediaForTripProvider(tripId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Photos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_camera),
            tooltip: 'Scan for photos',
            onPressed: () => _showScanDialog(context),
          ),
        ],
      ),
      body: mediaAsync.when(
        data: (mediaByDive) {
          if (mediaByDive.isEmpty) {
            return const _EmptyGallery();
          }
          return _GalleryContent(
            mediaByDive: mediaByDive,
            tripId: tripId,
            initialMediaId: initialMediaId,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Error loading photos: $error'),
        ),
      ),
    );
  }

  void _showScanDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo scanning coming soon')),
    );
  }
}

class _EmptyGallery extends StatelessWidget {
  const _EmptyGallery();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No photos in this trip',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the camera icon to scan your gallery',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryContent extends StatelessWidget {
  final Map<Dive, List<MediaItem>> mediaByDive;
  final String tripId;
  final String? initialMediaId;

  const _GalleryContent({
    required this.mediaByDive,
    required this.tripId,
    this.initialMediaId,
  });

  @override
  Widget build(BuildContext context) {
    // Sort dives by date (most recent first)
    final sortedEntries = mediaByDive.entries.toList()
      ..sort((a, b) => b.key.dateTime.compareTo(a.key.dateTime));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        return _DivePhotoSection(
          dive: entry.key,
          media: entry.value,
          tripId: tripId,
          initiallyExpanded: true,
        );
      },
    );
  }
}

class _DivePhotoSection extends StatelessWidget {
  final Dive dive;
  final List<MediaItem> media;
  final String tripId;
  final bool initiallyExpanded;

  const _DivePhotoSection({
    required this.dive,
    required this.media,
    required this.tripId,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.MMMd();
    final siteName = dive.site?.name ?? 'Unknown Site';
    final diveNumber = dive.diveNumber != null ? 'Dive #${dive.diveNumber}' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Row(
          children: [
            if (diveNumber.isNotEmpty) ...[
              Text(
                diveNumber,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(' - '),
            ],
            Expanded(
              child: Text(
                siteName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${dateFormat.format(dive.dateTime)} (${media.length} photos)',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _PhotoGrid(
              media: media,
              tripId: tripId,
              diveId: dive.id,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoGrid extends ConsumerWidget {
  final List<MediaItem> media;
  final String tripId;
  final String diveId;

  const _PhotoGrid({
    required this.media,
    required this.tripId,
    required this.diveId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final item = media[index];
        return _GridThumbnail(
          item: item,
          tripId: tripId,
        );
      },
    );
  }
}

class _GridThumbnail extends ConsumerWidget {
  final MediaItem item;
  final String tripId;

  const _GridThumbnail({required this.item, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    if (item.platformAssetId == null) {
      return _buildPlaceholder(colorScheme);
    }

    final thumbnailAsync = ref.watch(
      assetThumbnailProvider(item.platformAssetId!),
    );

    return GestureDetector(
      onTap: () => _openViewer(context, ref),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: thumbnailAsync.when(
          data: (bytes) {
            if (bytes == null) return _buildPlaceholder(colorScheme);
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              cacheWidth: 200,
              cacheHeight: 200,
            );
          },
          loading: () => Container(
            color: colorScheme.surfaceContainerHighest,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, __) => _buildPlaceholder(colorScheme),
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TripPhotoViewerPage(
          tripId: tripId,
          initialMediaId: item.id,
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.photo, color: colorScheme.onSurfaceVariant),
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/trips/presentation/pages/trip_gallery_page_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/trips/presentation/pages/trip_gallery_page.dart test/features/trips/presentation/pages/trip_gallery_page_test.dart
git commit -m "feat(trips): add trip gallery page with photos grouped by dive"
```

---

## Task 5: Trip Photo Viewer Page

**Files:**
- Create: `lib/features/media/presentation/pages/trip_photo_viewer_page.dart`

**Step 1: Create trip-scoped photo viewer**

```dart
// lib/features/media/presentation/pages/trip_photo_viewer_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/widgets/mini_dive_profile_overlay.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';

/// Trip-scoped photo viewer that allows swiping through ALL photos in a trip
/// with dive context overlays that update when crossing dive boundaries.
class TripPhotoViewerPage extends ConsumerStatefulWidget {
  final String tripId;
  final String initialMediaId;

  const TripPhotoViewerPage({
    super.key,
    required this.tripId,
    required this.initialMediaId,
  });

  @override
  ConsumerState<TripPhotoViewerPage> createState() => _TripPhotoViewerPageState();
}

class _TripPhotoViewerPageState extends ConsumerState<TripPhotoViewerPage> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaByDiveAsync = ref.watch(mediaForTripProvider(widget.tripId));
    final flatMediaAsync = ref.watch(flatMediaListForTripProvider(widget.tripId));
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: flatMediaAsync.when(
        data: (mediaList) {
          if (mediaList.isEmpty) {
            return const Center(
              child: Text(
                'No photos available',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          // Find initial index
          final initialIndex = mediaList.indexWhere(
            (m) => m.id == widget.initialMediaId,
          );
          if (initialIndex != -1 && !_pageController.hasClients) {
            _currentIndex = initialIndex;
            _pageController = PageController(initialPage: initialIndex);
          }

          final currentItem = mediaList[_currentIndex];

          // Find the dive for current photo
          final mediaByDive = mediaByDiveAsync.valueOrNull ?? {};
          final currentDive = _findDiveForMedia(currentItem, mediaByDive);

          return GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! > 300) {
                Navigator.of(context).pop();
              }
            },
            child: Stack(
              children: [
                // Photo gallery
                PhotoViewGallery.builder(
                  scrollPhysics: const BouncingScrollPhysics(),
                  pageController: _pageController,
                  itemCount: mediaList.length,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  backgroundDecoration: const BoxDecoration(color: Colors.black),
                  builder: (context, index) {
                    final item = mediaList[index];
                    return PhotoViewGalleryPageOptions.customChild(
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 3.0,
                      child: _PhotoItem(item: item),
                    );
                  },
                  loadingBuilder: (context, event) => const Center(
                    child: CircularProgressIndicator(color: Colors.white54),
                  ),
                ),

                // Tap target to toggle overlays
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => setState(() => _showOverlay = !_showOverlay),
                    child: const SizedBox.expand(),
                  ),
                ),

                // Overlays
                if (_showOverlay) ...[
                  _TopOverlay(
                    currentIndex: _currentIndex,
                    totalCount: mediaList.length,
                    onClose: () => Navigator.of(context).pop(),
                    onShare: () => _shareCurrentPhoto(currentItem),
                  ),

                  // Mini dive profile
                  if (currentDive != null &&
                      currentDive.profile.isNotEmpty &&
                      currentItem.enrichment?.elapsedSeconds != null)
                    PositionedMiniProfileOverlay(
                      profile: currentDive.profile,
                      photoElapsedSeconds: currentItem.enrichment!.elapsedSeconds!,
                      photoDepthMeters: currentItem.enrichment?.depthMeters,
                      settings: settings,
                      visible: _showOverlay,
                    ),

                  _BottomMetadataOverlay(
                    item: currentItem,
                    dive: currentDive,
                    settings: settings,
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (error, stack) => Center(
          child: Text(
            'Error loading photos: $error',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Dive? _findDiveForMedia(MediaItem item, Map<Dive, List<MediaItem>> mediaByDive) {
    for (final entry in mediaByDive.entries) {
      if (entry.value.any((m) => m.id == item.id)) {
        return entry.key;
      }
    }
    return null;
  }

  Future<void> _shareCurrentPhoto(MediaItem item) async {
    if (item.platformAssetId == null) {
      _showError('Cannot share this photo');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      final bytes = await ref.read(
        assetFullResolutionProvider(item.platformAssetId!).future,
      );

      if (bytes == null) {
        throw Exception('Could not load image');
      }

      final tempDir = await getTemporaryDirectory();
      final filename = item.originalFilename ?? 'dive_photo.jpg';
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes);

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'image/jpeg')]),
      );
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showError('Failed to share: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _PhotoItem extends ConsumerWidget {
  final MediaItem item;

  const _PhotoItem({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.platformAssetId == null) {
      return const Center(
        child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
      );
    }

    final imageAsync = ref.watch(
      assetFullResolutionProvider(item.platformAssetId!),
    );

    return imageAsync.when(
      data: (bytes) {
        if (bytes == null) {
          return const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
          );
        }
        return PhotoView(
          imageProvider: MemoryImage(bytes),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3.0,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      ),
      error: (_, __) => const Center(
        child: Icon(Icons.error_outline, color: Colors.white54, size: 64),
      ),
    );
  }
}

class _TopOverlay extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final VoidCallback onClose;
  final VoidCallback onShare;

  const _TopOverlay({
    required this.currentIndex,
    required this.totalCount,
    required this.onClose,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onClose,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${currentIndex + 1} / $totalCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: onShare,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomMetadataOverlay extends StatelessWidget {
  final MediaItem item;
  final Dive? dive;
  final AppSettings settings;

  const _BottomMetadataOverlay({
    required this.item,
    required this.dive,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final enrichment = item.enrichment;
    final formatter = UnitFormatter(settings);
    final timeFormat = DateFormat.jm();
    final dateFormat = DateFormat.yMMMd();
    final siteName = dive?.site?.name;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Site name
                if (siteName != null && siteName.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          siteName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Metadata row
                Row(
                  children: [
                    if (enrichment?.depthMeters != null) ...[
                      _MetadataChip(
                        icon: Icons.arrow_downward,
                        value: formatter.formatDepth(
                          enrichment!.depthMeters,
                          decimals: 1,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (enrichment?.temperatureCelsius != null) ...[
                      _MetadataChip(
                        icon: Icons.thermostat,
                        value: formatter.formatTemperature(
                          enrichment!.temperatureCelsius,
                          decimals: 0,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (enrichment?.elapsedSeconds != null) ...[
                      _MetadataChip(
                        icon: Icons.timer_outlined,
                        value: _formatElapsedTime(enrichment!.elapsedSeconds!),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                // Timestamp
                Text(
                  '${dateFormat.format(item.takenAt)} at ${timeFormat.format(item.takenAt)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatElapsedTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '+$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String value;

  const _MetadataChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/media/presentation/pages/trip_photo_viewer_page.dart
git commit -m "feat(media): add trip-scoped photo viewer with dive context overlays"
```

---

## Task 6: Add Gallery Route

**Files:**
- Modify: `lib/core/router/app_router.dart`

**Step 1: Add import**

```dart
import 'package:submersion/features/trips/presentation/pages/trip_gallery_page.dart';
```

**Step 2: Add gallery route under trips**

Find the trips routes section (~line 494) and add after the edit route:

```dart
              GoRoute(
                path: ':tripId',
                name: 'tripDetail',
                builder: (context, state) =>
                    TripDetailPage(tripId: state.pathParameters['tripId']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editTrip',
                    builder: (context, state) =>
                        TripEditPage(tripId: state.pathParameters['tripId']),
                  ),
                  // NEW: Gallery route
                  GoRoute(
                    path: 'gallery',
                    name: 'tripGallery',
                    builder: (context, state) => TripGalleryPage(
                      tripId: state.pathParameters['tripId']!,
                      initialMediaId: state.uri.queryParameters['mediaId'],
                    ),
                  ),
                ],
              ),
```

**Step 3: Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat(router): add trip gallery route"
```

---

## Task 7: Trip Media Scanner Service

**Files:**
- Create: `lib/features/media/data/services/trip_media_scanner.dart`
- Test: `test/features/media/data/services/trip_media_scanner_test.dart`

**Step 1: Write the failing test**

```dart
// test/features/media/data/services/trip_media_scanner_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';

void main() {
  group('TripMediaScanner', () {
    group('matchPhotoToDive', () {
      test('returns dive when photo is within dive time range', () {
        final dive = Dive(
          id: 'dive-1',
          dateTime: DateTime(2024, 1, 15, 10, 0),
          entryTime: DateTime(2024, 1, 15, 10, 0),
          exitTime: DateTime(2024, 1, 15, 11, 0),
          duration: const Duration(minutes: 60),
        );

        final photoTime = DateTime(2024, 1, 15, 10, 30);
        final result = TripMediaScanner.matchPhotoToDive(photoTime, [dive]);

        expect(result, equals(dive));
      });

      test('returns null when photo is outside all dive time ranges', () {
        final dive = Dive(
          id: 'dive-1',
          dateTime: DateTime(2024, 1, 15, 10, 0),
          entryTime: DateTime(2024, 1, 15, 10, 0),
          exitTime: DateTime(2024, 1, 15, 11, 0),
          duration: const Duration(minutes: 60),
        );

        final photoTime = DateTime(2024, 1, 15, 15, 0); // 4 hours later
        final result = TripMediaScanner.matchPhotoToDive(photoTime, [dive]);

        expect(result, isNull);
      });

      test('returns dive when photo is within buffer zone', () {
        final dive = Dive(
          id: 'dive-1',
          dateTime: DateTime(2024, 1, 15, 10, 0),
          entryTime: DateTime(2024, 1, 15, 10, 0),
          exitTime: DateTime(2024, 1, 15, 11, 0),
          duration: const Duration(minutes: 60),
        );

        // 20 minutes before entry (within 30 min buffer)
        final photoTime = DateTime(2024, 1, 15, 9, 40);
        final result = TripMediaScanner.matchPhotoToDive(
          photoTime,
          [dive],
          bufferMinutes: 30,
        );

        expect(result, equals(dive));
      });
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/services/trip_media_scanner_test.dart`
Expected: FAIL

**Step 3: Write implementation**

```dart
// lib/features/media/data/services/trip_media_scanner.dart
import 'package:photo_manager/photo_manager.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Result of scanning device gallery for trip photos
class ScanResult {
  /// Photos matched to specific dives
  final Map<Dive, List<AssetEntity>> matchedByDive;

  /// Photos within trip date range but not matched to any dive
  final List<AssetEntity> unmatched;

  /// Photos already linked (filtered out)
  final int alreadyLinkedCount;

  const ScanResult({
    required this.matchedByDive,
    required this.unmatched,
    required this.alreadyLinkedCount,
  });

  /// Total new photos found
  int get totalNewPhotos =>
      matchedByDive.values.fold(0, (sum, list) => sum + list.length) +
      unmatched.length;

  /// Total matched photos (excluding unmatched)
  int get totalMatchedPhotos =>
      matchedByDive.values.fold(0, (sum, list) => sum + list.length);
}

/// Service for scanning device gallery and matching photos to dives
class TripMediaScanner {
  /// Match a photo timestamp to a dive from the list.
  ///
  /// Returns the dive if photo was taken:
  /// 1. During the dive (between entry and exit times)
  /// 2. Within [bufferMinutes] of dive boundaries
  ///
  /// Returns null if no match found.
  static Dive? matchPhotoToDive(
    DateTime photoTime,
    List<Dive> dives, {
    int bufferMinutes = 30,
  }) {
    final buffer = Duration(minutes: bufferMinutes);

    for (final dive in dives) {
      final entryTime = dive.entryTime ?? dive.dateTime;
      DateTime exitTime;

      if (dive.exitTime != null) {
        exitTime = dive.exitTime!;
      } else if (dive.duration != null) {
        exitTime = entryTime.add(dive.duration!);
      } else {
        // Default to 1 hour if no exit time or duration
        exitTime = entryTime.add(const Duration(hours: 1));
      }

      // Check if photo is within dive time (including buffer)
      final bufferedEntry = entryTime.subtract(buffer);
      final bufferedExit = exitTime.add(buffer);

      if (photoTime.isAfter(bufferedEntry) && photoTime.isBefore(bufferedExit)) {
        return dive;
      }
    }

    return null;
  }

  /// Scan device gallery for photos within trip date range and match to dives.
  ///
  /// [dives] - All dives in the trip
  /// [tripStartDate] - Trip start date
  /// [tripEndDate] - Trip end date
  /// [existingAssetIds] - Platform asset IDs already linked (to filter out)
  static Future<ScanResult> scanGalleryForTrip({
    required List<Dive> dives,
    required DateTime tripStartDate,
    required DateTime tripEndDate,
    required Set<String> existingAssetIds,
  }) async {
    // Request permission
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      return const ScanResult(
        matchedByDive: {},
        unmatched: [],
        alreadyLinkedCount: 0,
      );
    }

    // Add 1 hour buffer to trip dates for edge cases
    final startWithBuffer = tripStartDate.subtract(const Duration(hours: 1));
    final endWithBuffer = tripEndDate.add(const Duration(hours: 1));

    // Fetch photos from gallery within trip date range
    final filterOption = FilterOptionGroup(
      imageOption: const FilterOption(
        sizeConstraint: SizeConstraint(ignoreSize: true),
      ),
      videoOption: const FilterOption(
        sizeConstraint: SizeConstraint(ignoreSize: true),
      ),
      createTimeCond: DateTimeCond(
        min: startWithBuffer,
        max: endWithBuffer,
      ),
    );

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common, // Photos and videos
      filterOption: filterOption,
    );

    // Get all assets from all albums
    final List<AssetEntity> allAssets = [];
    for (final album in albums) {
      final assets = await album.getAssetListRange(start: 0, end: 10000);
      allAssets.addAll(assets);
    }

    // Remove duplicates by ID
    final uniqueAssets = <String, AssetEntity>{};
    for (final asset in allAssets) {
      uniqueAssets[asset.id] = asset;
    }

    // Filter out already linked photos and match to dives
    final Map<Dive, List<AssetEntity>> matchedByDive = {};
    final List<AssetEntity> unmatched = [];
    int alreadyLinkedCount = 0;

    for (final asset in uniqueAssets.values) {
      if (existingAssetIds.contains(asset.id)) {
        alreadyLinkedCount++;
        continue;
      }

      final createTime = asset.createDateTime;
      final matchedDive = matchPhotoToDive(createTime, dives);

      if (matchedDive != null) {
        matchedByDive.putIfAbsent(matchedDive, () => []).add(asset);
      } else {
        unmatched.add(asset);
      }
    }

    return ScanResult(
      matchedByDive: matchedByDive,
      unmatched: unmatched,
      alreadyLinkedCount: alreadyLinkedCount,
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/data/services/trip_media_scanner_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/media/data/services/trip_media_scanner.dart test/features/media/data/services/trip_media_scanner_test.dart
git commit -m "feat(media): add trip media scanner service for timestamp matching"
```

---

## Task 8: Scan Results Dialog

**Files:**
- Create: `lib/features/media/presentation/widgets/scan_results_dialog.dart`

**Step 1: Create the dialog widget**

```dart
// lib/features/media/presentation/widgets/scan_results_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';

/// Result returned from the scan results dialog
class ScanDialogResult {
  final bool confirmed;
  final Map<Dive, List<AssetEntity>> selectedPhotos;

  const ScanDialogResult({
    required this.confirmed,
    required this.selectedPhotos,
  });
}

/// Bottom sheet dialog showing scan results with selection options
class ScanResultsDialog extends StatefulWidget {
  final ScanResult scanResult;

  const ScanResultsDialog({super.key, required this.scanResult});

  @override
  State<ScanResultsDialog> createState() => _ScanResultsDialogState();
}

class _ScanResultsDialogState extends State<ScanResultsDialog> {
  late Map<Dive, bool> _selectedDives;

  @override
  void initState() {
    super.initState();
    // Initialize all dives as selected
    _selectedDives = Map.fromEntries(
      widget.scanResult.matchedByDive.keys.map((dive) => MapEntry(dive, true)),
    );
  }

  int get _selectedCount {
    int count = 0;
    for (final entry in widget.scanResult.matchedByDive.entries) {
      if (_selectedDives[entry.key] == true) {
        count += entry.value.length;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateFormat = DateFormat.MMMd();

    if (widget.scanResult.totalNewPhotos == 0) {
      return _buildNoPhotosFound(context, colorScheme, textTheme);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Found ${widget.scanResult.totalNewPhotos} new photos',
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Dive list with checkboxes
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ...widget.scanResult.matchedByDive.entries.map((entry) {
                      final dive = entry.key;
                      final photos = entry.value;
                      final siteName = dive.site?.name ?? 'Unknown Site';
                      final diveNumber = dive.diveNumber != null
                          ? 'Dive #${dive.diveNumber}'
                          : '';

                      return CheckboxListTile(
                        value: _selectedDives[dive],
                        onChanged: (value) {
                          setState(() => _selectedDives[dive] = value ?? false);
                        },
                        title: Row(
                          children: [
                            if (diveNumber.isNotEmpty) ...[
                              Text(
                                diveNumber,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(' - '),
                            ],
                            Expanded(
                              child: Text(
                                siteName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(dateFormat.format(dive.dateTime)),
                        secondary: Text(
                          '${photos.length}',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }),

                    // Unmatched photos warning
                    if (widget.scanResult.unmatched.isNotEmpty) ...[
                      const Divider(),
                      ListTile(
                        leading: Icon(
                          Icons.warning_amber,
                          color: colorScheme.tertiary,
                        ),
                        title: Text(
                          'Unmatched photos',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.tertiary,
                          ),
                        ),
                        subtitle: const Text('Outside dive time ranges'),
                        trailing: Text(
                          '${widget.scanResult.unmatched.length}',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(
                      const ScanDialogResult(confirmed: false, selectedPhotos: {}),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _selectedCount > 0 ? _onLink : null,
                    child: Text('Link $_selectedCount photos'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPhotosFound(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              widget.scanResult.alreadyLinkedCount > 0
                  ? 'All photos already linked'
                  : 'No photos found',
              style: textTheme.titleMedium,
            ),
            if (widget.scanResult.alreadyLinkedCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${widget.scanResult.alreadyLinkedCount} photos were already in your trip',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                const ScanDialogResult(confirmed: false, selectedPhotos: {}),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  void _onLink() {
    final selectedPhotos = <Dive, List<AssetEntity>>{};
    for (final entry in widget.scanResult.matchedByDive.entries) {
      if (_selectedDives[entry.key] == true) {
        selectedPhotos[entry.key] = entry.value;
      }
    }

    Navigator.of(context).pop(
      ScanDialogResult(confirmed: true, selectedPhotos: selectedPhotos),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/media/presentation/widgets/scan_results_dialog.dart
git commit -m "feat(media): add scan results dialog for photo linking confirmation"
```

---

## Task 9: Wire Up Scan Functionality

**Files:**
- Modify: `lib/features/trips/presentation/pages/trip_detail_page.dart`
- Modify: `lib/features/trips/presentation/widgets/trip_photo_section.dart`
- Modify: `lib/features/trips/presentation/pages/trip_gallery_page.dart`

**Step 1: Update trip_detail_page.dart with actual scan logic**

Add imports:
```dart
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/presentation/widgets/scan_results_dialog.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
```

Replace the placeholder `_showScanDialog` method with:
```dart
  Future<void> _showScanDialog(
    BuildContext context,
    WidgetRef ref,
    String tripId,
  ) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get trip and dives
      final trip = tripWithStats.trip;
      final dives = await ref.read(divesForTripProvider(tripId).future);

      if (dives.isEmpty) {
        if (context.mounted) Navigator.of(context).pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add dives first to match photos')),
          );
        }
        return;
      }

      // Get existing asset IDs to filter
      final mediaByDive = await ref.read(mediaForTripProvider(tripId).future);
      final existingIds = <String>{};
      for (final mediaList in mediaByDive.values) {
        for (final item in mediaList) {
          if (item.platformAssetId != null) {
            existingIds.add(item.platformAssetId!);
          }
        }
      }

      // Scan gallery
      final result = await TripMediaScanner.scanGalleryForTrip(
        dives: dives,
        tripStartDate: trip.startDate,
        tripEndDate: trip.endDate,
        existingAssetIds: existingIds,
      );

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Dismiss loading

      // Show results dialog
      final dialogResult = await showModalBottomSheet<ScanDialogResult>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ScanResultsDialog(scanResult: result),
      );

      if (dialogResult == null || !dialogResult.confirmed) return;
      if (!context.mounted) return;

      // Import selected photos
      await _importPhotos(context, ref, dialogResult.selectedPhotos);

      // Refresh providers
      ref.invalidate(mediaForTripProvider(tripId));
      ref.invalidate(mediaCountForTripProvider(tripId));
      ref.invalidate(flatMediaListForTripProvider(tripId));

    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning: $e')),
        );
      }
    }
  }

  Future<void> _importPhotos(
    BuildContext context,
    WidgetRef ref,
    Map<Dive, List<AssetEntity>> photosByDive,
  ) async {
    // Show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Linking photos...'),
          ],
        ),
      ),
    );

    try {
      final importService = MediaImportService();
      int totalImported = 0;

      for (final entry in photosByDive.entries) {
        final dive = entry.key;
        final assets = entry.value;

        final result = await importService.importPhotosForDive(
          diveId: dive.id,
          assets: assets,
          diveProfile: dive.profile,
          diveStartTime: dive.entryTime ?? dive.dateTime,
        );

        totalImported += result.importedCount;

        // Invalidate media providers for this dive
        ref.invalidate(mediaForDiveProvider(dive.id));
        ref.invalidate(mediaCountForDiveProvider(dive.id));
      }

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Dismiss progress

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Linked $totalImported photos')),
      );
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error linking photos: $e')),
        );
      }
    }
  }
```

Also add the import for AssetEntity:
```dart
import 'package:photo_manager/photo_manager.dart';
```

**Step 2: Copy scan logic to gallery page**

Add the same imports and methods to `trip_gallery_page.dart`, adapting for the widget context.

**Step 3: Run app and test**

Run: `flutter run -d macos`
Test the full scan → link flow.

**Step 4: Commit**

```bash
git add lib/features/trips/presentation/pages/trip_detail_page.dart lib/features/trips/presentation/pages/trip_gallery_page.dart
git commit -m "feat(trips): wire up photo scan and link functionality"
```

---

## Task 10: Final Testing and Polish

**Step 1: Run all tests**

Run: `flutter test`
Verify all tests pass (308+ passing, only pre-existing tag failures).

**Step 2: Run the app and test all flows**

1. Open trip detail page → verify photo section appears
2. Tap "View All" → verify gallery page opens
3. Tap photo → verify trip-scoped viewer opens
4. Swipe through photos → verify dive context updates
5. Tap "Scan" → verify scan dialog appears
6. Link photos → verify they appear in gallery

**Step 3: Format and analyze**

Run: `dart format lib/ test/`
Run: `flutter analyze`

Fix any issues found.

**Step 4: Final commit**

```bash
git add -A
git commit -m "chore: polish and cleanup trip photo galleries feature"
```

---

## Summary

| Task | Files | Description |
|------|-------|-------------|
| 1 | trip_media_providers.dart | Aggregation providers for trip media |
| 2 | trip_photo_section.dart | Preview section widget |
| 3 | trip_detail_page.dart | Integrate photo section |
| 4 | trip_gallery_page.dart | Full gallery with dive grouping |
| 5 | trip_photo_viewer_page.dart | Trip-scoped photo viewer |
| 6 | app_router.dart | Add gallery route |
| 7 | trip_media_scanner.dart | Gallery scan service |
| 8 | scan_results_dialog.dart | Link confirmation dialog |
| 9 | Wire up scan | Connect scan to import |
| 10 | Polish | Testing and cleanup |

**Total estimated time:** 2-3 hours of focused implementation
