import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/media_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/json_object_codec.dart';
import 'package:submersion/features/agent_access/data/writes/object_list_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/media/data/repositories/media_color_adjustment_repository.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/repositories/site_attachment_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/media_dive_window.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart'
    as attachment;
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

/// How long dive [diveId]'s profile runs, in seconds: the latest moment a
/// photo can be pinned to.
typedef DiveProfileLength = Future<int> Function(String diveId);

/// A photo or video's edits, through the services the media viewer uses:
/// its moment on its dive, the dive it is on, who and what is in it, its
/// colour, a site attachment's details, and its delete, which holds the
/// cloud copy's delete as the viewer's does. Media is added in the app.
class MediaWrites extends WritableEntry {
  MediaWrites(
    this._r, {
    DiveProfileLength? profileLength,
    Future<void> Function()? kickWorker,
    MediaTransferQueueRepository Function()? transferQueue,
  }) : _profileLength = profileLength,
       _kickWorker = kickWorker,
       _transferQueue = transferQueue;

  final RecordRepositories _r;
  final DiveProfileLength? _profileLength;

  /// What would start the media store's worker; a held delete never calls
  /// it, so the change log can still put the cloud copy back.
  final Future<void> Function()? _kickWorker;

  /// The queue a cloud copy's delete waits in.
  final MediaTransferQueueRepository Function()? _transferQueue;
  final _people = MediaPeopleRepository();
  final _speciesTags = MediaSpeciesRepository();
  final _colors = MediaColorAdjustmentRepository();
  final _attachments = SiteAttachmentRepository();

  late final _tagging = SpeciesTaggingService(
    tags: _speciesTags,
    media: _r.media,
    species: _r.species,
  );
  late final _deletion = MediaDeletionCoordinator(
    mediaRepository: _r.media,
    queue: _transferQueue ?? MediaTransferQueueRepository.new,
    kickWorker: _kickWorker,
  );

  @override
  String get name => 'media';

  @override
  String get table => 'media';

  @override
  String get note =>
      'Media is added in the app; here it is edited or deleted. '
      'manual_elapsed_s pins it to a moment of its dive, 0 to the profile\'s '
      'end. people is the whole list, each a buddy_id or a diver_id with an '
      'optional box (x, y, width, height, 0 to 1) and, on a video, '
      'video_position_ms; a person once per photo. A new species tag on a '
      'dive photo logs the dive\'s sighting when it has none. A delete holds '
      'the cloud copy\'s delete.';

  @override
  late final Map<String, FieldCodec> fields = {
    'manual_elapsed_s': const FieldCodec.integer(
      min: 0,
      max: 86400,
      nullable: true,
    ),
    'dive_id': const FieldCodec.reference('dives', nullable: true),
    'people': const ObjectListCodec({
      'buddy_id': FieldCodec.text(maxLength: 100, nullable: true),
      'diver_id': FieldCodec.text(maxLength: 100, nullable: true),
      'box': FieldCodec.numberMap(
        keys: {'x', 'y', 'width', 'height'},
        min: 0,
        max: 1,
        nullable: true,
      ),
      'video_position_ms': FieldCodec.integer(min: 0, nullable: true),
    }, maxItems: 50),
    'color_adjustment': const JsonObjectCodec(
      shape: 'a colour adjustment object',
      normalize: colorAdjustmentJson,
      nullable: true,
    ),
    'attachment_category': FieldCodec.enumName(
      SiteAttachmentCategory.values,
      nullable: true,
    ),
    'attachment_display_size': FieldCodec.enumName(
      AttachmentDisplaySize.values,
      nullable: true,
    ),
  };

  @override
  final Map<String, RelationSpec> relations = const {
    'species_ids': RelationSpec(refEntity: 'species'),
  };

  @override
  Set<String> get requiredOnCreate => const {};

  @override
  Future<Set<String>> currentRelation(String id, String relation) async => {
    for (final t in await _speciesTags.getTagsForMedia(id)) t.speciesId,
  };

