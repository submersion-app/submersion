import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_gas_role.dart';
import 'package:submersion/features/gas_calculators/domain/blending/flush_fee.dart';
import 'package:submersion/features/gas_calculators/presentation/pages/blender_settings_page.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../support/fake_app_settings_repository.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// The Riverpod `Override` type is sealed and not re-exported, so overrides
// are threaded through as `dynamic` and cast at the `ProviderScope` boundary
// (see test/helpers/test_app.dart).
Future<WidgetRef> _pump(
  WidgetTester tester, {
  List<dynamic> overrides = const [],
}) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(const AppSettings()),
        ),
        ...overrides,
      ].cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return const BlenderSettingsPage();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  testWidgets('rows are labelled by role, not by bank number', (tester) async {
    // Issue #42: banks are identities (oxygen, helium, topup) rather than
    // positions, and the defaults fill oxygen, then helium, then topup.
    await _pump(tester);

    expect(find.text('O₂'), findsOneWidget);
    expect(find.text('Helium'), findsOneWidget);
    expect(find.text('Topup'), findsOneWidget);
    expect(find.text('1.'), findsNothing);
  });

  testWidgets('the oxygen and helium roles show no purity field at all', (
    tester,
  ) async {
    // Issue #42: only the topup role's oxygen fraction is editable; oxygen
    // and helium are always 100% pure. Issue #44 follow-up: that fixed
    // value is no longer shown at all, not even as read-only text -- a
    // number nobody can change isn't information the diver needs here.
    await _pump(tester);

    expect(find.text('100 %'), findsNothing);
    expect(find.byKey(const Key('blender-gas-fixed-o2')), findsNothing);
    expect(find.byKey(const Key('blender-gas-fixed-he')), findsNothing);
    // Only the topup role gets a mix field.
    expect(find.byKey(const Key('blender-topup-o2')), findsOneWidget);
  });

  testWidgets('submitting the topup O2 field saves the preferences', (
    tester,
  ) async {
    final repo = FakeAppSettingsRepository();
    final ref = await _pump(
      tester,
      overrides: [appSettingsRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.enterText(find.byKey(const Key('blender-topup-o2')), '32');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(ref.read(blenderTopupO2PercentProvider), closeTo(32, 0.001));
    expect(repo.blenderPreferences?.topupO2Percent, closeTo(32, 0.001));
  });

  testWidgets('a stored price seeds its role row field, converted for '
      'display', (tester) async {
    // Eric's PR #1359 review point 3: the price sits directly below its
    // own fill-gas row, keyed by role (issue #42) so it survives a reorder.
    await _pump(
      tester,
      overrides: [
        blenderGasPricesProvider.overrideWith(
          (ref) => const [12.5, null, null],
        ),
      ],
    );

    expect(find.widgetWithText(TextField, '12.5'), findsOneWidget);
  });

  testWidgets('submitting a role row price field saves the preferences', (
    tester,
  ) async {
    final repo = FakeAppSettingsRepository();
    await _pump(
      tester,
      overrides: [appSettingsRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.enterText(
      find.byKey(const Key('blender-gas-price-o2')),
      '9.5',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      repo.blenderPreferences?.gasPrices[BlenderGasRole.o2.index],
      closeTo(9.5, 0.001),
    );
  });

  testWidgets('the up/down arrows reorder the fill roles, not drag', (
    tester,
  ) async {
    final repo = FakeAppSettingsRepository();
    final ref = await _pump(
      tester,
      overrides: [appSettingsRepositoryProvider.overrideWithValue(repo)],
    );

    expect(ref.read(blenderFillOrderProvider), kDefaultBlenderFillOrder);
    // The default order is oxygen first, so its up arrow is disabled.
    final o2Up = tester.widget<IconButton>(
      find.byKey(const Key('blender-gas-move-up-o2')),
    );
    expect(o2Up.onPressed, isNull);

    await tester.tap(find.byKey(const Key('blender-gas-move-down-o2')));
    await tester.pumpAndSettle();

    expect(ref.read(blenderFillOrderProvider), [
      BlenderGasRole.he,
      BlenderGasRole.o2,
      BlenderGasRole.topup,
    ]);
    expect(repo.blenderPreferences?.fillOrder, [
      BlenderGasRole.he,
      BlenderGasRole.o2,
      BlenderGasRole.topup,
    ]);
  });

  testWidgets('a role keeps its own price after being reordered', (
    tester,
  ) async {
    // Issue #42: the price belongs to the role's identity, not to the row
    // position, so moving a role must not move its price to another role.
    final ref = await _pump(
      tester,
      overrides: [
        blenderGasPricesProvider.overrideWith(
          (ref) => const [12.5, null, null],
        ),
      ],
    );

    ref.read(blenderFillOrderProvider.notifier).state = [
      BlenderGasRole.he,
      BlenderGasRole.o2,
      BlenderGasRole.topup,
    ];
    await tester.pumpAndSettle();

    final o2Price = tester.widget<TextField>(
      find.byKey(const Key('blender-gas-price-o2')),
    );
    expect(o2Price.controller?.text, '12.5');
  });

  testWidgets('a stored flush volume seeds its role row field, converted for '
      'display', (tester) async {
    // Issue #42 follow-up: the purge volume moved here from the Cost card,
    // keyed by role so it survives a reorder like the price does.
    await _pump(
      tester,
      overrides: [
        blenderFlushFeeGasesProvider.overrideWith(
          (ref) => const [
            FlushFeeGasSetting(volumeLiters: 40),
            FlushFeeGasSetting(volumeLiters: 20),
            FlushFeeGasSetting(volumeLiters: 20),
          ],
        ),
      ],
    );

    expect(find.widgetWithText(TextField, '40'), findsOneWidget);
  });

  testWidgets('submitting a role row flush volume field saves the '
      'preferences', (tester) async {
    final repo = FakeAppSettingsRepository();
    final ref = await _pump(
      tester,
      overrides: [appSettingsRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.enterText(
      find.byKey(const Key('blender-flush-fee-volume-o2')),
      '40',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      ref
          .read(blenderFlushFeeGasesProvider)[BlenderGasRole.o2.index]
          .volumeLiters,
      closeTo(40, 0.001),
    );
    expect(
      repo
          .blenderPreferences
          ?.flushFeeGases[BlenderGasRole.o2.index]
          .volumeLiters,
      closeTo(40, 0.001),
    );
  });

  testWidgets('a role keeps its own flush volume after being reordered', (
    tester,
  ) async {
    // Issue #42 follow-up: same reordering guarantee as the price.
    final ref = await _pump(
      tester,
      overrides: [
        blenderFlushFeeGasesProvider.overrideWith(
          (ref) => const [
            FlushFeeGasSetting(volumeLiters: 40),
            FlushFeeGasSetting(volumeLiters: 20),
            FlushFeeGasSetting(volumeLiters: 20),
          ],
        ),
      ],
    );

    ref.read(blenderFillOrderProvider.notifier).state = [
      BlenderGasRole.he,
      BlenderGasRole.o2,
      BlenderGasRole.topup,
    ];
    await tester.pumpAndSettle();

    final o2Volume = tester.widget<TextField>(
      find.byKey(const Key('blender-flush-fee-volume-o2')),
    );
    expect(o2Volume.controller?.text, '40');
  });
}
