import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/database/database.dart' hide DiveSite;
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_catalogue_fill_repository.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_edit_fields.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/site_edit_save_service.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_catalogue_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_gap_comparison_sheet.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/site_types/presentation/providers/site_type_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

const _record = CatalogueSite(
  id: 'r1',
  name: 'SS Thistlegorm',
  location: GeoPoint(27.8138, 33.92),
  minDepth: 16,
  maxDepth: 32,
  typeIds: ['wreck'],
  source: 'ukho',
);

/// The catalogue offer's Review, held on the header block: chosen fields
/// become changes of their cards, and the link and the answers are written
/// with the sitting (issue #4527, phase 2).
void main() {
  late AppDatabase db;
  const site = DiveSite(id: 's1', diverId: 'me', name: 'Thistlegorm');
  const pair = CataloguePair(
    site: site,
    record: _record,
    kind: CataloguePairKind.sure,
    fields: {
      CatalogueGapField.position,
      CatalogueGapField.depth,
      CatalogueGapField.siteTypes,
    },
  );
  final at = DateTime.utc(2026);
  final wreck = SiteTypeEntity(
    id: 'wreck',
    name: 'Wreck',
    isBuiltIn: true,
    createdAt: at,
    updatedAt: at,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    await insertDiver(db, 'me');
    await SiteRepository().createSite(site);
    await ChangeLogRepository().settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  Future<EditSession<DiveSite>> loaded() async {
    final session = EditSession<DiveSite>(site);
    addTearDown(session.dispose);
    await siteTypesList.load(session);
    return session;
  }

  Future<void> save(EditSession<DiveSite> session) =>
      SiteEditSaveService(SiteRepository()).save(
        siteId: 's1',
        apply: session.applyTo,
        changedCardIds: session.changedCardIds,
        writeFirst: session.hasHeldWritesBeforeRecord
            ? () => session.runHeldWrites(beforeRecord: true)
            : null,
        alsoWrite: session.runHeldWrites,
        alsoWriteIsAChange: session.hasHeldChanges,
      );

  test('applying fills the chosen fields on their cards', () async {
    final session = await loaded();

    holdCatalogueReview(
      session,
      pair,
      const ComparisonApply({
        CatalogueGapField.position,
        CatalogueGapField.depth,
        CatalogueGapField.siteTypes,
      }),
      allTypes: [wreck],
      actingDiverId: 'me',
    );

    expect(session.valueOf(siteLocationField), _record.location);
    expect(session.valueOf(siteMinDepthField), 16);
    expect(session.valueOf(siteMaxDepthField), 32);
    expect(siteTypesList.current(session)!.map((t) => t.id), ['wreck']);
    expect(
      session.changedCardIds,
      containsAll(['location', 'depth', 'header']),
    );
    final stored = (await SiteRepository().getSiteById('s1'))!;
    expect(stored.catalogueId, isNull);
    expect(stored.location, isNull);
  });

  test(
    'Save links the record and fills the fields in one History entry',
    () async {
      final session = await loaded();
      holdCatalogueReview(
        session,
        pair,
        const ComparisonApply({
          CatalogueGapField.depth,
          CatalogueGapField.siteTypes,
        }),
        allTypes: [wreck],
        actingDiverId: 'me',
      );

      await save(session);

      final stored = (await SiteRepository().getSiteById('s1'))!;
      expect(stored.catalogueId, 'r1');
      expect(stored.maxDepth, 32);
      // Turned down: the position the diver left unticked.
      expect(stored.catalogueAnswers.declined['r1'], contains('position'));
      final types = await SiteClassificationRepository().getTypesForSite('s1');
      expect(types.map((t) => t.id), ['wreck']);
      await ChangeLogRepository().settleAll();
      final ops = await db
          .customSelect('SELECT label FROM change_log_operations')
          .get();
      expect(ops, hasLength(1));
    },
  );

  test('a record claimed by another site meanwhile fails the Save with the '
      'catalogue message', () async {
    final session = await loaded();
    holdCatalogueReview(
      session,
      pair,
      const ComparisonApply({CatalogueGapField.depth}),
      allTypes: [wreck],
      actingDiverId: 'me',
    );
    await SiteRepository().createSite(
      const DiveSite(id: 's2', diverId: 'me', name: 'Other'),
    );
    await db.customStatement(
      "UPDATE dive_sites SET catalogue_id = 'r1' WHERE id = 's2'",
    );

    final error = await save(
      session,
    ).then<Object?>((_) => null, onError: (Object e) => e);

    expect(error, isA<RecordSittingRefusal>());
    final l10n = AppLocalizationsEn();
    expect(
      (error! as RecordSittingRefusal).message(l10n),
      l10n.diveSites_edit_catalogueRefused,
    );
    final stored = (await SiteRepository().getSiteById('s1'))!;
    expect(stored.catalogueId, isNull);
    expect(stored.maxDepth, isNull);
  });

  test('not the same writes only the answer at Save', () async {
    final session = await loaded();
    holdCatalogueReview(
      session,
      pair,
      const ComparisonNotSame(),
      allTypes: [wreck],
      actingDiverId: 'me',
    );
    expect(session.changedCardIds, {siteHeaderCardId});
    expect(
      (await SiteRepository().getSiteById('s1'))!.catalogueAnswers.notSame,
      isEmpty,
    );

    await save(session);

    final stored = (await SiteRepository().getSiteById('s1'))!;
    expect(stored.catalogueAnswers.notSame, {'r1'});
    expect(stored.catalogueId, isNull);
  });

  // The profile lost the right to edit the site after the Review: the
  // answer is refused, and Save is all or nothing.
  for (final answer in const <CatalogueComparisonResult>[
    ComparisonNotSame(),
    ComparisonNoThanks(),
  ]) {
    test(
      'a refused ${answer.runtimeType} answer fails the whole Save',
      () async {
        final session = await loaded();
        session.set(siteNotesField, 'Choppy');
        holdCatalogueReview(
          session,
          pair,
          answer,
          allTypes: [wreck],
          actingDiverId: 'me',
          repository: SiteCatalogueFillRepository(stamper: _MayNotEdit()),
        );

        final error = await save(
          session,
        ).then<Object?>((_) => null, onError: (Object e) => e);

        expect(error, isA<RecordSittingRefusal>());
        final stored = (await SiteRepository().getSiteById('s1'))!;
        expect(stored.notes, isNot('Choppy'));
        expect(stored.catalogueAnswers.notSame, isEmpty);
      },
    );
  }

  test('no thanks writes only the declines at Save', () async {
    final session = await loaded();
    holdCatalogueReview(
      session,
      pair,
      const ComparisonNoThanks(),
      allTypes: [wreck],
      actingDiverId: 'me',
    );

    await save(session);

    final stored = (await SiteRepository().getSiteById('s1'))!;
    expect(stored.catalogueAnswers.declined['r1'], {
      'position',
      'depth',
      'siteTypes',
    });
  });

  test('site types chosen before the types are read are neither filled nor '
      'declined', () async {
    // The types list never read: nothing to add the record's types to.
    final session = EditSession<DiveSite>(site);
    addTearDown(session.dispose);
    holdCatalogueReview(
      session,
      pair,
      const ComparisonApply({
        CatalogueGapField.depth,
        CatalogueGapField.siteTypes,
      }),
      allTypes: [wreck],
      actingDiverId: 'me',
    );

    await save(session);

    final stored = (await SiteRepository().getSiteById('s1'))!;
    expect(stored.catalogueId, 'r1');
    // Offered again later, not turned down.
    expect(stored.catalogueAnswers.declined['r1'], {'position'});
  });

  group('from the page', () {
    ProviderContainer container0({Object? typesFail, Future<void>? typesGate}) {
      final container = ProviderContainer(
        overrides: [
          siteTypesProvider.overrideWith((_) async {
            await typesGate;
            if (typesFail != null) throw typesFail;
            return [wreck];
          }),
          validatedCurrentDiverIdProvider.overrideWith((_) async => 'me'),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('reads the types, the diver and the list, then holds', () async {
      final session = EditSession<DiveSite>(site);
      addTearDown(session.dispose);

      final held = await holdCatalogueReviewFrom(
        container0(),
        session,
        pair,
        const ComparisonApply({CatalogueGapField.siteTypes}),
      );

      expect(held, isTrue);
      expect(siteTypesList.current(session)!.map((t) => t.id), ['wreck']);
      expect(siteCatalogueReviewed(session), isTrue);
    });

    // Save waits for work the sitting tracks: a Review accepted just before
    // Save is written with it, not left out while its lookups answer.
    test('Save waits for the hold while its lookups answer', () async {
      final session = EditSession<DiveSite>(site);
      addTearDown(session.dispose);
      final gate = Completer<void>();

      final holding = holdCatalogueReviewFrom(
        container0(typesGate: gate.future),
        session,
        pair,
        const ComparisonApply({CatalogueGapField.depth}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(session.isSettled, isFalse);

      gate.complete();
      await session.settled();
      expect(siteCatalogueReviewed(session), isTrue);
      expect(await holding, isTrue);
    });

    // A Save tapped before the lookups answer must see the Review as the
    // change it is, or a sitting with nothing else changed would lock with
    // nothing saved.
    test('the Review is a change at once, before its lookups answer', () async {
      final session = EditSession<DiveSite>(site);
      addTearDown(session.dispose);
      final gate = Completer<void>();

      final holding = holdCatalogueReviewFrom(
        container0(typesGate: gate.future),
        session,
        pair,
        const ComparisonApply({CatalogueGapField.depth}),
      );

      expect(session.isDirty, isTrue);
      expect(siteCatalogueReviewed(session), isTrue);
      gate.complete();
      expect(await holding, isTrue);
      expect(session.isDirty, isTrue);
    });

    test('a lookup that fails takes back the Review it held at once', () async {
      final session = EditSession<DiveSite>(site);
      addTearDown(session.dispose);
      final gate = Completer<void>();

      final holding = holdCatalogueReviewFrom(
        container0(typesGate: gate.future, typesFail: StateError('offline')),
        session,
        pair,
        const ComparisonApply({CatalogueGapField.depth}),
      );
      gate.complete();

      expect(await holding, isFalse);
      expect(session.isDirty, isFalse);
      expect(siteCatalogueReviewed(session), isFalse);
    });

    // A Save that stopped waiting writes what it had: a Review landing on
    // the frozen sitting is not written, and must not read as held.
    test('a Review landing after Save froze the sitting is not held', () async {
      final session = EditSession<DiveSite>(site);
      addTearDown(session.dispose);
      final gate = Completer<void>();

      final holding = holdCatalogueReviewFrom(
        container0(typesGate: gate.future),
        session,
        pair,
        const ComparisonApply({CatalogueGapField.depth}),
      );
      session.freeze();
      gate.complete();

      expect(await holding, isFalse);
    });

    test('a lookup that fails holds nothing and says so', () async {
      final session = EditSession<DiveSite>(site);
      addTearDown(session.dispose);

      final held = await holdCatalogueReviewFrom(
        container0(typesFail: StateError('offline')),
        session,
        pair,
        const ComparisonApply({CatalogueGapField.depth}),
      );

      expect(held, isFalse);
      expect(session.isDirty, isFalse);
      expect(siteCatalogueReviewed(session), isFalse);
    });
  });
}

/// A stamper that says this profile may not edit the site.
class _MayNotEdit extends LibraryEditStamper {
  @override
  Future<bool> mayEdit(String siteId, {String? actingDiverId}) async => false;
}
