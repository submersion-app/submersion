import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo.dart';
import 'package:submersion/features/dive_log/domain/card_photo/focus_box.dart';

/// Reads which photos can stand behind each dive's card.
///
/// Two queries for the whole log, run once and shared by every card, rather
/// than one query per card as it scrolls into view.
class CardPhotoRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(CardPhotoRepository);

  /// Every dive-linked photo whose file is not known to be missing, grouped
  /// by dive id, each with the boxes of the people tagged on it. Videos,
  /// documents and signatures are left out: only a photo is drawn.
  Future<Map<String, List<CardPhoto>>> getCardPhotosByDive() async {
    try {
      final photoRows = await _db
          .customSelect(
            'SELECT id, dive_id FROM media '
            "WHERE dive_id IS NOT NULL AND file_type = 'photo' "
            'AND is_orphaned = 0',
            readsFrom: {_db.media},
          )
          .get();
      if (photoRows.isEmpty) return const {};

      final boxRows = await _db
          .customSelect(
            'SELECT p.media_id, p.bbox_x, p.bbox_y, p.bbox_width, p.bbox_height '
            'FROM media_people p JOIN media m ON m.id = p.media_id '
            "WHERE m.dive_id IS NOT NULL AND m.file_type = 'photo' "
            'AND p.bbox_x IS NOT NULL AND p.bbox_y IS NOT NULL '
            'AND p.bbox_width IS NOT NULL AND p.bbox_height IS NOT NULL',
            readsFrom: {_db.media, _db.mediaPeople},
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
