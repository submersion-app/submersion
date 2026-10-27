import 'package:drift/drift.dart' show Variable;
import 'package:path/path.dart' as p;
import 'package:submersion/core/util/wall_clock_utc.dart';
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
import 'seed_context.dart';

/// The demo photos, linked (never copied, as the app does with real photos)
/// to dives where they belong, with their credits, species and tags.
class MediaSeeder implements DemoSeeder {
  @override
  String get name => 'photos';

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    final media = MediaRepository();
    final species = MediaSpeciesRepository();
    final tags = TagLinkRepository(TagScope.media);
    final candidates = ctx.plan.dives
        .where((d) => d.destination.key != 'home' && !d.night)
        .toList();
    String? turtleTrip;
    var n = 0;
    for (final photo in ctx.photoFiles) {
      final dive = _diveFor(ctx, photo, candidates, n);
      final id = 'demo-media-${n++}';
      // Relative to the package: the device relinks it into its own photo
      // folder, and the build machine's folders never reach the public file.
      final path = p.posix.join('photos', photo.fileName);
      final taken = dive.start.add(Duration(minutes: 12 + n * 3 % 30));
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
      // Where the photo sits on the dive: what the import pipeline records
      // from the profile, so the photo marker appears on the dive's chart.
      final elapsed = taken.difference(dive.start).inSeconds;
      final at = await ctx.db
          .customSelect(
            'SELECT max_depth * 0.7 AS depth, water_temp AS temp FROM dives '
            'WHERE id = ?',
            variables: [Variable.withString(ctx.diveId(dive.number))],
          )
          .getSingle();
      await ctx.db.customInsert(
        'INSERT INTO media_enrichment (id, media_id, dive_id, depth_meters, '
        'temperature_celsius, elapsed_seconds, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('demo-enrichment-$id'),
          Variable.withString(id),
          Variable.withString(ctx.diveId(dive.number)),
          Variable(at.read<double?>('depth')),
          Variable(at.read<double?>('temp')),
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

  /// A dive where the photo's subject lives, else any trip dive.
  static PlannedDive _diveFor(
    DemoSeedContext ctx,
    DemoPhoto photo,
    List<PlannedDive> candidates,
    int n,
  ) {
    final matching = candidates
        .where(
          (d) => destinationSpecies[d.destination.key]!.contains(photo.subject),
        )
        .toList();
    final pool = matching.isNotEmpty ? matching : candidates;
    return pool[(n * 7) % pool.length];
  }

  static String _title(DemoPhoto photo) =>
      photo.subject[0].toUpperCase() + photo.subject.substring(1);
}
