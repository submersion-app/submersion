import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_billing_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../support/fake_app_settings_repository.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A tank from the diver's own gear (issue #2926: the cost card reads a
/// cylinder's own equipment entry now, not the global tank presets).
EquipmentItem _tank(String id, String name, {double? volumeL}) => EquipmentItem(
  id: id,
  name: name,
  type: EquipmentType.tank,
  attributes: [
    if (volumeL != null)
      EquipmentAttribute(
        id: '',
        equipmentId: id,
        key: EquipmentAttrKeys.volumeL,
        valueNum: volumeL,
      ),
  ],
);

// The Riverpod `Override` type is sealed and not re-exported, so overrides
// are threaded through as `dynamic` and cast at the `ProviderScope` boundary
// (see test/helpers/test_app.dart).
Future<WidgetRef> _pump(
  WidgetTester tester, {
  List<dynamic> overrides = const [],
  List<EquipmentItem>? gear,
  double textScale = 1,
}) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) =>
              _TestSettingsNotifier(const AppSettings(defaultCurrency: 'CHF')),
        ),
        activeEquipmentProvider.overrideWith(
          (ref) async =>
              gear ??
              [
                _tank('al80', 'AL80', volumeL: 11.1),
                _tank('deco', 'Deco bottle', volumeL: 3),
              ],
        ),
        ...overrides,
      ].cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Consumer(
              builder: (context, ref, _) {
                captured = ref;
                return const BlenderBillingCard();
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  // The arithmetic itself is pinned to the cent against both worked examples
  // in blend_billing_test.dart. What matters here is that the card is wired to
  // the real cylinder volume and prices, which proportionality demonstrates
  // without restating the formula.
  testWidgets('the total scales with the cylinder volume', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderGasPricesProvider.notifier).state = const [2.0, 7.99, 0.1];
    ref.read(blenderCylinderLitersProvider.notifier).state = 3;
    await tester.pumpAndSettle();
    final small = ref.read(blenderBillingProvider).total!;

    ref.read(blenderCylinderLitersProvider.notifier).state = 6;
    await tester.pumpAndSettle();
    final large = ref.read(blenderBillingProvider).total!;

    expect(large, closeTo(small * 2, 1e-9));
    expect(find.text('Total'), findsOneWidget);
  });

  testWidgets('shows the bar delivered on every line', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderCylinderLitersProvider.notifier).state = 12;
    await tester.pumpAndSettle();
    expect(find.textContaining('+'), findsWidgets);
  });

  testWidgets('an unpriced gas suppresses the total', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderGasPricesProvider.notifier).state = const [2.0, null, null];
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a price for every gas'), findsOneWidget);
  });

  testWidgets('states the billing basis', (tester) async {
    await _pump(tester);
    expect(find.textContaining('pressure delivered'), findsOneWidget);
  });

  testWidgets('defaults the currency to the diver setting', (tester) async {
    final ref = await _pump(tester);
    expect(ref.read(blenderCurrencyProvider), 'CHF');
  });

  testWidgets('an unreadable cylinder volume says why and keeps the volume '
      '(#1900)', (tester) async {
    final ref = await _pump(tester);
    final volumeField = find.byType(TextField).first;
    await tester.enterText(volumeField, '12');
    await tester.pump();
    await tester.enterText(volumeField, '1..2');
    await tester.pump();

    expect(find.textContaining('Enter a valid number'), findsOneWidget);
    expect(
      ref.read(blenderCylinderLitersProvider),
      closeTo(12, 0.01),
      reason: 'unreadable text used to read as a 0 L cylinder',
    );
  });

  // Issue #2926: the cost card reads a cylinder from the diver's own gear
  // (same picker as the start cylinder and "Log this fill"), not the global
  // tank presets. The free-text field stays, for a customer's cylinder that
  // has no equipment entry of its own.
  testWidgets('choosing a cylinder fills the volume field', (tester) async {
    final ref = await _pump(tester);
    await tester.tap(find.byKey(const Key('blender-billing-choose-cylinder')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deco bottle'));
    await tester.pumpAndSettle();

    expect(ref.read(blenderCylinderLitersProvider), closeTo(3, 0.01));
  });

  testWidgets('the picker offers exactly the diver-owned tanks', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('blender-billing-choose-cylinder')));
    await tester.pumpAndSettle();
    for (final label in ['AL80', 'Deco bottle']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('the picker never offers a tag scan here', (tester) async {
    // A scan would import the tag's fill into the cylinder's history (spec
    // section 11), a side effect this card only wants the water volume from.
    await _pump(tester);
    await tester.tap(find.byKey(const Key('blender-billing-choose-cylinder')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('blender-scan-tag')), findsNothing);
  });

  testWidgets('a tank with no recorded volume says so and keeps the field', (
    tester,
  ) async {
    final ref = await _pump(tester, gear: [_tank('spare', 'Spare 12')]);
    ref.read(blenderCylinderLitersProvider.notifier).state = 11.1;
    await tester.tap(find.byKey(const Key('blender-billing-choose-cylinder')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spare 12'));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(BlenderBillingCard)),
    );
    expect(
      find.text(l10n.gasCalculators_blender_cylinderNoVolume('Spare 12')),
      findsOneWidget,
    );
    expect(ref.read(blenderCylinderLitersProvider), closeTo(11.1, 0.01));
  });

  testWidgets(
    'with no tanks in the gear, says to type the volume instead of opening '
    'an empty picker',
    (tester) async {
      final ref = await _pump(tester, gear: const []);
      ref.read(blenderCylinderLitersProvider.notifier).state = 11.1;
      await tester.tap(
        find.byKey(const Key('blender-billing-choose-cylinder')),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(BlenderBillingCard)),
      );
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.text(l10n.gasCalculators_blender_noCylinders),
        findsOneWidget,
      );
      expect(ref.read(blenderCylinderLitersProvider), closeTo(11.1, 0.01));
    },
  );

  testWidgets(
    'on a narrow card at a large text size, Choose cylinder wraps its label '
    'onto more lines instead of truncating it',
    (tester) async {
      // TextButton.icon puts its label in a Flexible, so the label can wrap;
      // an ellipsis overflow would pin it to one truncated line instead.
      await tester.binding.setSurfaceSize(const Size(260, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(tester, textScale: 3);

      final label = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(const Key('blender-billing-choose-cylinder')),
          matching: find.text('Choose cylinder'),
        ),
      );
      final lineHeight = label.getFullHeightForCaret(
        const TextPosition(offset: 0),
      );
      expect(tester.takeException(), isNull);
      expect(label.didExceedMaxLines, isFalse);
      expect(label.size.height, greaterThan(lineHeight * 1.5));
    },
  );

  testWidgets('submitting a typed cylinder volume saves the preferences', (
    tester,
  ) async {
    final repo = FakeAppSettingsRepository();
    final ref = await _pump(
      tester,
      overrides: [appSettingsRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.enterText(find.byType(TextField).first, '15');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(ref.read(blenderCylinderLitersProvider), closeTo(15, 0.001));
    expect(repo.blenderPreferences?.cylinderWaterLiters, closeTo(15, 0.001));
  });

  group('flush fee gas row', () {
    // Issue #44 follow-up: an InputDecorator still reads as a disabled
    // input field (border, floating label box) even with no TextField
    // inside it. The purge volume and price are read from settings and
    // must show as plain text instead, the same look as _costLine.
    testWidgets('shows the price and purge volume as plain text, not a '
        'field-styled control', (tester) async {
      final ref = await _pump(tester);
      ref.read(blenderFlushFeeEnabledProvider.notifier).state = true;
      ref.read(blenderGasPricesProvider.notifier).state = const [
        7.5,
        null,
        null,
      ];
      await tester.pumpAndSettle();

      for (final key in [
        'blender-flush-fee-volume-o2',
        'blender-flush-fee-price-o2',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(InputDecorator),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(TextField),
          ),
          findsNothing,
        );
      }
      expect(find.textContaining('20'), findsWidgets);
      expect(find.textContaining('7.5'), findsWidgets);
    });

    testWidgets(
      'lines up one tab-aligned row per gas, with the currency instead of '
      'a hard-coded "price" label',
      (tester) async {
        // Issue #44: label, volume and price sit on the same row per gas,
        // in the same columns for every role, instead of two stacked
        // label/value blocks. The rate carries the diver's actual currency
        // rather than a hard-coded word.
        final ref = await _pump(tester);
        ref.read(blenderFlushFeeEnabledProvider.notifier).state = true;
        ref.read(blenderGasPricesProvider.notifier).state = const [
          7.5,
          null,
          null,
        ];
        await tester.pumpAndSettle();

        final o2Row = find.byKey(const Key('blender-flush-fee-row-o2'));
        expect(o2Row, findsOneWidget);
        expect(
          find.descendant(of: o2Row, matching: find.textContaining('O₂')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: o2Row,
            matching: find.byKey(const Key('blender-flush-fee-volume-o2')),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: o2Row,
            matching: find.byKey(const Key('blender-flush-fee-price-o2')),
          ),
          findsOneWidget,
        );
        // The unit and currency now sit once in the column headers instead
        // of being repeated on every row.
        expect(find.textContaining('CHF/100'), findsOneWidget);
        expect(find.text('Price'), findsNothing);
      },
    );
  });
}
