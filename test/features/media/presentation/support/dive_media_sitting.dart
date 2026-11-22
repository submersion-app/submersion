import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// The open Media card's sitting on dive `dive-1`: selection and Unlink
/// belong to it alone (issue #4673). No test using it reaches Save, so its
/// writers write nothing, except that the unlink writer records the ids it
/// is given in [unlinkWrites] when one is passed. The controller is disposed
/// when the test ends.
///
/// Shared by the dive Media card tests so they hold media the same way.
EditSession<Dive> openDiveMediaSitting({List<List<String>>? unlinkWrites}) {
  final controller = RecordEditController<Dive>(onSave: (_) async {})
    ..unlock(Dive(id: 'dive-1', dateTime: DateTime.utc(2026)));
  addTearDown(controller.dispose);
  final session = controller.session!;
  holdSittingMedia(
    session,
    SittingMediaWriters(
      writeRows: (_) async => const [],
      insertNetwork: (_) async => const [],
      unlink: (ids) async => unlinkWrites?.add(ids),
      replace: (_, _, _) async {},
      drainDeletes: () async {},
      enqueueUpload: (_) {},
    ),
    cardId: DiveDetailSectionId.media.name,
  );
  return session;
}
