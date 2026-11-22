import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_sightings_section.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_where_seen_section.dart';
import 'package:submersion/features/media/presentation/widgets/species_photos_section.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import 'species_detail_page_unlock_harness.dart';

/// A new species opens on the species page, already unlocked (issue
/// #4527, phase 3, plan 11).
void main() {
  final l = AppLocalizationsEn();

  Finder nameField() =>
      find.byKey(const ValueKey('species_header_common_name'));

  Future<void> typeName(WidgetTester tester, String name) async {
    await tester.enterText(nameField(), name);
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  Future<void> tapCancel(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();
  }

  testWidgets('a new species opens unlocked with its header open', (
    tester,
  ) async {
    await pumpNewSpeciesPage(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text(l.marineLife_speciesEdit_addTitle), findsOneWidget);
    expect(nameField(), findsOneWidget);
    expect(find.byKey(const ValueKey('species_detail_menu')), findsNothing);
  });

  testWidgets('what a new species cannot have yet is not shown', (
    tester,
  ) async {
    await pumpNewSpeciesPage(tester);

    expect(find.byType(SpeciesPhotosSection), findsNothing);
    expect(find.byType(SpeciesSightingsSection), findsNothing);
    expect(find.byType(SpeciesWhereSeenSection), findsNothing);
  });

  testWidgets('Save waits for the first entry, and the name is required', (
    tester,
  ) async {
    final harness = await pumpNewSpeciesPage(tester);

    await tapSave(tester);
    expect(harness.save.creates, isEmpty);

    await typeName(tester, 'Frogfish');
    await tapSave(tester);
    final created = harness.save.creates.single;
    expect(created.species.commonName, 'Frogfish');
    expect(created.species.category, SpeciesCategory.fish);
    expect(created.cards, contains('header'));
    expect(harness.popped, created.species.id);
  });

  testWidgets('an untouched new species leaves without asking', (tester) async {
    final harness = await pumpNewSpeciesPage(tester);

    await tapCancel(tester);

    expect(find.text(l.forms_discard_title), findsNothing);
    expect(harness.poppedAtAll, isTrue);
    expect(harness.popped, isNull);
  });

  testWidgets('an entry asks before leaving, and nothing is written', (
    tester,
  ) async {
    final harness = await pumpNewSpeciesPage(tester);
    await typeName(tester, 'Frogfish');

    await tapCancel(tester);
    expect(find.text(l.forms_discard_title), findsOneWidget);
    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();

    expect(harness.poppedAtAll, isTrue);
    expect(harness.save.creates, isEmpty);
    expect(harness.save.calls, isEmpty);
  });

  testWidgets('a Save that fails keeps everything', (tester) async {
    final harness = await pumpNewSpeciesPage(tester);
    await typeName(tester, 'Frogfish');
    harness.save.fail = true;

    await tapSave(tester);
    expect(find.text(l.recordEdit_saveFailed), findsOneWidget);
    expect(find.byType(RecordEditBar), findsOneWidget);

    harness.save.fail = false;
    await tapSave(tester);
    expect(harness.save.creates, hasLength(2));
    expect(
      harness.save.creates.last.species.id,
      harness.save.creates.first.species.id,
    );
  });

  testWidgets('a lookup fills the header as changes', (tester) async {
    final harness = await pumpNewSpeciesPage(
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

    await tester.tap(find.byKey(const ValueKey('species_lookup_online')));
    await tester.pumpAndSettle();
    await tapSave(tester);

    final created = harness.save.creates.single.species;
    expect(created.commonName, 'Reef manta');
    expect(created.scientificName, 'Mobula alfredi');
    expect(created.category, SpeciesCategory.ray);
    expect(created.taxonomyClass, 'Elasmobranchii');
  });
}
