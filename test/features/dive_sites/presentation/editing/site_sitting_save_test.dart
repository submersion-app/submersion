import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/site_edit_save_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_save.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// A save the service refuses because this profile may no longer edit the
/// site.
class _Refusing extends SiteEditSaveService {
  _Refusing() : super(SiteRepository());

  @override
  Future<({DiveSite before, DiveSite after})?> save({
    required String siteId,
    required DiveSite Function(DiveSite stored) apply,
    required Iterable<String> changedCardIds,
    String? actingDiverId,
    Future<void> Function()? writeFirst,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
    Set<String> Function()? heldLibraryFields,
    bool privateOnly = false,
  }) async => throw const SiteEditRefused('s1');
}

/// The site page says why a Save was refused (issue #4527, phase 2).
void main() {
  test('a Save refused for a lost right says so', () async {
    final session = EditSession<DiveSite>(
      const DiveSite(id: 's1', name: 'Blue Hole'),
    );
    addTearDown(session.dispose);

    final error = await saveSiteSitting(
      session,
      _Refusing(),
    ).then<Object?>((_) => null, onError: (Object e) => e);

    expect(error, isA<RecordSittingRefusal>());
    final l10n = AppLocalizationsEn();
    expect(
      (error! as RecordSittingRefusal).message(l10n),
      l10n.diveSites_edit_saveRefused,
    );
  });

  // A new site's photos are queued for their store once it is created, as
  // a stored site's are once saved (issue #4527, plan 6).
  group('a new site', () {
    setUp(() async {
      final db = await setUpTestDatabase();
      await insertDiver(db, 'me');
    });
    tearDown(tearDownTestDatabase);

    test('queues its new media rows for upload once created', () async {
      final at = DateTime.utc(2026, 11, 19);
      final enqueued = <String>[];
      final session = EditSession<DiveSite>(
        const DiveSite(id: 'n1', diverId: 'me', name: ''),
        isNew: true,
      );
      addTearDown(session.dispose);
      holdSittingMedia(
        session,
        SittingMediaWriters(
          writeRows: (prepared) async => [for (final p in prepared) p.item.id],
          insertNetwork: (_) async => const [],
          unlink: (_) async {},
          replace: (_, _, _) async {},
          drainDeletes: () async {},
          enqueueUpload: enqueued.add,
        ),
        cardId: 'media',
      );
      session.set(siteNameField, 'Blue Hole');
      addMediaToSitting(session, [
        HeldMediaRow((
          item: MediaItem(
            id: 'm1',
            siteId: 'n1',
            mediaType: MediaType.photo,
            originalFilename: 'reef.jpg',
            takenAt: at,
            createdAt: at,
            updatedAt: at,
          ),
          enrichment: null,
        )),
      ]);

      final created = await createSiteSitting(
        session,
        SiteEditSaveService(SiteRepository()),
      );

      expect(created.id, 'n1');
      expect((await SiteRepository().getSiteById('n1'))?.name, 'Blue Hole');
      expect(enqueued, ['m1']);
    });
  });
}
