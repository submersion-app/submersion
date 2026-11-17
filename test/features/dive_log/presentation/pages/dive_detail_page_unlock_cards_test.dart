import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_altitude_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_details_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_environment_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_environment_card_editor.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/features/weather/domain/entities/weather_data.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// The Altitude and Environment cards on the unlocked dive page: the
/// two cards working together, and with the page around them (issue
/// #4527).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  group('the Altitude and Environment cards', () {
    const cards = {
      DiveDetailSectionId.notes,
      DiveDetailSectionId.altitude,
      DiveDetailSectionId.environment,
    };
    // Tall enough that every row of an open card is on screen.
    const tall = Size(700, 2600);
    const reef = DiveSite(
      id: 'site-1',
      name: 'Reef',
      location: GeoPoint(-16.5, 145.8),
      waterType: WaterType.salt,
    );
    const addAltitude = ValueKey('addStrip_altitude');
    const addEnvironment = ValueKey('addStrip_environment');

    AppLocalizations l10nOf(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byType(DiveDetailPage)));

    RecordEditController<Dive> controller(WidgetTester tester) => tester
        .widget<RecordEditScope<Dive>>(find.byType(RecordEditScope<Dive>))
        .notifier!;

    /// The text field of the row labelled [label], once that row is open.
    Finder fieldOf(String label) => find.descendant(
      of: find.widgetWithText(FormRow, label),
      matching: find.byType(TextFormField),
    );

    /// Opens the row labelled [label] and types [text] into it.
    Future<void> typeIn(WidgetTester tester, String label, String text) async {
      await tester.tap(find.widgetWithText(FormRow, label));
      await tester.pump();
      await tester.enterText(fieldOf(label), text);
      await settle(tester);
    }

    List<Override> noSatellite() => [
      reefHealthForDiveProvider.overrideWith(
        (ref, request) async => const ReefPart<ReefHealth>.empty(),
      ),
      reefHabitatProvider.overrideWith(
        (ref, location) async => const ReefPart<ReefHabitat>.empty(),
      ),
    ];

    testWidgets('a sea-level dive with nothing logged is offered both', (
      tester,
    ) async {
      await pumpPage(tester, visible: cards, size: tall);
      await unlock(tester);

      expect(find.byKey(addAltitude), findsOneWidget);
      expect(find.byKey(addEnvironment), findsOneWidget);
      expect(find.byTooltip('Edit Environment'), findsNothing);
    });

    // The Environment card shows for satellite conditions alone, which only
    // a provider knows about. The strip must not offer a card that is there.
    testWidgets('a dive showing satellite conditions is not offered '
        'Environment', (tester) async {
      await pumpPage(
        tester,
        visible: cards,
        size: tall,
        stored: dive.copyWith(site: reef),
        extra: [
          reefHealthForDiveProvider.overrideWith(
            (ref, request) async => ReefPart.ok(
              ReefHealth(
                sst: 30.1,
                sstAnomaly: 0.8,
                degreeHeatingWeeks: 4.2,
                alertLevel: BleachingAlertLevel.watch,
                observedAt: DateTime.utc(2023, 1, 1, 12),
              ),
            ),
          ),
          reefHabitatProvider.overrideWith(
            (ref, location) async =>
                const ReefPart.ok(ReefHabitat(onReef: true)),
          ),
        ],
      );
      await unlock(tester);

      expect(find.byTooltip('Edit Environment'), findsOneWidget);
      expect(find.byKey(addEnvironment), findsNothing);
      expect(find.byKey(addAltitude), findsOneWidget);
    });

    testWidgets('unreadable input: Done and Save both refuse, and Save says '
        'why', (tester) async {
      final page = await pumpPage(tester, visible: cards, size: tall);
      await unlock(tester);
      await tapStripChip(tester, 'altitude');
      await settle(tester);
      final l10n = l10nOf(tester);
      final altitude = l10n.diveLog_edit_label_altitude;

      // A readable change first, so there is something to save.
      await typeIn(tester, l10n.diveLog_edit_label_surfacePressure, '900');
      await typeIn(tester, altitude, '1.2.3');

      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(find.byType(DiveAltitudeCardEditor), findsOneWidget);

      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(page.save.calls, isEmpty);
      expect(find.text(l10n.recordEdit_fixInvalid), findsOneWidget);
      expect(find.text(l10n.recordEdit_saveFailed), findsNothing);
      expect(find.byTooltip('Unlock to edit'), findsNothing);

      await tester.enterText(fieldOf(altitude), '120');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);

      final saved = page.save.calls.single;
      expect(saved.merged.altitude, 120);
      expect(saved.merged.surfacePressure, closeTo(0.9, 1e-9));
      expect(saved.cards, ['altitude']);
      expect(find.byTooltip('Unlock to edit'), findsOneWidget);
    });

    testWidgets('unreadable input is forgotten after Cancel', (tester) async {
      await pumpPage(tester, visible: cards, size: tall);
      await unlock(tester);
      await tapStripChip(tester, 'altitude');
      await settle(tester);
      await typeIn(tester, l10nOf(tester).diveLog_edit_label_altitude, '1.2.3');
      expect(controller(tester).invalidCardIds, {'altitude'});

      await tester.tap(find.text('Cancel'));
      await settle(tester);

      // Nothing readable was changed, so there is nothing to ask about.
      expect(find.text('Discard'), findsNothing);
      expect(find.byTooltip('Unlock to edit'), findsOneWidget);

      await unlock(tester);
      expect(controller(tester).invalidCardIds, isEmpty);
      expect(controller(tester).refusedForInvalidInput, isFalse);
      expect(action(tester, 'Save').onPressed, isNull);
    });

    // 4050 ft reads back as 1,234.44 m and 25.69 inHg as 0.86996 bar.
    testWidgets('opening and closing a card in imperial units leaves the '
        'sitting clean', (tester) async {
      final page = await pumpPage(
        tester,
        visible: cards,
        size: tall,
        imperial: true,
        stored: dive.copyWith(altitude: 1234.5, surfacePressure: 0.87),
      );
      await unlock(tester);
      await tester.tap(find.byTooltip('Edit Altitude Dive'));
      await settle(tester);

      // The Environment card shows the pressure as well: look in the editor.
      Finder inEditor(String text) => find.descendant(
        of: find.byType(DiveAltitudeCardEditor),
        matching: find.text(text),
      );
      await tester.tap(inEditor('4050 ft'));
      await settle(tester);
      await tester.tap(inEditor('25.69 inHg'));
      await settle(tester);
      await tester.tap(find.text('Done'));
      await settle(tester);

      expect(find.byType(DiveAltitudeCardEditor), findsNothing);
      expect(controller(tester).isDirty, isFalse);
      expect(action(tester, 'Save').onPressed, isNull);
      expect(page.save.calls, isEmpty);
    });

    testWidgets('emptying the altitude and saving stores no altitude', (
      tester,
    ) async {
      final page = await pumpPage(
        tester,
        visible: cards,
        size: tall,
        stored: dive.copyWith(altitude: 900),
      );
      await unlock(tester);
      await tester.tap(find.byTooltip('Edit Altitude Dive'));
      await settle(tester);

      await typeIn(tester, l10nOf(tester).diveLog_edit_label_altitude, '');
      await tester.tap(find.text('Save'));
      await settle(tester);

      final saved = page.save.calls.single;
      expect(saved.merged.altitude, isNull);
      expect(saved.cards, ['altitude']);
    });

    // Another editor still open keeps the page laid out as it was. A card
    // emptied and closed meanwhile draws nothing, so the strip has to offer
    // it, or there is no way back into it until the other editor closes.
    testWidgets('a card emptied and closed while another is open is offered '
        'again', (tester) async {
      await pumpPage(
        tester,
        visible: cards,
        size: tall,
        stored: dive.copyWith(altitude: 900),
      );
      await unlock(tester);
      await openNotes(tester);
      await tester.tap(find.byTooltip('Edit Altitude Dive'));
      await settle(tester);

      await typeIn(tester, l10nOf(tester).diveLog_edit_label_altitude, '');
      controller(tester).closeCard('altitude');
      await settle(tester);

      expect(controller(tester).openCardIds, {'notes'});
      expect(find.byType(DiveAltitudeSection), findsNothing);
      expect(find.byKey(addAltitude), findsOneWidget);
    });

    testWidgets('the entry method carries the exit method with it', (
      tester,
    ) async {
      final page = await pumpPage(
        tester,
        visible: cards,
        size: tall,
        stored: dive.copyWith(airTemp: 20),
      );
      await unlock(tester);
      await tester.tap(find.byTooltip('Edit Environment'));
      await settle(tester);
      expect(find.byType(DiveEnvironmentCardEditor), findsOneWidget);

      await tester.tap(
        find.text(l10nOf(tester).diveLog_edit_label_entryMethod),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shore').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await settle(tester);

      final saved = page.save.calls.single;
      expect(saved.merged.entryMethod, EntryMethod.shore);
      expect(saved.merged.exitMethod, EntryMethod.shore);
      expect(saved.cards, ['environment']);
    });

    // The fetch belongs to the Environment card and fills a value the
    // Altitude card owns. Both cards already carry a change here, so the
    // set of changed cards does not move: the page redraws the Altitude
    // card only because a card that is not open changed again.
    testWidgets('a fetched pressure shows on the closed Altitude card', (
      tester,
    ) async {
      final page = await pumpPage(
        tester,
        visible: cards,
        size: tall,
        stored: dive.copyWith(altitude: 900, site: reef),
        extra: [
          ...noSatellite(),
          weatherServiceProvider.overrideWithValue(
            FakeWeather(const WeatherData(humidity: 70, surfacePressure: 0.9)),
          ),
        ],
      );
      await unlock(tester);
      final l10n = l10nOf(tester);
      final altitudeCard = find.byType(DiveAltitudeSection);
      Finder onAltitudeCard(Finder what) =>
          find.descendant(of: altitudeCard, matching: what);

      // Change the altitude and close its card.
      await tester.tap(find.byTooltip('Edit Altitude Dive'));
      await settle(tester);
      await typeIn(tester, l10n.diveLog_edit_label_altitude, '950');
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(onAltitudeCard(find.byType(RecordChangedDot)), findsOneWidget);
      expect(onAltitudeCard(find.text('900 mbar')), findsNothing);

      // Change the Environment card too, then fetch.
      await tapStripChip(tester, 'environment');
      await settle(tester);
      await typeIn(tester, l10n.diveLog_edit_label_humidity, '50');
      expect(controller(tester).session!.changedCardIds, {
        'altitude',
        'environment',
      });
      await tester.tap(find.text('Fetch Weather'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.common_action_ok));
      await tester.pumpAndSettle();

      expect(onAltitudeCard(find.text('900 mbar')), findsOneWidget);

      await tester.tap(find.text('Save'));
      await settle(tester);
      final saved = page.save.calls.single;
      expect(saved.merged.altitude, 950);
      expect(saved.merged.surfacePressure, 0.9);
      expect(saved.merged.humidity, 70);
      expect(saved.cards, unorderedEquals(['altitude', 'environment']));
    });

    // Surface pressure is edited on the Altitude card and shown on the
    // Environment card as well, where it also counts as something to show.
    group('a value one card owns and another shows', () {
      // One column, with Environment above Altitude in the page's order.

      testWidgets('typing it does not bring the other card in above the '
          'editor', (tester) async {
        await pumpPage(
          tester,
          visible: cards,
          size: tall,
          stored: dive.copyWith(altitude: 1200),
        );
        await unlock(tester);
        await tester.tap(find.byTooltip('Edit Altitude Dive'));
        await settle(tester);
        final editor = find.byType(DiveAltitudeCardEditor);
        final top = tester.getTopLeft(editor).dy;
        expect(find.byType(DiveEnvironmentSection), findsNothing);

        await typeIn(
          tester,
          l10nOf(tester).diveLog_edit_label_surfacePressure,
          '9',
        );

        expect(find.byType(DiveEnvironmentSection), findsNothing);
        expect(tester.getTopLeft(editor).dy, top);
        expect(find.byKey(addEnvironment), findsOneWidget);

        // Cards come and go once the editor is closed.
        await tester.tap(find.text('Done'));
        await settle(tester);

        expect(find.byType(DiveEnvironmentSection), findsOneWidget);
        expect(find.byKey(addEnvironment), findsNothing);
      });

      testWidgets('the other card shows it as it is typed', (tester) async {
        await pumpPage(
          tester,
          visible: cards,
          size: tall,
          stored: dive.copyWith(altitude: 1200, airTemp: 20),
        );
        await unlock(tester);
        await tester.tap(find.byTooltip('Edit Altitude Dive'));
        await settle(tester);
        final label = l10nOf(tester).diveLog_edit_label_surfacePressure;
        Finder onEnvironment(String text) => find.descendant(
          of: find.byType(DiveEnvironmentSection),
          matching: find.text(text),
        );

        await typeIn(tester, label, '9');
        await tester.enterText(fieldOf(label), '900');
        await settle(tester);

        expect(onEnvironment('900 mbar'), findsOneWidget);
        expect(onEnvironment('9 mbar'), findsNothing);
      });
    });

    // Typing the first value into an empty card changes whether the page
    // shows that card at all, and for Environment whether it shares a row
    // with Details. Neither may rebuild the editor being typed into.
    group('the first value typed into a card added from the strip', () {
      // Wide enough for Details and Environment to share a row, and below
      // the width at which the page moves into the list-and-detail layout.
      const wide = Size(1000, 2600);

      bool hasFocus(WidgetTester tester, Finder field) => tester
          .widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus;

      testWidgets('keeps the Environment editor, beside Details', (
        tester,
      ) async {
        await pumpPage(
          tester,
          size: wide,
          visible: const {
            DiveDetailSectionId.details,
            DiveDetailSectionId.environment,
          },
        );
        await unlock(tester);
        await tapStripChip(tester, 'environment');
        await settle(tester);
        final editor = find.byType(DiveEnvironmentCardEditor);
        final before = tester.state(editor);
        final details = find.byType(DiveDetailsSection);
        expect(
          tester.getRect(editor).left,
          greaterThan(tester.getRect(details).right - 1),
        );
        final label = l10nOf(tester).diveLog_edit_label_airTemp;

        await typeIn(tester, label, '2');

        expect(controller(tester).session!.working.airTemp, 2);
        expect(identical(tester.state(editor), before), isTrue);
        expect(hasFocus(tester, fieldOf(label)), isTrue);
        expect(
          tester.getRect(editor).left,
          greaterThan(tester.getRect(details).right - 1),
        );
      });

      testWidgets('keeps the Altitude editor', (tester) async {
        await pumpPage(tester, size: wide, visible: cards);
        await unlock(tester);
        await tapStripChip(tester, 'altitude');
        await settle(tester);
        final editor = find.byType(DiveAltitudeCardEditor);
        final before = tester.state(editor);
        final label = l10nOf(tester).diveLog_edit_label_altitude;

        await typeIn(tester, label, '12');

        expect(controller(tester).session!.working.altitude, 12);
        expect(identical(tester.state(editor), before), isTrue);
        expect(hasFocus(tester, fieldOf(label)), isTrue);
      });
    });
  });
}
