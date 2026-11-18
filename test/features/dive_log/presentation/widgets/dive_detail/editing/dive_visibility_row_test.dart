import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/domain/visibility/visibility_range.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/features/dive_log/presentation/providers/visibility_input_mode_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_visibility_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

const _cardId = 'details';

/// The visibility input of the Details card, bound to a sitting
/// (issue #4527). Numbers are typed a character at a time, as a diver
/// types them: one `enterText` with the finished text hides what the
/// characters in between do to the sitting.
void main() {
  final l = AppLocalizationsEn();
  final bare = Dive(id: 'dive', dateTime: DateTime(2024, 6, 1, 10));
  // The default scale is the tropical one: good is 15 m up to 30 m.
  const scale = VisibilityScale.tropical;
  final good = scale.rangeFor(VisibilityBand.good);
  const imperial = AppSettings(depthUnit: DepthUnit.feet);

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  final rowSession = ValueNotifier<EditSession<Dive>?>(null);
  tearDownAll(rowSession.dispose);

  Future<RecordEditController<Dive>> pumpRow(
    WidgetTester tester,
    Dive dive, {
    AppSettings settings = const AppSettings(),
    MockSettingsNotifier? notifier,
    String? rememberedMode,
    List<Override> extra = const [],
    RecordEditController<Dive>? ownController,
  }) async {
    rowSession.value = null;
    final overrides = await getBaseOverrides(
      settingsNotifier: notifier ?? MockSettingsNotifier(settings),
    );
    // The base overrides start from empty preferences; what the device
    // remembered goes in after them.
    if (rememberedMode != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dive_edit_visibility_input_mode', rememberedMode);
    }
    // A test that ends the sitting itself passes its own controller.
    final controller =
        ownController ?? RecordEditController<Dive>(onSave: (_) async {});
    if (ownController == null) addTearDown(controller.dispose);
    controller
      ..unlock(dive)
      ..openCard(_cardId);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...overrides, ...extra],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 500,
                child: RecordEditScope<Dive>(
                  controller: controller,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // The controller's sitting, unless a test hands
                        // the row another one.
                        ValueListenableBuilder<EditSession<Dive>?>(
                          valueListenable: rowSession,
                          builder: (context, other, _) => DiveVisibilityRow(
                            session: other ?? controller.session!,
                          ),
                        ),
                        const TextField(key: ValueKey('elsewhere')),
                        const SizedBox(height: 900),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  StoredVisibility value(RecordEditController<Dive> controller) =>
      controller.session!.valueOf(diveVisibilityField);

  /// Opens the Precise row for typing.
  Future<void> focus(WidgetTester tester) async {
    await tester.tap(find.text(l.diveLog_edit_label_visibility));
    await tester.pump();
  }

  /// Types [text] into the open row a character at a time.
  Future<void> type(WidgetTester tester, String text) async {
    for (var end = 1; end <= text.length; end++) {
      await tester.enterText(
        find.byType(TextFormField),
        text.substring(0, end),
      );
      await tester.pump();
    }
  }

  Future<void> clear(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField), '');
    await tester.pump();
  }

  Future<void> switchTo(WidgetTester tester, String segment) async {
    await tester.tap(find.text(segment));
    await tester.pump();
  }

  ChoiceChip chip(WidgetTester tester, String name) =>
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, name));

  String? selectedChip(WidgetTester tester) => tester
      .widgetList<ChoiceChip>(find.byType(ChoiceChip))
      .where((c) => c.selected)
      .map((c) => (c.label as Text).data)
      .firstOrNull;

  group('precise', () {
    testWidgets('a measured dive shows its number, and opening it is no '
        'change', (tester) async {
      final controller = await pumpRow(
        tester,
        bare.copyWith(visibilityMeters: 12.4),
      );

      expect(find.text('12 m'), findsOneWidget);
      await focus(tester);
      await tester.tap(find.byKey(const ValueKey('elsewhere')));
      await tester.pump();

      expect(controller.isDirty, isFalse);
    });

    testWidgets('metric: the number shown, typed back, is no change', (
      tester,
    ) async {
      final controller = await pumpRow(
        tester,
        bare.copyWith(visibilityMeters: 12.4),
      );
      await focus(tester);

      await tester.enterText(find.byType(TextFormField), '1');
      await tester.pump();
      expect(value(controller), const StoredVisibility(meters: 1));
      expect(controller.isDirty, isTrue);

      await tester.enterText(find.byType(TextFormField), '12');
      await tester.pump();
      expect(value(controller), const StoredVisibility(meters: 12.4));
      expect(controller.isDirty, isFalse);
    });

    testWidgets('imperial: values that show alike are told apart', (
      tester,
    ) async {
      // 12 m is 39.37 ft and shows as 39.
      final controller = await pumpRow(
        tester,
        bare.copyWith(visibilityMeters: 12),
        settings: imperial,
      );
      expect(find.text('39 ft'), findsOneWidget);
      await focus(tester);

      await type(tester, '40');
      expect(value(controller).meters, closeTo(12.192, 1e-5));
      expect(controller.isDirty, isTrue);

      await type(tester, '39');
      expect(value(controller), const StoredVisibility(meters: 12));
      expect(controller.isDirty, isFalse);
    });

    testWidgets('a number the diver typed, cut back to the one shown, is no '
        'change', (tester) async {
      // 12 m shows as 39 ft. 39.4 ft is typed, then its decimals deleted:
      // the 39 left is the number the row showed for 12 m, not a rounding
      // of what was typed.
      final controller = await pumpRow(
        tester,
        bare.copyWith(visibilityMeters: 12),
        settings: imperial,
      );
      await focus(tester);
      await type(tester, '39.4');
      expect(value(controller).meters, closeTo(12.009, 1e-3));

      await tester.enterText(find.byType(TextFormField), '39.');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '39');
      await tester.pump();

      expect(value(controller), const StoredVisibility(meters: 12));
      expect(controller.isDirty, isFalse);
    });

    testWidgets('a finer value than the one shown is a change', (tester) async {
      final controller = await pumpRow(
        tester,
        bare.copyWith(visibilityMeters: 12.4),
      );
      await focus(tester);

      await type(tester, '12.6');

      expect(value(controller), const StoredVisibility(meters: 12.6));
    });

    testWidgets('a decimal comma is read', (tester) async {
      final controller = await pumpRow(tester, bare);
      await focus(tester);

      await type(tester, '12,5');

      expect(value(controller), const StoredVisibility(meters: 12.5));
    });

    testWidgets('typing a number replaces a stored range and bucket', (
      tester,
    ) async {
      final controller = await pumpRow(
        tester,
        bare.copyWith(
          visibilityMinMeters: good.minM,
          visibilityMaxMeters: good.maxM,
        ),
      );
      await switchTo(tester, l.diveLog_edit_visibility_modePrecise);
      await focus(tester);

      await type(tester, '18');

      expect(value(controller), const StoredVisibility(meters: 18));
      final working = controller.session!.working;
      expect(working.visibilityMinMeters, isNull);
      expect(working.visibilityMaxMeters, isNull);
    });

    testWidgets('emptying a measurement clears it', (tester) async {
      final controller = await pumpRow(
        tester,
        bare.copyWith(visibilityMeters: 12),
      );
      await focus(tester);

      await clear(tester);

      expect(value(controller), StoredVisibility.none);
      expect(controller.isDirty, isTrue);
    });

    testWidgets('typing and emptying over a stored range goes back to the '
        'range', (tester) async {
      final ranged = bare.copyWith(
        visibilityMinMeters: good.minM,
        visibilityMaxMeters: good.maxM,
      );
      final controller = await pumpRow(tester, ranged);
      await switchTo(tester, l.diveLog_edit_visibility_modePrecise);
      await focus(tester);

      await type(tester, '15');
      expect(controller.isDirty, isTrue);
      await clear(tester);

      expect(value(controller), StoredVisibility(range: good));
      expect(controller.isDirty, isFalse);
    });

    testWidgets('typing and emptying over a stored bucket goes back to the '
        'bucket', (tester) async {
      final controller = await pumpRow(
        tester,
        bare.copyWith(visibility: Visibility.good),
      );
      await switchTo(tester, l.diveLog_edit_visibility_modePrecise);
      await focus(tester);

      await type(tester, '15');
      await clear(tester);

      expect(
        value(controller),
        const StoredVisibility(legacy: Visibility.good),
      );
      expect(controller.isDirty, isFalse);
    });

    testWidgets('unreadable text marks the card and leaves the sitting '
        'alone', (tester) async {
      final controller = await pumpRow(
        tester,
        bare.copyWith(visibilityMeters: 12),
      );
      await focus(tester);

      await type(tester, '1.2.3');

      expect(controller.invalidCardIds, {_cardId});
      // '1' and '1.2' were values on the way; what cannot be read changes
      // nothing further.
      expect(value(controller), const StoredVisibility(meters: 1.2));
      expect(find.text(l.numberInput_invalidNumber('.')), findsOneWidget);
    });

    testWidgets('fixing unreadable text clears the mark', (tester) async {
      final controller = await pumpRow(tester, bare);
      await focus(tester);
      await type(tester, '1.2.3');
      expect(controller.invalidCardIds, {_cardId});

      await tester.enterText(find.byType(TextFormField), '14');
      await tester.pump();

      expect(controller.invalidCardIds, isEmpty);
      expect(value(controller), const StoredVisibility(meters: 14));
    });

    testWidgets('a negative number is unreadable', (tester) async {
      final controller = await pumpRow(
        tester,
        bare.copyWith(visibilityMeters: 12),
      );
      await focus(tester);

      await tester.enterText(find.byType(TextFormField), '-5');
      await tester.pump();

      expect(controller.invalidCardIds, {_cardId});
      expect(value(controller), const StoredVisibility(meters: 12));
      expect(controller.isDirty, isFalse);
    });

    testWidgets('switching to Range drops unreadable text and its mark', (
      tester,
    ) async {
      final controller = await pumpRow(
        tester,
        bare.copyWith(visibilityMeters: 12),
      );
      await focus(tester);
      await tester.enterText(find.byType(TextFormField), '1x');
      await tester.pump();
      expect(controller.invalidCardIds, {_cardId});

      await switchTo(tester, l.diveLog_edit_visibility_modeRange);

      expect(controller.invalidCardIds, isEmpty);
      expect(value(controller), const StoredVisibility(meters: 12));
      expect(controller.isDirty, isFalse);

      // Back in Precise the row rests on the sitting's value, not the text
      // that was dropped.
      await switchTo(tester, l.diveLog_edit_visibility_modePrecise);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('12 m'), findsOneWidget);
    });

    testWidgets('dropping unreadable text keeps a range picked in this '
        'sitting', (tester) async {
      final controller = await pumpRow(
        tester,
        bare.copyWith(visibilityMeters: 12),
      );
      await switchTo(tester, l.diveLog_edit_visibility_modeRange);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Good'));
      await tester.pump();
      expect(value(controller), StoredVisibility(range: good));

      await switchTo(tester, l.diveLog_edit_visibility_modePrecise);
      await focus(tester);
      await tester.enterText(find.byType(TextFormField), 'x');
      await tester.pump();
      expect(controller.invalidCardIds, {_cardId});
      await switchTo(tester, l.diveLog_edit_visibility_modeRange);

      expect(controller.invalidCardIds, isEmpty);
      expect(value(controller), StoredVisibility(range: good));
    });

    testWidgets('a refused Done scrolls the row into view', (tester) async {
      final controller = await pumpRow(tester, bare);
      await focus(tester);
      await tester.enterText(find.byType(TextFormField), 'x');
      await tester.pump();
      // Scroll the row out of the window.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -600),
      );
      await tester.pump();
      expect(tester.getTopLeft(find.byType(DiveVisibilityRow)).dy, lessThan(0));

      controller.closeCard(_cardId);
      await tester.pumpAndSettle();

      expect(controller.openCardIds, {_cardId});
      expect(
        tester.getTopLeft(find.byType(DiveVisibilityRow)).dy,
        greaterThanOrEqualTo(0),
      );
      expect(controller.revealRequest, isNull);
    });
  });

  group('range', () {
    testWidgets('a stored range on this scale selects its chip, and the '
        'sitting is clean', (tester) async {
      final controller = await pumpRow(
        tester,
        bare.copyWith(
          visibilityMinMeters: good.minM,
          visibilityMaxMeters: good.maxM,
        ),
      );

      expect(selectedChip(tester), 'Good');
      expect(controller.isDirty, isFalse);
    });

    testWidgets('turning the chip off clears the visibility; on again is '
        'clean', (tester) async {
      final controller = await pumpRow(
        tester,
        bare.copyWith(
          visibilityMinMeters: good.minM,
          visibilityMaxMeters: good.maxM,
        ),
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Good'));
      await tester.pump();
      expect(value(controller), StoredVisibility.none);
      expect(selectedChip(tester), isNull);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Good'));
      await tester.pump();
      expect(controller.isDirty, isFalse);
      expect(selectedChip(tester), 'Good');
    });

    testWidgets('a range stored under another scale selects no chip and is '
        'kept', (tester) async {
      const other = VisibilityRange(minM: 7, maxM: 11);
      final controller = await pumpRow(
        tester,
        bare.copyWith(
          visibilityMinMeters: other.minM,
          visibilityMaxMeters: other.maxM,
        ),
      );

      expect(selectedChip(tester), isNull);
      expect(find.textContaining('7'), findsWidgets);
      expect(value(controller), const StoredVisibility(range: other));
      expect(controller.isDirty, isFalse);
    });

    testWidgets('a stored bucket is kept until a chip is tapped', (
      tester,
    ) async {
      final controller = await pumpRow(
        tester,
        bare.copyWith(visibility: Visibility.good),
      );
      expect(selectedChip(tester), isNull);
      expect(controller.isDirty, isFalse);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Moderate'));
      await tester.pump();

      expect(
        value(controller),
        StoredVisibility(range: scale.rangeFor(VisibilityBand.moderate)),
      );
      expect(controller.session!.working.visibility, isNull);
    });

    testWidgets('a chip replaces a measurement', (tester) async {
      final controller = await pumpRow(
        tester,
        bare.copyWith(visibilityMeters: 12),
      );
      await switchTo(tester, l.diveLog_edit_visibility_modeRange);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Good'));
      await tester.pump();

      expect(value(controller), StoredVisibility(range: good));
      expect(controller.session!.working.visibilityMeters, isNull);
      expect(chip(tester, 'Good').selected, isTrue);
    });
  });

  group('what Range says of a measured distance', () {
    const units = UnitFormatter(AppSettings());

    testWidgets('a distance the sitting holds is named, since no chip can '
        'show it', (tester) async {
      await pumpRow(tester, bare.copyWith(visibilityMeters: 12));

      await switchTo(tester, l.diveLog_edit_visibility_modeRange);

      expect(selectedChip(tester), isNull);
      expect(
        find.text(formatMeasuredVisibility(12, scale, l, units)),
        findsOneWidget,
      );
    });

    testWidgets('after unreadable text is dropped, what is still held is '
        'named', (tester) async {
      final controller = await pumpRow(tester, bare);
      await focus(tester);
      await type(tester, '1.2.3');
      expect(value(controller), const StoredVisibility(meters: 1.2));

      await switchTo(tester, l.diveLog_edit_visibility_modeRange);

      expect(
        find.text(formatMeasuredVisibility(1.2, scale, l, units)),
        findsOneWidget,
      );
    });

    testWidgets('with a chip picked there is no such line', (tester) async {
      await pumpRow(tester, bare.copyWith(visibilityMeters: 12));
      await switchTo(tester, l.diveLog_edit_visibility_modeRange);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Good'));
      await tester.pump();

      expect(
        find.text(formatMeasuredVisibility(12, scale, l, units)),
        findsNothing,
      );
    });
  });

  group('a look at the other input changes nothing', () {
    Future<void> lookAtPrecise(WidgetTester tester) async {
      await switchTo(tester, l.diveLog_edit_visibility_modePrecise);
      await focus(tester);
      await tester.tap(find.byKey(const ValueKey('elsewhere')));
      await tester.pump();
      await switchTo(tester, l.diveLog_edit_visibility_modeRange);
    }

    testWidgets('for a dive stored with an old bucket', (tester) async {
      final controller = await pumpRow(
        tester,
        bare.copyWith(visibility: Visibility.good),
      );

      await lookAtPrecise(tester);

      expect(
        value(controller),
        const StoredVisibility(legacy: Visibility.good),
      );
      expect(controller.isDirty, isFalse);
    });

    testWidgets('for a range stored under another scale', (tester) async {
      const other = VisibilityRange(minM: 7, maxM: 11);
      final controller = await pumpRow(
        tester,
        bare.copyWith(
          visibilityMinMeters: other.minM,
          visibilityMaxMeters: other.maxM,
        ),
      );

      await lookAtPrecise(tester);

      expect(value(controller), const StoredVisibility(range: other));
      expect(controller.isDirty, isFalse);
    });

    testWidgets('for a dive with no visibility', (tester) async {
      final controller = await pumpRow(tester, bare, rememberedMode: 'range');

      await lookAtPrecise(tester);

      expect(value(controller), StoredVisibility.none);
      expect(controller.isDirty, isFalse);
    });
  });

  testWidgets('handed another sitting, the row shows that sitting and drops '
      'its old mark', (tester) async {
    final controller = await pumpRow(
      tester,
      bare.copyWith(visibilityMeters: 12),
    );
    await focus(tester);
    await tester.enterText(find.byType(TextFormField), 'x');
    await tester.pump();
    expect(controller.invalidCardIds, {_cardId});

    // The same row, handed a sitting on a dive stored with a range.
    final other = EditSession<Dive>(
      bare.copyWith(
        visibilityMinMeters: good.minM,
        visibilityMaxMeters: good.maxM,
      ),
    );
    addTearDown(other.dispose);
    rowSession.value = other;
    await tester.pump();

    expect(controller.invalidCardIds, isEmpty);
    // It opens in the input the new sitting's value was entered in.
    expect(selectedChip(tester), 'Good');
  });

  testWidgets('a row whose first build failed leaves the ended sitting '
      'alone', (tester) async {
    final controller = RecordEditController<Dive>(onSave: (_) async {});
    // With no visibility the row asks which input the device used last.
    await pumpRow(
      tester,
      bare,
      ownController: controller,
      extra: [
        visibilityInputModeProvider.overrideWith(
          (ref) => throw StateError('no preferences on this device'),
        ),
      ],
    );
    expect(tester.takeException(), isNotNull);

    // The sitting ends, then the row goes: it must not start listening to
    // the sitting on its way out.
    controller.dispose();
    await tester.pumpWidget(const SizedBox());

    expect(tester.takeException(), isNull);
  });

  group('the switch', () {
    testWidgets('a dive with a measurement opens in Precise', (tester) async {
      await pumpRow(tester, bare.copyWith(visibilityMeters: 12));

      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('a dive with a range or a bucket opens in Range', (
      tester,
    ) async {
      await pumpRow(tester, bare.copyWith(visibility: Visibility.good));

      expect(find.byType(ChoiceChip), findsNWidgets(4));
    });

    testWidgets('a dive with none opens in the remembered mode', (
      tester,
    ) async {
      await pumpRow(tester, bare, rememberedMode: 'range');

      expect(find.byType(ChoiceChip), findsNWidgets(4));
    });

    testWidgets('with nothing remembered, a dive with none opens in '
        'Precise', (tester) async {
      await pumpRow(tester, bare);

      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('switching alone changes nothing', (tester) async {
      final controller = await pumpRow(
        tester,
        bare.copyWith(visibilityMeters: 12),
      );

      await switchTo(tester, l.diveLog_edit_visibility_modeRange);
      await switchTo(tester, l.diveLog_edit_visibility_modePrecise);

      expect(controller.isDirty, isFalse);
    });

    testWidgets('a number typed in Precise survives a look at Range', (
      tester,
    ) async {
      final controller = await pumpRow(tester, bare);
      await focus(tester);
      await type(tester, '12');

      await switchTo(tester, l.diveLog_edit_visibility_modeRange);

      expect(value(controller), const StoredVisibility(meters: 12));
      expect(selectedChip(tester), isNull);
    });
  });

  group('following what changes underneath', () {
    testWidgets('a change of units reshows the value and stays clean', (
      tester,
    ) async {
      final notifier = MockSettingsNotifier(const AppSettings());
      final controller = await pumpRow(
        tester,
        bare.copyWith(visibilityMeters: 12),
        notifier: notifier,
      );
      expect(find.text('12 m'), findsOneWidget);

      notifier.state = imperial;
      await tester.pump();
      await tester.pump();

      expect(find.text('39 ft'), findsOneWidget);
      expect(controller.isDirty, isFalse);
    });

    testWidgets('a rebase to another visibility is followed while '
        'untouched', (tester) async {
      final controller = await pumpRow(
        tester,
        bare.copyWith(visibilityMeters: 12),
      );

      controller.storedChanged(bare.copyWith(visibilityMeters: 20));
      await tester.pump();

      expect(find.text('20 m'), findsOneWidget);
      expect(controller.isDirty, isFalse);
    });

    testWidgets('a typed number is kept through a rebase of something '
        'else', (tester) async {
      final controller = await pumpRow(
        tester,
        bare.copyWith(visibilityMeters: 12),
      );
      await focus(tester);
      await type(tester, '18');

      controller.storedChanged(
        bare.copyWith(visibilityMeters: 12, notes: 'Changed elsewhere'),
      );
      await tester.pump();

      expect(value(controller), const StoredVisibility(meters: 18));
    });
  });

  // Range and Precise share one form row. After a look at Range, Precise
  // must come back resting, as it opened, not as an open field.
  group('switching inputs', () {
    testWidgets('Precise comes back resting after a look at Range', (
      tester,
    ) async {
      await pumpRow(tester, bare.copyWith(visibilityMeters: 18));
      expect(find.byType(TextFormField), findsNothing);

      await switchTo(tester, l.diveLog_edit_visibility_modeRange);
      await switchTo(tester, l.diveLog_edit_visibility_modePrecise);

      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('18 m'), findsOneWidget);
    });

    testWidgets('Precise opened for typing comes back resting after a look '
        'at Range', (tester) async {
      await pumpRow(tester, bare.copyWith(visibilityMeters: 18));
      await focus(tester);
      expect(find.byType(TextFormField), findsOneWidget);

      await switchTo(tester, l.diveLog_edit_visibility_modeRange);
      await switchTo(tester, l.diveLog_edit_visibility_modePrecise);

      expect(find.byType(TextFormField), findsNothing);
    });
  });
}
