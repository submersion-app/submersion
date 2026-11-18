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
    await loadSiteSharing(session, container.read);
    return session;
  }

  const withAna = ItemSharing(profileIds: {'ana'});

  // A library site follows its library: it shows no sharing and writes
  // none, so a sitting on it reads none.
  test('a library site reads no sharing', () async {
    final session = EditSession<DiveSite>(site.copyWith(sharedLibraryId: 'L'));
    addTearDown(session.dispose);

    await loadSiteSharing(session, container.read);

    expect(siteSharingLoaded(session), isNull);
    expect(siteSharingUnread(session), isFalse);
  });

  test(
    'choosing other profiles holds the change and dots the header',
    () async {
      final session = await loaded();
      expect(siteSharingInSitting(session), ItemSharing.none);

      setSiteSharing(session, withAna, actingDiverId: 'me');

      expect(siteSharingInSitting(session), withAna);
      expect(session.changedCardIds, {siteHeaderCardId});
      expect(
        await ItemSharesRepository().sharingOf(SharedItemKind.site, 's1'),
        ItemSharing.none,
      );
    },
  );

  test('choosing the loaded value releases it', () async {
    final session = await loaded();
    setSiteSharing(session, withAna, actingDiverId: 'me');

    setSiteSharing(session, ItemSharing.none, actingDiverId: 'me');

    expect(session.isDirty, isFalse);
  });

  test('Save writes the sharing with the site', () async {
    final session = await loaded();
    setSiteSharing(session, withAna, actingDiverId: 'me');

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

  test('a refused share fails the Save with the sharing message', () async {
    final session = await loaded();
    // Another profile may not share the owner's site.
    setSiteSharing(session, withAna, actingDiverId: 'ana');
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
