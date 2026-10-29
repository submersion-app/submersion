import 'dart:math';

import 'package:drift/drift.dart' show Variable;
import 'package:path/path.dart' as p;
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_smart_album_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../story/destination_life.dart';
import '../story/story_plan.dart';
import 'dive_kit.dart';
import 'seed_context.dart';

/// The demo photos, linked (never copied, as the app does with real photos)
/// to the dives that carried the camera where they belong, up to three a
/// dive, with their credits, species and tags.
class MediaSeeder implements DemoSeeder {
  @override
  String get name => 'photos';

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    final media = MediaRepository();
    final species = MediaSpeciesRepository();
    final people = MediaPeopleRepository();
    final tags = TagLinkRepository(TagScope.media);
    final dives = DiveRepository();
    final cameraDives = ctx.plan.dives
        .where((d) => isPhotoDive(d, ctx.timeline))
        .toList();
    final onDive = <int, int>{};
    String? turtleTrip;
    var n = 0;
    for (final photo in ctx.photoFiles) {
      final dive = _diveFor(photo, cameraDives, onDive, n);
      // A photo of something none of the camera dives met stays out of the
      // logbook, and so out of the package.
      if (dive == null) continue;
      final shot = onDive[dive.number] = (onDive[dive.number] ?? 0) + 1;
      final id = 'demo-media-${n++}';
      ctx.linkedPhotos.add(photo.fileName);
      // Relative to the package: the device relinks it into its own photo
      // folder, and the build machine's folders never reach the public file.
      final path = p.posix.join('photos', photo.fileName);
      // A dive's photos are spread through it, a quarter of the way in
      // and on, and each records the profile's depth and water at its
      // moment, as the import pipeline does for a real photo.
      final profile = await dives.getDiveProfile(ctx.diveId(dive.number));
      final elapsed =
          (profile.last.timestamp * (0.05 + 0.2 * shot)).round() + 15 * (n % 5);
      final at = profile.lastWhere((s) => s.timestamp <= elapsed);
      final taken = dive.start.add(Duration(seconds: elapsed));
      final site = ctx.plan.sites.firstWhere((s) => s.id == dive.siteId);
      await media.createMedia(
        MediaItem(
          id: id,
          diveId: ctx.diveId(dive.number),
          siteId: ctx.siteId(dive.siteId),
          mediaType: MediaType.photo,
          sourceType: MediaSourceType.localFile,
          filePath: path,
          localPath: path,
          originalFilename: photo.fileName,
          caption: '${_title(photo)}. Photo: ${photo.credit}',
          latitude: site.latitude,
          longitude: site.longitude,
          // On the dive's clock: wall-clock time stored as UTC.
          takenAt: asWallClockUtc(taken),
          createdAt: taken,
          updatedAt: taken,
        ),
      );
      // Where the photo sits on the dive, so its marker appears on the
      // dive's chart.
      await ctx.db.customInsert(
        'INSERT INTO media_enrichment (id, media_id, dive_id, depth_meters, '
        'temperature_celsius, elapsed_seconds, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('demo-enrichment-$id'),
          Variable.withString(id),
          Variable.withString(ctx.diveId(dive.number)),
          Variable(at.depth),
          Variable(at.temperature),
          Variable.withInt(elapsed),
          Variable.withInt(taken.millisecondsSinceEpoch),
        ],
      );
      await tags.replaceTags(id, [
        ctx.tags['Photo']!,
        if (n % 4 == 0) ctx.tags['Favourite']!,
      ]);
      final speciesId = ctx.species[photo.subject];
      if (speciesId != null) {
        await species.addTag(mediaId: id, speciesId: speciesId);
        if (photo.subject.contains('Turtle')) turtleTrip ??= dive.tripId;
      }
      // Every third photo is tagged with a buddy from its dive (issue
      // #1745), without a spot: the demo photos show marine life, so there
      // is no face to box.
      if (n % 3 == 0) {
        final buddy = await ctx.db
            .customSelect(
              'SELECT buddy_id FROM dive_buddies WHERE dive_id = ? '
              'ORDER BY buddy_id LIMIT 1',
              variables: [Variable.withString(ctx.diveId(dive.number))],
            )
            .getSingleOrNull();
        if (buddy != null) {
          await people.addTag(
            mediaId: id,
            buddyId: buddy.read<String>('buddy_id'),
          );
        }
      }
    }

    final albums = MediaSmartAlbumRepository();
    final turtle = ctx.species['Green Sea Turtle'];
    if (turtle != null) {
      await albums.create(
        name: 'Turtles',
        filter: MediaLibraryFilter(speciesId: turtle),
      );
    }
    final firstTrip = ctx.plan.trips.firstWhere(
      (t) => ctx.plan.dives.any((d) => d.tripId == t.id),
    );
    await albums.create(
      name: firstTrip.name,
      filter: MediaLibraryFilter(tripId: firstTrip.id),
    );
  }

  /// The most photos one dive keeps.
  static const _perDive = 3;

  /// A camera dive where the photo's subject lives (a species met there, or
  /// a reef or wreck dived there), taking the dives with the fewest photos
  /// first; null when there is none.
  static PlannedDive? _diveFor(
    DemoPhoto photo,
    List<PlannedDive> cameraDives,
    Map<int, int> onDive,
    int n,
  ) {
    final matching = [
      for (final d in cameraDives)
        if ((onDive[d.number] ?? 0) < _perDive &&
            (destinationSpecies[d.destination.key]!.contains(photo.subject) ||
                destinationSiteTypes[d.destination.key]!.contains(
                  photo.subject,
                )))
          d,
    ];
    if (matching.isEmpty) return null;
    final fewest = matching.map((d) => onDive[d.number] ?? 0).reduce(min);
    final pool = [
      for (final d in matching)
        if ((onDive[d.number] ?? 0) == fewest) d,
    ];
    return pool[(n * 7) % pool.length];
  }

  static String _title(DemoPhoto photo) =>
      photo.subject[0].toUpperCase() + photo.subject.substring(1);
}