  /// What a read leaves out that a write takes: the people, as a list a
  /// write sends back unchanged.
  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async => {
    ...document,
    'people': [
      for (final t in await _people.getTagsForMedia(id, diverId: null))
        _personJson(t),
    ],
  };

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (!currentDeviceCapabilities().mediaAttach) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'Media is not edited on this build of the app.',
      );
    }
    if (check.kind == ChangeKind.create) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'Media is added in the app, from a file, a camera roll or a link.',
      );
    }
    if (check.kind == ChangeKind.delete) return null;
    final v = check.values;
    final dive = v.containsKey('dive_id')
        ? v['dive_id'] as String?
        : check.document?['dive_id'] as String?;
    if (v['manual_elapsed_s'] case final int seconds) {
      if (dive == null) {
        return const PlanBlock(
          BlockReason.invalidValue,
          'manual_elapsed_s: only media on a dive is pinned to a moment.',
        );
      }
      final length = await _lengthOf(dive);
      if (seconds > length) {
        return PlanBlock(
          BlockReason.invalidValue,
          'manual_elapsed_s: 0 to the dive\'s $length seconds.',
        );
      }
    }
    if ((v.containsKey('attachment_category') ||
            v.containsKey('attachment_display_size')) &&
        check.document?['site_id'] == null) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'attachment_category and attachment_display_size are a site '
        'attachment\'s.',
      );
    }
    if (v['people'] case final Object people) {
      return _peopleProblem(
        ObjectListCodec.items(people),
        check.id!,
        check.ownerId,
      );
    }
    return null;
  }

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    final v = update.values;
    final dive = v.containsKey('dive_id')
        ? v['dive_id'] as String?
        : document['dive_id'] as String?;
    final parts =
        v.containsKey('dive_id') && v['dive_id'] != document['dive_id']
        ? await countOwned(const {'media_enrichment': 'media_id'}, id)
        : const <String, int>{};
    var sightings = 0;
    final added = update.relations['species_ids']?.add ?? const <String>{};
    if (dive != null && added.isNotEmpty) {
      final logged = {
        for (final s in await _r.species.getSightingsForDive(dive)) s.speciesId,
      };
      sightings = added.where((s) => !logged.contains(s)).length;
    }
    return SideEffects(
      parts: parts,
      created: {if (sightings > 0) 'sightings': sightings},
    );
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    final cloud = await countRows(
      'media',
      'id = ?1 AND remote_uploaded_at IS NOT NULL',
      id,
    );
    return DeleteReach(
      records: {if (cloud > 0) 'cloud_copies': cloud},
      parts: await countOwned(const {
        'media_people': 'media_id',
        'media_species': 'media_id',
        'media_tags': 'media_id',
        'media_enrichment': 'media_id',
      }, id),
    );
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) =>
      throw UnsupportedError('Media is added in the app.');

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final v = update.values;
    final media = _r.media;
    if (v.containsKey('dive_id')) {
      final dive = v['dive_id'] as String?;
      if (dive == null) {
        await media.unlinkFromDive([id]);
      } else {
        await media.reassignMediaToDive([id], dive);
      }
    }
    if (v.containsKey('manual_elapsed_s')) {
      await media.setManualElapsedSeconds(id, v['manual_elapsed_s'] as int?);
    }
    if (v['people'] case final Object people) {
      await _writePeople(id, ObjectListCodec.items(people));
    }
    if (update.relations['species_ids'] case final species?) {
      for (final s in species.add) {
        await _tagging.tagPhoto(mediaId: id, speciesId: s);
      }
      for (final s in species.remove) {
        await _tagging.untagPhoto(mediaId: id, speciesId: s);
      }
    }
    if (v.containsKey('color_adjustment')) {
      await _colors.setColorAdjustment(
        id,
        colorAdjustmentOf(switch (v['color_adjustment']) {
          final String json => JsonObjectCodec.decoded(json),
          _ => null,
        }),
      );
    }
    if (v.containsKey('attachment_category') ||
        v.containsKey('attachment_display_size')) {
      await _attachments.setAttachmentDetails(
        id,
        attachment.AttachmentDetailsEdit(
          category: v.containsKey('attachment_category')
              ? attachment.FieldChange(switch (v['attachment_category']) {
                  final String c => SiteAttachmentCategory.values.byName(c),
                  _ => null,
                })
              : null,
          displaySize: v.containsKey('attachment_display_size')
              ? attachment.FieldChange(switch (v['attachment_display_size']) {
                  final String s => AttachmentDisplaySize.values.byName(s),
                  _ => null,
                })
              : null,
        ),
      );
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) async {
    final item =
        await _r.media.getMediaById(id) ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Media $id no longer exists.',
          details: {'id': id},
        ));
    // Held, as the viewer's delete is: the cloud copy goes on the next
    // drain, and a revert that puts the row back first keeps it.
    await _deletion.deleteMediaItems([item], holdRemoteDelete: true);
  }

  Future<int> _lengthOf(String diveId) async {
    final length = _profileLength;
    if (length != null) return length(diveId);
    return MediaDiveWindow.profileLengthSeconds(
      await _r.dives.getDiveProfile(diveId),
    );
  }

  /// Why [people] cannot be the photo's, or null: each names one person,
  /// a buddy of the profile or a profile, and a photo holds a person once.
  Future<PlanBlock?> _peopleProblem(
    List<Map<String, Object?>> people,
    String mediaId,
    String? ownerId,
  ) async {
    final video = await countRows(
      'media',
      "id = ?1 AND file_type = 'video'",
      mediaId,
    );
    final seen = <String>{};
    for (final (i, p) in people.indexed) {
      final buddy = p['buddy_id'] as String?;
      final diver = p['diver_id'] as String?;
      if ((buddy == null) == (diver == null)) {
        return PlanBlock(
          BlockReason.invalidValue,
          'people: item $i names a buddy_id or a diver_id, not both.',
        );
      }
      final table = buddy != null ? 'buddies' : 'divers';
      if (await countRows(table, 'id = ?1', buddy ?? diver!) == 0) {
        return PlanBlock(
          BlockReason.unknownReference,
          'people: item $i names no ${buddy != null ? 'buddy' : 'profile'} '
          '${buddy ?? diver}.',
        );
      }
      // The people picker offers the photo's own profile's buddies: the
      // profile of the dive it is on, else the one acting.
      if (buddy != null &&
          await countRows(
                'buddies',
                'id = ?1 AND diver_id IS NOT NULL AND diver_id IS NOT '
                    'COALESCE((SELECT d.diver_id FROM media m JOIN dives d '
                    'ON d.id = m.dive_id WHERE m.id = ?2), ?3)',
                buddy,
                [mediaId, ownerId ?? ''],
              ) >
              0) {
        return PlanBlock(
          BlockReason.otherProfileReference,
          'people: item $i, buddy $buddy, belongs to another profile.',
        );
      }
      final key =
          '${buddy ?? diver}'
          '${video > 0 ? '@${p['video_position_ms']}' : ''}';
      if (!seen.add(key)) {
        return PlanBlock(
          BlockReason.invalidValue,
          'people: item $i tags ${buddy ?? diver} again; a person is on a '
          'photo once.',
        );
      }
    }
    return null;
  }

  /// Makes [people] the photo's tags: one kept where its person was,
  /// moved where its box changed, removed where its person left.
  Future<void> _writePeople(
    String mediaId,
    List<Map<String, Object?>> people,
  ) async {
    final current = await _people.getTagsForMedia(mediaId, diverId: null);
    String keyOf(String? buddy, String? diver) =>
        '${buddy ?? ''}|${diver ?? ''}';
    final wanted = {
      for (final p in people)
        keyOf(p['buddy_id'] as String?, p['diver_id'] as String?): p,
    };
    for (final tag in current) {
      if (!wanted.containsKey(keyOf(tag.buddyId, tag.diverId))) {
        await _people.removeTag(tag.id);
      }
    }
    for (final MapEntry(key: key, value: p) in wanted.entries) {
      final box = _box(p['box']);
      final position = switch (p['video_position_ms']) {
        final int ms => Duration(milliseconds: ms),
        _ => null,
      };
      final existing = current
          .where((t) => keyOf(t.buddyId, t.diverId) == key)
          .firstOrNull;
      if (existing == null) {
        await _people.addTag(
          mediaId: mediaId,
          buddyId: p['buddy_id'] as String?,
          diverId: p['diver_id'] as String?,
          box: box,
          videoPosition: position,
        );
      } else if (existing.box != box || existing.videoPosition != position) {
        await _people.updateTag(
          MediaPersonTag(
            id: existing.id,
            mediaId: mediaId,
            buddyId: existing.buddyId,
            diverId: existing.diverId,
            box: box,
            videoPosition: position,
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt,
          ),
        );
      }
    }
  }

  static FaceBox? _box(Object? raw) => raw is Map
      ? FaceBox(
          x: (raw['x'] as num).toDouble(),
          y: (raw['y'] as num).toDouble(),
          width: (raw['width'] as num).toDouble(),
          height: (raw['height'] as num).toDouble(),
        )
      : null;

  static Map<String, Object?> _personJson(MediaPersonTag t) => {
    'buddy_id': t.buddyId,
    'diver_id': t.diverId,
    'box': t.box == null
        ? null
        : {
            'x': t.box!.x,
            'y': t.box!.y,
            'width': t.box!.width,
            'height': t.box!.height,
          },
    'video_position_ms': t.videoPosition?.inMilliseconds,
  };
}
