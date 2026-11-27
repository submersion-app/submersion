import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_edit_cards.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_header_card_editor.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_reader_sitting.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_gap_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sharing_sitting.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/shared/widgets/shared_items/item_sharing_field.dart';

import '../../../../helpers/shared_items_fixture.dart';

import 'site_editor_harness.dart';

/// Share rows that answer only once [gate] completes, or never with
/// [fails].
class _SlowShares extends FakeItemShares {
  _SlowShares({this.fails = false}) : super({'s1': ItemSharing.all});

  final bool fails;
  final gate = Completer<void>();

  @override
  Future<ItemSharing> sharingOf(SharedItemKind kind, String id) async {
    if (fails) throw StateError('unreadable');
    await gate.future;
    return super.sharingOf(kind, id);
  }
}

/// The site's header block edited in place: its name and its water (issue
/// #4527, phase 2, plan 2).
void main() {
  final l = AppLocalizationsEn();
  const site = DiveSite(id: 's1', name: 'Blue Hole', waterType: WaterType.salt);

  Future<SiteEditorHarness> pump(WidgetTester tester, [DiveSite s = site]) =>
      pumpSiteEditor(
        tester,
        s,
        (session) => SiteHeaderCardEditor(session: session),
      );

  testWidgets('typing the name writes it', (tester) async {
    final h = await pump(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Great Blue Hole');
    await tester.pump();

    expect(h.session.valueOf(siteNameField), 'Great Blue Hole');
    expect(h.session.changedCardIds, {siteHeaderCardId});
  });

  testWidgets('a blank name refuses Save and shows the message', (
    tester,
  ) async {
    final h = await pump(tester);

    await tester.enterText(find.byType(TextFormField).first, '  ');
    await tester.pumpAndSettle();

    expect(siteHeaderCard.isValid!(h.session), isFalse);
    expect(
      find.text(l.diveSites_edit_field_siteName_validation),
      findsOneWidget,
    );
  });

  testWidgets('a stored blank name does not block saving another card', (
    tester,
  ) async {
    final h = await pump(tester, site.copyWith(name: ''));

    expect(siteHeaderCard.isValid!(h.session), isTrue);
  });

  testWidgets('tapping the selected water type clears it', (tester) async {
    final h = await pump(tester);

    await tester.tap(find.text(WaterType.salt.localizedName(l)));
    await tester.pump();
    expect(h.session.valueOf(siteWaterTypeField), isNull);

    await tester.tap(find.text(WaterType.fresh.localizedName(l)));
    await tester.pump();
    expect(h.session.valueOf(siteWaterTypeField), WaterType.fresh);
  });

  group('sharing', () {
    final at = DateTime.utc(2026);
    final me = Diver(id: 'me', name: 'Me', createdAt: at, updatedAt: at);
    final ana = Diver(id: 'ana', name: 'Ana', createdAt: at, updatedAt: at);
    const owned = DiveSite(id: 's1', diverId: 'me', name: 'Blue Hole');

    Future<SiteEditorHarness> pumpWith(
      WidgetTester tester,
      DiveSite s,
      List<Diver> divers, {
      Future<String?> Function()? active,
      ItemSharesRepository? shares,
    }) => pumpSiteEditor(
      tester,
      s,
      (session) => SiteHeaderCardEditor(session: session),
      overrides: [
        allDiversProvider.overrideWith((_) async => divers),
        validatedCurrentDiverIdProvider.overrideWith(
          (_) => active?.call() ?? Future.value('me'),
        ),
        if (shares != null)
          itemSharesRepositoryProvider.overrideWithValue(shares),
      ],
    );

    SharingTile tile(WidgetTester tester) =>
        tester.widget<SharingTile>(find.byType(SharingTile));

    testWidgets('offered with two or more divers', (tester) async {
      await pumpWith(tester, owned, [me, ana]);
      expect(find.text(l.sharedItems_sharedWith_label), findsOneWidget);
    });

    testWidgets('not offered with one diver', (tester) async {
      await pumpWith(tester, owned, [me]);
      expect(find.text(l.sharedItems_sharedWith_label), findsNothing);
    });

    // The form's sharing cases, on the header block (plan 7).
    testWidgets('the owner can change sharing', (tester) async {
      await pumpWith(tester, owned, [me, ana], shares: FakeItemShares());
      await tester.pumpAndSettle();

      expect(tile(tester).onTap, isNotNull);
    });

    testWidgets('another profile cannot change sharing', (tester) async {
      await pumpWith(
        tester,
        owned,
        [me, ana],
        active: () => Future.value('ana'),
        shares: FakeItemShares(),
      );
      await tester.pumpAndSettle();

      expect(tile(tester).onTap, isNull);
      expect(find.text(l.sharedItems_shareOwnerOnly('Me')), findsOneWidget);
    });

    testWidgets('an unreadable profile locks sharing', (tester) async {
      await pumpWith(
        tester,
        owned,
        [me, ana],
        active: () => Future.error(StateError('no profile')),
        shares: FakeItemShares(),
      );
      await tester.pumpAndSettle();

      expect(tile(tester).onTap, isNull);
      expect(find.textContaining('can change sharing'), findsNothing);
    });

    testWidgets('waits for the share rows, and locks when they cannot be '
        'read', (tester) async {
      final slow = _SlowShares();
      await pumpWith(tester, owned, [me, ana], shares: slow);
      await tester.pump();
      expect(find.text(l.sharedItems_sharedWith_label), findsNothing);

      slow.gate.complete();
      await tester.pumpAndSettle();
      expect(tile(tester).onTap, isNotNull);

      await pumpWith(tester, owned, [
        me,
        ana,
      ], shares: _SlowShares(fails: true));
      await tester.pumpAndSettle();
      expect(tile(tester).onTap, isNull);
    });

    testWidgets('taking a profile off asks first', (tester) async {
      final h = await pumpWith(tester, owned, [
        me,
        ana,
      ], shares: FakeItemShares({'s1': ItemSharing.all}));
      await tester.pumpAndSettle();

      Future<void> untickEveryone() async {
        await tester.tap(find.text(l.sharedItems_sharedWith_label));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Everyone'),
          ),
        );
        await tester.pump();
        await tester.tap(find.text(l.forms_save));
        await tester.pumpAndSettle();
      }

      await untickEveryone();
      expect(find.text(l.sites_unshareConfirm_title), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel'),
        ),
      );
      await tester.pumpAndSettle();
      expect(h.session.isDirty, isFalse);

      await untickEveryone();
      await tester.tap(find.text(l.common_action_unshare));
      await tester.pumpAndSettle();
      expect(siteSharing.inSitting(h.session)!.isShared, isFalse);
      expect(h.session.changedCardIds, {siteHeaderCardId});
    });

    testWidgets('not offered for a library site', (tester) async {
      await pumpWith(tester, owned.copyWith(sharedLibraryId: 'lib-1'), [
        me,
        ana,
      ]);
      expect(find.text(l.sharedItems_sharedWith_label), findsNothing);
    });
  });

  // In a library reader's sitting a fill would write the library's site,
  // which a reader cannot: the catalogue offer reads only (plan 5).
  group('the catalogue offer', () {
    const pair = CataloguePair(
      site: site,
      record: CatalogueSite(id: 'r1', name: 'Blue Hole', source: 'osm'),
      kind: CataloguePairKind.linked,
      fields: {CatalogueGapField.depth},
    );
    final offer = [
      catalogueGapPairForSiteProvider('s1').overrideWith((ref) => pair),
    ];

    testWidgets('an editor can review it', (tester) async {
      await pumpSiteEditor(
        tester,
        site,
        (session) => SiteHeaderCardEditor(session: session),
        overrides: offer,
      );

      expect(find.text(l.diveSites_gapNotice_review), findsOneWidget);
    });

    testWidgets('a reader\'s sitting reads it only', (tester) async {
      await pumpSiteEditor(
        tester,
        site,
        (session) => SiteHeaderCardEditor(session: session),
        overrides: offer,
        onStart: markReaderSitting,
      );

      expect(find.text(l.diveSites_gapNotice_review), findsNothing);
    });
  });
}
