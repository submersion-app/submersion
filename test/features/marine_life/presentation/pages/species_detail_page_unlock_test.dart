import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import 'species_detail_page_unlock_harness.dart';

/// The species page edits in place behind the phase 3 switch (issue
/// #4527): it opens locked, a sitting edits its names and description, and
/// one Save writes it.
void main() {
  final l = AppLocalizationsEn();

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  Future<void> openCard(WidgetTester tester, String title) async {
    await tester.tap(find.byTooltip(l.recordEdit_editCardTooltip(title)));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  String headerTitle() => l.settings_conflict_ref_species;
  String descriptionTitle() => l.marineLife_speciesDetail_descriptionTitle;

  // The lock is the one way in (issue #4527, plan 12): no Edit pencil.
  testWidgets('the locked bar has the lock and no Edit pencil', (tester) async {
    await pumpSpeciesPage(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.edit), findsNothing);
    expect(find.widgetWithIcon(IconButton, Icons.edit_outlined), findsNothing);
  });

  testWidgets('locked, no tap writes', (tester) async {
    final harness = await pumpSpeciesPage(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byType(RecordPencilIcon), findsNothing);
    await tester.tap(find.text('Manta'));
    await tester.tap(find.text('Big'));
    await tester.pumpAndSettle();

    expect(harness.save.calls, isEmpty);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('unlocking marks the header and the description, and fades the '
      'calculated cards', (tester) async {
    await pumpSpeciesPage(tester);
    await unlock(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text(l.recordEdit_editingTitle('Manta')), findsOneWidget);
    expect(
      find.byTooltip(l.recordEdit_editCardTooltip(headerTitle())),
      findsOneWidget,
    );
    expect(
      find.byTooltip(l.recordEdit_editCardTooltip(descriptionTitle())),
      findsOneWidget,
    );
    expect(find.text(l.recordEdit_calculated), findsWidgets);
    expect(find.byType(RecordCardFade<Species>), findsWidgets);
  });

  testWidgets('editing the description and saving writes one sitting', (
    tester,
  ) async {
    final harness = await pumpSpeciesPage(tester);
    await unlock(tester);
    await openCard(tester, descriptionTitle());
    await tester.enterText(find.byType(TextField).last, 'Huge');
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls, hasLength(1));
    expect(harness.save.calls.single.cards, {'description'});
    expect(harness.save.calls.single.after.description, 'Huge');
    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.text('Huge'), findsOneWidget);
  });

  testWidgets('a blank common name stops Save and says why', (tester) async {
    final harness = await pumpSpeciesPage(tester);
    await unlock(tester);
    await openCard(tester, headerTitle());
    await tester.enterText(
      find.byKey(const ValueKey('species_header_common_name')),
      '',
    );
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls, isEmpty);
    expect(find.text(l.recordEdit_fixInvalid), findsOneWidget);
    expect(find.text(l.marineLife_speciesEdit_commonNameError), findsOneWidget);
  });

  testWidgets(
    'the lookup fills the names, taxonomy and category as changes of the '
    'header',
    (tester) async {
      final harness = await pumpSpeciesPage(
        tester,
        lookupAnswer: const SpeciesLookupChosen(
          SpeciesLookupResult(
            taxonId: 1,
            commonName: 'Reef manta',
            scientificName: 'Mobula alfredi',
            category: SpeciesCategory.ray,
            taxonomyClass: 'Elasmobranchii',
          ),
        ),
      );
      await unlock(tester);
      await openCard(tester, headerTitle());

      await tester.tap(find.byKey(const ValueKey('species_lookup_online')));
      await tester.pumpAndSettle();
      await save(tester);

      final call = harness.save.calls.single;
      expect(call.cards, {'header'});
      expect(call.after.commonName, 'Reef manta');
      expect(call.after.scientificName, 'Mobula alfredi');
      expect(call.after.taxonomyClass, 'Elasmobranchii');
      expect(call.after.category, SpeciesCategory.ray);
    },
  );

  testWidgets('a built-in species edits its stored English name', (
    tester,
  ) async {
    final harness = await pumpSpeciesPage(
      tester,
      species: const Species(
        id: 'sp_whale_shark',
        commonName: 'Whale Shark',
        category: SpeciesCategory.shark,
        isBuiltIn: true,
      ),
      locale: const Locale('de'),
    );
    await unlock(tester);
    await tester.tap(find.byType(RecordPencilIcon).first);
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('species_header_common_name'));
    expect(tester.widget<TextField>(field).controller!.text, 'Whale Shark');

    await tester.enterText(field, 'Giant shark');
    await tester.pumpAndSettle();
    final de = lookupAppLocalizations(const Locale('de'));
    await tester.tap(find.text(de.forms_save));
    await tester.pumpAndSettle();

    expect(harness.save.calls.single.after.commonName, 'Giant shark');
    expect(find.text('Giant shark'), findsOneWidget);
  });

  testWidgets('an empty description is offered in the strip', (tester) async {
    await pumpSpeciesPage(
      tester,
      species: manta.copyWith(id: 'manta').withoutDescription,
    );
    await unlock(tester);

    expect(
      find.descendant(
        of: find.byType(AddStrip),
        matching: find.text(descriptionTitle()),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a rename underneath keeps the description being edited', (
    tester,
  ) async {
    final harness = await pumpSpeciesPage(tester);
    await unlock(tester);
    await openCard(tester, descriptionTitle());
    await tester.enterText(find.byType(TextField).last, 'Huge');
    await tester.pumpAndSettle();

    harness.stored.state = harness.stored.state!.copyWith(
      commonName: 'Oceanic manta',
    );
    await tester.pumpAndSettle();
    await save(tester);

    final after = harness.save.calls.single.after;
    expect(after.commonName, 'Oceanic manta');
    expect(after.description, 'Huge');
  });

  testWidgets('Cancel with changes asks first', (tester) async {
    await pumpSpeciesPage(tester);
    await unlock(tester);
    await openCard(tester, descriptionTitle());
    await tester.enterText(find.byType(TextField).last, 'Huge');
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });
  group('photos tagged in a sitting', () {
    Future<void> tagOne(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('species_tag_photos')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MediaThumbnailTile).first);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('tag_picker_confirm')));
      await tester.pumpAndSettle();
    }

    testWidgets('Tag photos while locked is not offered', (tester) async {
      await pumpSpeciesPage(tester);

      expect(find.byKey(const ValueKey('species_tag_photos')), findsNothing);
    });

    testWidgets('tagged in a sitting, Save tags them once', (tester) async {
      final harness = await pumpSpeciesPage(tester);
      await unlock(tester);
      await tagOne(tester);

      expect(harness.tagging.tagged, isEmpty);
      expect(
        find.byKey(const ValueKey('species_pending_remove_p1')),
        findsOneWidget,
      );
      await save(tester);

      expect(harness.save.calls.single.cards, {'photos'});
      expect(harness.tagging.tagged, ['p1']);
    });

    testWidgets('the remove button lets a held photo go', (tester) async {
      final harness = await pumpSpeciesPage(tester);
      await unlock(tester);
      await tagOne(tester);

      await tester.tap(find.byKey(const ValueKey('species_pending_remove_p1')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('species_pending_remove_p1')),
        findsNothing,
      );
      expect(harness.tagging.tagged, isEmpty);
    });

    testWidgets('Cancel tags nothing', (tester) async {
      final harness = await pumpSpeciesPage(tester);
      await unlock(tester);
      await tagOne(tester);

      await tester.tap(find.text(l.forms_cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.forms_discard_discard).last);
      await tester.pumpAndSettle();

      expect(harness.save.calls, isEmpty);
      expect(harness.tagging.tagged, isEmpty);
      expect(
        find.byKey(const ValueKey('species_pending_remove_p1')),
        findsNothing,
      );
    });
  });
  group('photos added in a sitting', () {
    Future<void> addOne(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('species_add_photos')));
      await tester.pumpAndSettle();
    }

    testWidgets('Add photos while locked is not offered', (tester) async {
      await pumpSpeciesPage(tester);

      expect(find.byKey(const ValueKey('species_add_photos')), findsNothing);
    });

    testWidgets('added in a sitting, Save imports and tags them once', (
      tester,
    ) async {
      final harness = await pumpSpeciesPage(tester);
      await unlock(tester);
      await addOne(tester);

      expect(harness.written, isEmpty);
      expect(
        find.byKey(const ValueKey('species_pending_remove_new1')),
        findsOneWidget,
      );
      await save(tester);

      expect(harness.save.calls.single.cards, {'photos'});
      expect(harness.written, ['new1']);
      expect(harness.tagging.tagged, ['new1']);
    });

    testWidgets('Cancel imports nothing and tags nothing', (tester) async {
      final harness = await pumpSpeciesPage(tester);
      await unlock(tester);
      await addOne(tester);

      await tester.tap(find.text(l.forms_cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.forms_discard_discard).last);
      await tester.pumpAndSettle();

      expect(harness.written, isEmpty);
      expect(harness.tagging.tagged, isEmpty);
    });
  });
  group('addresses and operations', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('species_detail_menu')));
      await tester.pumpAndSettle();
    }

    Finder deleteItem() => find.text(l.marineLife_speciesManage_deleteButton);

    testWidgets('opened with mode=edit, the page is unlocked', (tester) async {
      await pumpSpeciesPage(tester, openUnlocked: true);

      expect(find.byType(RecordEditBar), findsOneWidget);
    });

    testWidgets('locked, Delete is disabled under "Unlock to use these"', (
      tester,
    ) async {
      final harness = await pumpSpeciesPage(tester);
      await openMenu(tester);

      expect(find.text(l.recordEdit_unlockToUseThese), findsOneWidget);
      await tester.tap(deleteItem());
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(harness.species.deleted, isEmpty);
    });

    testWidgets('unlocked with nothing to save, Delete asks and deletes', (
      tester,
    ) async {
      final harness = await pumpSpeciesPage(tester);
      await unlock(tester);
      await openMenu(tester);

      await tester.tap(deleteItem());
      await tester.pumpAndSettle();
      expect(
        find.text(l.marineLife_species_delete_confirmTitle),
        findsOneWidget,
      );
      await tester.tap(deleteItem().last);
      await tester.pumpAndSettle();

      expect(harness.species.deleted, ['manta']);
    });

    testWidgets('a species in use is not deleted and says why', (tester) async {
      final harness = await pumpSpeciesPage(tester);
      harness.species.inUse = true;
      await unlock(tester);
      await openMenu(tester);

      await tester.tap(deleteItem());
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text(l.marineLife_species_delete_inUseError('Manta')),
        findsOneWidget,
      );
      expect(harness.species.deleted, isEmpty);
    });

    testWidgets('a built-in species offers no Delete', (tester) async {
      await pumpSpeciesPage(
        tester,
        species: const Species(
          id: 'sp_whale_shark',
          commonName: 'Whale Shark',
          category: SpeciesCategory.shark,
          isBuiltIn: true,
        ),
      );
      await unlock(tester);
      await openMenu(tester);

      expect(deleteItem(), findsNothing);
    });

    testWidgets('Suggest for catalog is offered while locked', (tester) async {
      await pumpSpeciesPage(tester);
      await openMenu(tester);

      final item = tester.widget<PopupMenuItem<String>>(
        find.ancestor(
          of: find.text(l.marineLife_speciesDetail_suggestForCatalog),
          matching: find.byType(PopupMenuItem<String>),
        ),
      );
      expect(item.enabled, isTrue);
    });
  });
  group('review fixes', () {
    testWidgets('photos added are queued for upload even if the page goes', (
      tester,
    ) async {
      final harness = await pumpSpeciesPage(tester);
      await unlock(tester);
      await tester.tap(find.byKey(const ValueKey('species_add_photos')));
      await tester.pumpAndSettle();
      final gate = harness.save.gate = Completer<void>();

      await tester.tap(find.text(l.forms_save));
      await tester.pump();
      // The diver leaves while the write runs; the app stays.
      harness.showPage.value = false;
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();

      expect(harness.written, ['new1']);
      expect(harness.enqueued, ['new1']);
    });

    testWidgets('a delete that fails says so', (tester) async {
      final harness = await pumpSpeciesPage(tester);
      harness.species.deleteFails = StateError('in use');
      await unlock(tester);
      await tester.tap(find.byKey(const ValueKey('species_detail_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.marineLife_speciesManage_deleteButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.marineLife_speciesManage_deleteButton).last);
      await tester.pumpAndSettle();

      expect(
        find.text(l.marineLife_species_delete_error('Bad state: in use')),
        findsOneWidget,
      );
    });

    testWidgets('a trailing space on the name is no change', (tester) async {
      await pumpSpeciesPage(tester);
      await unlock(tester);
      await openCard(tester, headerTitle());

      await tester.enterText(
        find.byKey(const ValueKey('species_header_common_name')),
        'Manta ',
      );
      await tester.pumpAndSettle();

      final saveButton = find.text(l.forms_save);
      expect(saveButton, findsOneWidget);
      expect(
        tester.widget<RecordEditBar>(find.byType(RecordEditBar)).canSave,
        isFalse,
      );
    });
  });
}

extension on Species {
  /// This species with no description, which `copyWith` cannot clear.
  Species get withoutDescription => Species(
    id: id,
    commonName: commonName,
    scientificName: scientificName,
    category: category,
    taxonomyClass: taxonomyClass,
  );
}
