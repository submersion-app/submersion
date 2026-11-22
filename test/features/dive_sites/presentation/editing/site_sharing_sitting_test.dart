import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart' hide DiveSite;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/site_edit_save_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_edit_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sharing_sitting.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';
import 'package:submersion/shared/widgets/shared_items/item_sharing_field.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// Sharing a site with other profiles is held on the header block and
/// written with the sitting; a refusal fails the whole Save (issue #4527,
/// phase 2).
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  const site = DiveSite(id: 's1', diverId: 'me', name: 'Blue Hole');

  setUp(() async {
    db = await setUpTestDatabase();
    await insertDiver(db, 'me');
    await insertDiver(db, 'ana');
    await SiteRepository().createSite(site);
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  Future<EditSession<DiveSite>> loaded() async {
    final session = EditSession<DiveSite>(site);
    addTearDown(session.dispose);
    await loadSiteSharing(session, container.read, actingDiverId: 'me');
    return session;
  }

  Future<void> save(EditSession<DiveSite> session) =>
      SiteEditSaveService(SiteRepository()).save(
        siteId: 's1',
        apply: session.applyTo,
        changedCardIds: session.changedCardIds,
        alsoWrite: session.runHeldWrites,
        alsoWriteIsAChange: session.hasHeldChanges,
      );

  const withAna = ItemSharing(profileIds: {'ana'});

  // A library site follows its library: it shows no sharing and writes
  // none, so a sitting on it reads none.
  test('a library site reads no sharing', () async {
    final session = EditSession<DiveSite>(site.copyWith(sharedLibraryId: 'L'));
    addTearDown(session.dispose);

    await loadSiteSharing(session, container.read);

    expect(siteSharing.loaded(session), isNull);
    expect(siteSharing.unread(session), isFalse);
  });

  // A new site (issue #4527, plan 6) has no row to read: its sharing is
  // the seed's, the starting record, and a change from it is held.
  test('a new site\'s sharing is the seed\'s, read from nowhere', () async {
    final session = EditSession<DiveSite>(
      const DiveSite(id: 'n1', diverId: 'me', name: '', isShared: true),
      isNew: true,
    );
    addTearDown(session.dispose);

    await loadSiteSharing(session, container.read);

    expect(siteSharing.loaded(session), const ItemSharing(everyone: true));
    expect(siteSharing.unread(session), isFalse);
    expect(session.isDirty, isFalse);
    siteSharing.set(session, ItemSharing.none, actingDiverId: 'me');
    expect(session.changedCardIds, {siteHeaderCardId});
  });

  test(
    'choosing other profiles holds the change and dots the header',
    () async {
      final session = await loaded();
      expect(siteSharing.inSitting(session), ItemSharing.none);

      siteSharing.set(session, withAna, actingDiverId: 'me');

      expect(siteSharing.inSitting(session), withAna);
      expect(session.changedCardIds, {siteHeaderCardId});
      expect(
        await ItemSharesRepository().sharingOf(SharedItemKind.site, 's1'),
        ItemSharing.none,
      );
    },
  );

  test('choosing the loaded value releases it', () async {
    final session = await loaded();
    siteSharing.set(session, withAna, actingDiverId: 'me');

    siteSharing.set(session, ItemSharing.none, actingDiverId: 'me');

    expect(session.isDirty, isFalse);
  });

  test('Save writes the sharing with the site', () async {
    final session = await loaded();
    siteSharing.set(session, withAna, actingDiverId: 'me');

    await SiteEditSaveService(SiteRepository()).save(
      siteId: 's1',
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
      alsoWrite: session.runHeldWrites,
      alsoWriteIsAChange: session.hasHeldChanges,
    );

    expect(
      await ItemSharesRepository().sharingOf(SharedItemKind.site, 's1'),
      withAna,
    );
  });

  // A sync race can leave share rows beside the Everyone flag; the owner's
  // next Save that changes something clears them, as a trip's does (plan
  // 12, Question 4). Upkeep alone is no change: Cancel does not ask.
  test('stray share rows beside Everyone are rewritten with the next Save '
      'that changes something', () async {
    final shares = ItemSharesRepository();
    await shares.setSharing(
      SharedItemKind.site,
      's1',
      withAna,
      actingDiverId: 'me',
    );
    await db.customStatement(
      "UPDATE dive_sites SET is_shared = 1 WHERE id = 's1'",
    );
    expect(await shares.storedProfileIds(SharedItemKind.site, 's1'), {'ana'});

    final session = await loaded();
    expect(siteSharing.inSitting(session), const ItemSharing(everyone: true));
    expect(session.isDirty, isFalse);
    // A Save with no change writes nothing, the upkeep included.
    await save(session);
    expect(await shares.storedProfileIds(SharedItemKind.site, 's1'), {'ana'});

    session.set(siteNotesField, 'Choppy');
    await save(session);

    expect(await shares.storedProfileIds(SharedItemKind.site, 's1'), isEmpty);
    expect(
      await shares.sharingOf(SharedItemKind.site, 's1'),
      const ItemSharing(everyone: true),
    );
  });

  test('a refused share fails the Save with the sharing message', () async {
    final session = await loaded();
    // Another profile may not share the owner's site.
    siteSharing.set(session, withAna, actingDiverId: 'ana');
    session.set(siteNotesField, 'Choppy');

    final error = await SiteEditSaveService(SiteRepository())
        .save(
          siteId: 's1',
          apply: session.applyTo,
          changedCardIds: session.changedCardIds,
          alsoWrite: session.runHeldWrites,
          alsoWriteIsAChange: session.hasHeldChanges,
        )
        .then<Object?>((_) => null, onError: (Object e) => e);

    expect(error, isA<RecordSittingRefusal>());
    final l10n = AppLocalizationsEn();
    expect(
      (error! as RecordSittingRefusal).message(l10n),
      sharingRefusedMessage(l10n),
    );
    // Nothing written: the notes rolled back with it.
    expect((await SiteRepository().getSiteById('s1'))!.notes, '');
  });
}
