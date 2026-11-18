import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/widgets/dive_media_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MediaRepository repo;
  late SharedPreferences prefs;

  final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = MediaRepository();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(tearDownTestDatabase);

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(epoch),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  MediaItem item(String id, {String? diveId}) => MediaItem(
    id: id,
    diveId: diveId,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: '/tmp/$id',
    localPath: '/tmp/$id',
    takenAt: DateTime(2026, 6, 1),
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );

  testWidgets('in an open sitting the selection bar offers Unlink and no '
      'Delete; Unlink holds the unlink and writes nothing', (tester) async {
    await insertDive('d1');
    await repo.createMedia(item('m1', diveId: 'd1'));

    // Only the open card unlinks, and it holds the unlink until Save
    // (issue #4673).
    final controller = RecordEditController<Dive>(onSave: (_) async {})
      ..unlock(Dive(id: 'd1', dateTime: DateTime(2026)));
    addTearDown(controller.dispose);
    final session = controller.session!;
    final unlinkWrites = <List<String>>[];
    holdSittingMedia(
      session,
      SittingMediaWriters(
        writeRows: (_) async => const [],
        insertNetwork: (_) async => const [],
        unlink: (ids) async => unlinkWrites.add(ids),
        replace: (_, _, _) async {},
        drainDeletes: () async {},
        enqueueUpload: (_) {},
      ),
      cardId: DiveDetailSectionId.media.name,
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiveMediaSection(diveId: 'd1', editing: session),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });

    // Entry is the keyed Select affordance: long-press was removed as a
    // selection entry across every surface (PR #1021).
    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_select_all')));
    await tester.pumpAndSettle();

    // Unlink is the only bulk action here. There is no separate delete
    // because unlink IS the removal (at Save): the row, the cloud proxies
    // and the thumbnails all go, and only the original source file is left
    // alone.
    expect(
      find.byKey(const ValueKey('selection_action_unlink')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('selection_delete')), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    await tester.tap(find.byKey(const ValueKey('selection_action_unlink')));
    await tester.pumpAndSettle();
    expect(find.text('Unlink 1 items?'), findsOneWidget);
    await tester.tap(find.text('Unlink'));
    await tester.pumpAndSettle();

    // Held in the sitting, and nothing written: the row keeps its link until
    // Save. Read in the real zone, where database calls move.
    expect(sittingMedia(session).unlinked, {'m1'});
    expect(unlinkWrites, isEmpty);
    final row = await tester.runAsync(() => repo.getMediaById('m1'));
    expect(row, isNotNull);
    expect(row!.diveId, 'd1');
  });
}
