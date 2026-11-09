import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo.dart';
import 'package:submersion/features/dive_log/domain/card_photo/focus_box.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';

/// Reads which photos can stand behind each dive's card.
///
/// Two queries for the whole log, run once and shared by every card, rather
/// than one query per card as it scrolls into view.
class CardPhotoRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(CardPhotoRepository);

  /// The tags a diver owns, as MediaPeopleRepository scopes them: its own
  /// Me tags and the tags of its own buddies.
  /// The media rows a card may draw, as `m`: on a dive, a photo by every
  /// file_type spelling the app reads as one ([kNonPhotoFileTypes] lists the
  /// others, as for every photo count kept in SQL), and not known to be
  /// missing. Both queries share it, so they cannot disagree on which
  /// photos count.
  static final _photoWhere =
      'm.dive_id IS NOT NULL AND m.is_orphaned = 0 '
      'AND m.file_type NOT IN '
      '(${List.filled(kNonPhotoFileTypes.length, '?').join(', ')})';

  static List<Variable<Object>> get _photoVariables => [
    for (final type in kNonPhotoFileTypes) Variable.withString(type),
  ];

  /// Ticks when anything [getCardPhotosByDive] reads changes: a media row, a
  /// tagged person's box (written to `media_people` alone), or a buddy, whose
  /// owner decides whether its tags count. Nothing else, so enrichment and
  /// species writes do not rerun the whole-log queries.
  Stream<void> watchChanges() => _db
      .tableUpdates(
        TableUpdateQuery.onAllTables([_db.media, _db.mediaPeople, _db.buddies]),
      )
      .debounce(MediaRepository.changeTickDebounce);

  static const _ownedByDiver =
      ' AND (p.diver_id = ? OR p.buddy_id IN '
      '(SELECT id FROM buddies WHERE diver_id = ?))';

  /// Every dive-linked photo whose file is not known to be missing, grouped
  /// by dive id, each with the boxes of the people tagged on it. Videos,
  /// documents and signatures are left out: only a photo is drawn.
  ///
  /// Only tags [diverId] owns place the crop, as only those are shown to
  /// it: its own Me tags and its own buddies' tags, never a row that names
  /// nobody. A null [diverId] (no profile chosen) takes every named tag.
  Future<Map<String, List<CardPhoto>>> getCardPhotosByDive({
    required String? diverId,
  }) async {
    try {
      final photoRows = await _db
          .customSelect(
            'SELECT m.id, m.dive_id FROM media m WHERE $_photoWhere',
            variables: _photoVariables,
            readsFrom: {_db.media},
          )
          .get();
      if (photoRows.isEmpty) return const {};

      final boxRows = await _db
          .customSelect(
            'SELECT p.media_id, p.bbox_x, p.bbox_y, p.bbox_width, p.bbox_height '
            'FROM media_people p JOIN media m ON m.id = p.media_id '
            'WHERE $_photoWhere '
            'AND p.bbox_x IS NOT NULL AND p.bbox_y IS NOT NULL '
            'AND p.bbox_width IS NOT NULL AND p.bbox_height IS NOT NULL '
            'AND (p.buddy_id IS NOT NULL OR p.diver_id IS NOT NULL)'
            '${diverId == null ? '' : _ownedByDiver}',
            variables: [
              ..._photoVariables,
              if (diverId != null) ...[
                Variable.withString(diverId),
                Variable.withString(diverId),
              ],
            ],
            readsFrom: {_db.media, _db.mediaPeople, _db.buddies},
          )
          .get();
      final boxes = <String, List<FocusBox>>{};
      for (final row in boxRows) {
        (boxes[row.read<String>('media_id')] ??= []).add(
          FocusBox(
            x: row.read<double>('bbox_x'),
            y: row.read<double>('bbox_y'),
            width: row.read<double>('bbox_width'),
            height: row.read<double>('bbox_height'),
          ),
        );
      }

      final byDive = <String, List<CardPhoto>>{};
      for (final row in photoRows) {
        final id = row.read<String>('id');
        (byDive[row.read<String>('dive_id')] ??= []).add(
          CardPhoto(mediaId: id, focusBoxes: boxes[id] ?? const []),
        );
      }
      return byDive;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to read dive card photos',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
