import 'dart:convert';
import 'dart:io';

import 'package:excel_community/excel_community.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_gas_role.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/blending/flush_fee.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_billing_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_invoice_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_invoice_export_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The share helpers write into getApplicationDocumentsDirectory(), a
/// platform channel with no implementation under flutter_test.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

class _FakeSharePlatform extends SharePlatform {
  final List<ShareParams> calls = [];

  @override
  Future<ShareResult> share(ShareParams params) async {
    calls.add(params);
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Opens "Add a line", switched to the free-amount kind when [freeAmount].
Future<void> _openAddLine(
  WidgetTester tester, {
  bool freeAmount = false,
}) async {
  await tester.tap(find.byKey(const Key('blender-add-manual-line')));
  await tester.pumpAndSettle();
  if (freeAmount) {
    await tester.tap(find.text('Free amount'));
    await tester.pumpAndSettle();
  }
}

/// Picks [gas] from the gas fill's dropdown.
Future<void> _pickGas(WidgetTester tester, String gas) async {
  await tester.tap(find.byKey(const Key('blender-line-gas')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(gas).last);
  await tester.pumpAndSettle();
}

Future<WidgetRef> _pump(
  WidgetTester tester, {
  List<TankPresetEntity> presets = const [],
  AppSettings settings = const AppSettings(defaultCurrency: 'CHF'),
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
        tankPresetsProvider.overrideWith((ref) async => presets),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Consumer(
              builder: (context, ref, _) {
                captured = ref;
                return const Column(
                  children: [BlenderBillingCard(), BlenderInvoiceCard()],
                );
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
  group('BilledFill', () {
    test('round-trips through JSON, itemisation included', () {
      const fill = BilledFill(
        id: 'a',
        label: 'Tx 18/45',
        lines: [
          BilledGasLine(
            gas: 'O₂',
            addedBar: 10,
            cost: 10,
            freeGasLiters: 30,
            cylinderLiters: 12,
          ),
          BilledGasLine(gas: 'He', addedBar: 80, cost: 20, freeGasLiters: 240),
        ],
        total: 35,
      );
      final decoded = BilledFill.fromJson(
        jsonDecode(jsonEncode(fill.toJson())) as Map<String, dynamic>,
      )!;
      expect(decoded.label, 'Tx 18/45');
      expect(decoded.lines, hasLength(2));
      expect(decoded.lines[0].cylinderLiters, 12);
      expect(decoded.lines[1].gas, 'He');
      expect(decoded.lines[1].freeGasLiters, 240);
      expect(decoded.total, 35);
      expect(decoded.isManual, isFalse);
    });

    test('a line saved before #1335 has no volume, and that survives a '
        'round trip', () {
      const line = BilledGasLine(gas: 'O₂', addedBar: 10, cost: 10);
      final decoded = BilledGasLine.fromJson(
        jsonDecode(jsonEncode(line.toJson())) as Map<String, dynamic>,
      )!;
      expect(decoded.freeGasLiters, isNull);
    });

    test('a line saved before #1876 has no cylinder size, and that survives '
        'a round trip', () {
      const line = BilledGasLine(
        gas: 'O₂',
        addedBar: 10,
        cost: 10,
        freeGasLiters: 30,
      );
      final decoded = BilledGasLine.fromJson(
        jsonDecode(jsonEncode(line.toJson())) as Map<String, dynamic>,
      )!;
      expect(decoded.cylinderLiters, isNull);
    });

    test('a manual line has no itemisation', () {
      const fill = BilledFill(
        id: 'b',
        label: 'Analyser cell',
        lines: [],
        total: 40,
      );
      expect(fill.isManual, isTrue);
    });

    test('a hand-entered gas fill round-trips its role and start pressure '
        '(#2302)', () {
      const fill = BilledFill(
        id: 'c',
        label: 'Helium',
        lines: [
          BilledGasLine(
            gas: 'Helium',
            addedBar: 150,
            cost: 27,
            freeGasLiters: 1800,
            cylinderLiters: 12,
            role: BlenderGasRole.he,
            startBar: 50,
          ),
        ],
        total: 27,
      );
      final decoded = BilledFill.fromJson(
        jsonDecode(jsonEncode(fill.toJson())) as Map<String, dynamic>,
      )!;
      final line = decoded.manualGasLine;
      expect(line, isNotNull);
      expect(line!.role, BlenderGasRole.he);
      expect(line.startBar, 50);
      expect(line.endBar, 200);
      expect(decoded.isManual, isFalse);
    });

    test('a computed fill is not a hand-entered gas fill', () {
      const fill = BilledFill(
        id: 'd',
        label: 'Tx 18/45',
        lines: [BilledGasLine(gas: 'O₂', addedBar: 10, cost: 10)],
        total: 10,
      );
      expect(fill.manualGasLine, isNull);
    });

    test('an unknown role in a synced blob decodes to none, keeping the '
        'line', () {
      final line = BilledGasLine.fromJson({
        'gas': 'X',
        'addedBar': 10,
        'role': 'argon',
        'startBar': 'oops',
      })!;
      expect(line.role, isNull);
      expect(line.startBar, isNull);
      expect(line.addedBar, 10);
    });

    test('a manual line saved with the retired custom mix still decodes, '
        'without it (#2302)', () {
      final decoded = BilledFill.fromJson({
        'id': 'e',
        'label': 'Tx 21/35',
        'lines': [],
        'total': 40,
        'customMix': {'cylinderLiters': 11.1, 'o2': 21, 'he': 35},
      })!;
      expect(decoded.label, 'Tx 21/35');
      expect(decoded.total, 40);
      expect(decoded.isManual, isTrue);
      expect(decoded.toJson().containsKey('customMix'), isFalse);
    });

    test('copyWith can replace the lines, and leaves them alone otherwise', () {
      const fill = BilledFill(
        id: 'f',
        label: 'Helium',
        lines: [
          BilledGasLine(
            gas: 'Helium',
            addedBar: 150,
            cost: 27,
            role: BlenderGasRole.he,
          ),
        ],
        total: 27,
      );
      expect(fill.copyWith(label: 'x').lines, hasLength(1));
      expect(fill.copyWith(lines: const []).isManual, isTrue);
    });

    test('an unpriced line makes the total incomplete, not smaller', () {
      final total = totalOf(const [
        BilledFill(id: 'a', label: 'x', lines: [], total: 35),
        BilledFill(id: 'b', label: 'y', lines: [], total: null),
      ]);
      expect(total.amount, 35);
      expect(total.complete, isFalse);
    });

    test('preferences carry the bill through a round trip', () {
      final prefs = BlenderPreferences.defaults(cylinderWaterLiters: 12)
          .copyWith(
            billedFills: const [
              BilledFill(id: 'a', label: 'Tx 18/45', lines: [], total: 35),
            ],
            billedTo: 'Ada',
          );
      final decoded = BlenderPreferences.fromJson(
        jsonDecode(jsonEncode(prefs.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.billedFills, hasLength(1));
      expect(decoded.billedFills.single.label, 'Tx 18/45');
      expect(decoded.billedTo, 'Ada');
    });

    test('billed fills are capped', () {
      final many = List.generate(
        BlenderPreferences.maxBilledFills + 5,
        (i) => BilledFill(id: '$i', label: 'x', lines: const [], total: 1),
      );
      final capped = BlenderPreferences.defaults(
        cylinderWaterLiters: 12,
      ).copyWith(billedFills: many);
      expect(capped.billedFills, hasLength(BlenderPreferences.maxBilledFills));
    });

    test('the invoice date and archived invoices round-trip through JSON', () {
      final date = DateTime(2026, 3, 5);
      final prefs = BlenderPreferences.defaults(cylinderWaterLiters: 12)
          .copyWith(
            billedDate: date,
            archivedInvoices: [
              ArchivedInvoice(
                id: 'inv-1',
                date: date,
                billedTo: 'Ada',
                fills: const [
                  BilledFill(id: 'a', label: 'Tx 18/45', lines: [], total: 35),
                ],
                total: 35,
              ),
            ],
          );
      final decoded = BlenderPreferences.fromJson(
        jsonDecode(jsonEncode(prefs.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.billedDate, date);
      expect(decoded.archivedInvoices, hasLength(1));
      expect(decoded.archivedInvoices.single.billedTo, 'Ada');
      expect(decoded.archivedInvoices.single.fills.single.label, 'Tx 18/45');
      expect(decoded.archivedInvoices.single.total, 35);
    });

    test('a blob with no invoice date yet decodes to null, not a made-up '
        'date', () {
      final prefs = BlenderPreferences.defaults(cylinderWaterLiters: 12);
      final decoded = BlenderPreferences.fromJson(
        jsonDecode(jsonEncode(prefs.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.billedDate, isNull);
    });

    test('an archived invoice keeps its currency snapshot through JSON, and '
        'an older one without it decodes to null rather than a made-up '
        'code', () {
      final withCurrency = ArchivedInvoice.fromJson(
        jsonDecode(
              jsonEncode(
                ArchivedInvoice(
                  id: 'a',
                  date: DateTime(2026, 3, 5),
                  billedTo: 'Ada',
                  fills: const [],
                  total: 35,
                  currencyCode: 'CHF',
                ).toJson(),
              ),
            )
            as Map<String, dynamic>,
      )!;
      expect(withCurrency.currencyCode, 'CHF');

      final withoutCurrency = ArchivedInvoice.fromJson({
        'id': 'b',
        'date': DateTime(2026, 3, 5).toIso8601String(),
        'billedTo': 'Ada',
        'fills': [],
        'total': 35,
      })!;
      expect(withoutCurrency.currencyCode, isNull);
    });

    test('archived invoices are capped, dropping the oldest', () {
      var invoices = <ArchivedInvoice>[];
      for (var i = 0; i < kMaxArchivedInvoices + 5; i++) {
        invoices = appendArchivedCapped(
          invoices,
          ArchivedInvoice(
            id: '$i',
            date: DateTime(2026, 1, 1),
            billedTo: '',
            fills: const [],
            total: 1,
          ),
        );
      }
      expect(invoices, hasLength(kMaxArchivedInvoices));
      expect(invoices.last.id, '${kMaxArchivedInvoices + 4}');
      expect(invoices.first.id, '5');
    });
  });

  group('invoice card', () {
    testWidgets('starts empty', (tester) async {
      await _pump(tester);
      expect(find.textContaining('Nothing billed yet'), findsOneWidget);
    });

    testWidgets('saving a fill puts it on the bill with its itemisation', (
      tester,
    ) async {
      final ref = await _pump(tester);
      ref.read(blenderCylinderLitersProvider.notifier).state = 3;
      ref.read(blenderTargetMixProvider.notifier).state = const GasMix(
        o2: 18,
        he: 45,
      );
      ref.read(blenderGasPricesProvider.notifier).state = const [
        2.0,
        10.0,
        0.1,
      ];
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('blender-save-fill')));
      await tester.pumpAndSettle();

      final fills = ref.read(blenderBilledFillsProvider);
      expect(fills, hasLength(1));
      expect(fills.single.label, 'Tx 18/45');
      expect(fills.single.lines, hasLength(3));
      expect(fills.single.total, isNotNull);
      expect(find.text('Tx 18/45'), findsWidgets);
      // The volume is frozen at save time (#1335), not just the pressure.
      expect(fills.single.lines.every((l) => l.freeGasLiters != null), isTrue);
      // The cylinder size in effect at save time is frozen too (#1876), so
      // the invoice can itemise which bottle each fill went into.
      expect(fills.single.lines.every((l) => l.cylinderLiters == 3), isTrue);
    });

    testWidgets('two fills add up', (tester) async {
      final ref = await _pump(tester);
      ref.read(blenderBilledFillsProvider.notifier).state = const [
        BilledFill(id: 'a', label: 'Tx 18/45', lines: [], total: 35),
        BilledFill(id: 'b', label: 'Tx 15/55', lines: [], total: 35),
      ];
      await tester.pumpAndSettle();

      expect(totalOf(ref.read(blenderBilledFillsProvider)).amount, 70);
      expect(find.textContaining('70'), findsWidgets);
    });

    testWidgets('a line can be deleted', (tester) async {
      final ref = await _pump(tester);
      ref.read(blenderBilledFillsProvider.notifier).state = const [
        BilledFill(id: 'a', label: 'Tx 18/45', lines: [], total: 35),
      ];
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Actions for Tx 18/45'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Tx 18/45'));
      await tester.pumpAndSettle();

      expect(ref.read(blenderBilledFillsProvider), isEmpty);
    });

    testWidgets('a free-amount line can be added', (tester) async {
      final ref = await _pump(tester);
      await _openAddLine(tester, freeAmount: true);

      await tester.enterText(
        find.byKey(const Key('blender-line-description')),
        'Analyser cell',
      );
      await tester.enterText(
        find.byKey(const Key('blender-line-amount')),
        '12.50',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final fills = ref.read(blenderBilledFillsProvider);
      expect(fills, hasLength(1));
      expect(fills.single.isManual, isTrue);
      expect(fills.single.total, closeTo(12.50, 0.001));
    });

    testWidgets('a free amount with nothing to name it says so', (
      tester,
    ) async {
      // PR #1359 review: with nothing to label the line with, Save simply
      // returned - no line, no message, a button that reads as broken.
      final ref = await _pump(tester);
      await _openAddLine(tester, freeAmount: true);
      await tester.enterText(
        find.byKey(const Key('blender-line-amount')),
        '12.50',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Enter a description'), findsOneWidget);
      // Still open, with the amount intact, so the diver can fix it in place.
      expect(find.byKey(const Key('blender-line-amount')), findsOneWidget);
      expect(ref.read(blenderBilledFillsProvider), isEmpty);
    });

    testWidgets('the kind switch shows only the fields that kind needs '
        '(#2302)', (tester) async {
      await _pump(tester);
      await _openAddLine(tester);

      // A new line starts as a gas fill.
      expect(find.byKey(const Key('blender-line-gas')), findsOneWidget);
      expect(find.byKey(const Key('blender-line-cylinder')), findsOneWidget);
      expect(
        find.byKey(const Key('blender-line-start-pressure')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('blender-line-end-pressure')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('blender-line-computed-amount')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('blender-line-amount')), findsNothing);

      await tester.tap(find.text('Free amount'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('blender-line-amount')), findsOneWidget);
      expect(find.byKey(const Key('blender-line-gas')), findsNothing);
      expect(find.byKey(const Key('blender-line-cylinder')), findsNothing);
      expect(find.byKey(const Key('blender-line-end-pressure')), findsNothing);
      expect(
        find.byKey(const Key('blender-line-computed-amount')),
        findsNothing,
      );
    });

    testWidgets('a gas fill is priced from the cylinder, the pressures and '
        'the gas price (#2302)', (tester) async {
      final ref = await _pump(tester);
      ref.read(blenderGasPricesProvider.notifier).state = const [1.0, 1.5, 0.1];
      await _openAddLine(tester);

      await _pickGas(tester, 'Helium');
      await tester.enterText(
        find.byKey(const Key('blender-line-cylinder')),
        '12',
      );
      await tester.enterText(
        find.byKey(const Key('blender-line-start-pressure')),
        '50',
      );
      await tester.enterText(
        find.byKey(const Key('blender-line-end-pressure')),
        '200',
      );
      await tester.pumpAndSettle();

      // Shown live, as text rather than an editable field.
      expect(
        tester
            .widget<Text>(find.byKey(const Key('blender-line-fill-pressure')))
            .data,
        contains('150'),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('blender-line-computed-amount')))
            .data,
        contains('27.00'),
      );
      expect(find.byKey(const Key('blender-line-no-price')), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final fills = ref.read(blenderBilledFillsProvider);
      expect(fills, hasLength(1));
      expect(fills.single.total, closeTo(27, 1e-9));
      final line = fills.single.manualGasLine!;
      expect(line.role, BlenderGasRole.he);
      expect(line.gas, 'Helium');
      expect(line.addedBar, 150);
      expect(line.startBar, 50);
      expect(line.freeGasLiters, 1800);
      expect(line.cylinderLiters, 12);
      // No description typed: the label is generated from the fill.
      expect(fills.single.label, startsWith('Helium · 12'));
      expect(fills.single.label, endsWith('150.0 bar'));
    });

    testWidgets('a gas without a price is charged at 0, and the form says '
        'so (#2302)', (tester) async {
      final ref = await _pump(tester);
      await _openAddLine(tester);

      expect(find.byKey(const Key('blender-line-no-price')), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final fills = ref.read(blenderBilledFillsProvider);
      expect(fills, hasLength(1));
      expect(fills.single.total, 0);
      // Priced at zero, so the bill is complete rather than flagged.
      expect(totalOf(fills).complete, isTrue);
    });

    testWidgets('an end pressure not above the start pressure blocks saving '
        '(#2302)', (tester) async {
      final ref = await _pump(tester);
      await _openAddLine(tester);

      await tester.enterText(
        find.byKey(const Key('blender-line-start-pressure')),
        '200',
      );
      await tester.enterText(
        find.byKey(const Key('blender-line-end-pressure')),
        '100',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('end pressure must be above'), findsOneWidget);
      expect(ref.read(blenderBilledFillsProvider), isEmpty);
    });

    testWidgets('a cylinder preset sets the volume and the end pressure, '
        'which stays editable (#2302)', (tester) async {
      final ref = await _pump(
        tester,
        presets: [
          TankPresetEntity(
            id: 'd12',
            name: 'd12',
            displayName: 'D12 232',
            volumeLiters: 12,
            workingPressureBar: 232,
            material: TankMaterial.steel,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ],
      );
      ref.read(blenderGasPricesProvider.notifier).state = const [1.0, 1.5, 0.1];
      await _openAddLine(tester);

      await tester.tap(find.byKey(const Key('blender-line-cylinder-presets')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('D12 232').last);
      await tester.pumpAndSettle();

      String text(String key) =>
          tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
      expect(text('blender-line-cylinder'), '12');
      expect(text('blender-line-end-pressure'), '232');

      // Overridden by hand, e.g. for the oxygen step of a blend.
      await tester.enterText(
        find.byKey(const Key('blender-line-end-pressure')),
        '30',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final line = ref.read(blenderBilledFillsProvider).single.manualGasLine!;
      expect(line.role, BlenderGasRole.o2);
      expect(line.addedBar, 30);
      expect(line.cylinderLiters, 12);
    });

    testWidgets('re-editing a gas fill reopens it with its values and '
        'reprices it (#2302)', (tester) async {
      final ref = await _pump(tester);
      ref.read(blenderGasPricesProvider.notifier).state = const [1.0, 1.5, 0.1];
      ref.read(blenderBilledFillsProvider.notifier).state = const [
        BilledFill(
          id: 'a',
          label: 'Twinset',
          lines: [
            BilledGasLine(
              gas: 'Helium',
              addedBar: 150,
              cost: 27,
              freeGasLiters: 1800,
              cylinderLiters: 12,
              role: BlenderGasRole.he,
              startBar: 50,
            ),
          ],
          total: 27,
        ),
      ];
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Actions for Twinset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Twinset'));
      await tester.pumpAndSettle();

      String text(String key) =>
          tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
      expect(text('blender-line-description'), 'Twinset');
      expect(text('blender-line-cylinder'), '12');
      expect(text('blender-line-start-pressure'), '50');
      expect(text('blender-line-end-pressure'), '200');

      await tester.enterText(
        find.byKey(const Key('blender-line-end-pressure')),
        '150',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final fills = ref.read(blenderBilledFillsProvider);
      expect(fills, hasLength(1));
      expect(fills.single.label, 'Twinset');
      expect(fills.single.manualGasLine!.addedBar, 100);
      expect(fills.single.total, closeTo(18, 1e-9));
    });

    testWidgets('pressures are entered in the diver\'s unit and stored in '
        'bar (#2302)', (tester) async {
      final ref = await _pump(
        tester,
        settings: const AppSettings(
          defaultCurrency: 'CHF',
          pressureUnit: PressureUnit.psi,
        ),
      );
      ref.read(blenderGasPricesProvider.notifier).state = const [1.0, 1.5, 0.1];
      await _openAddLine(tester);

      expect(find.textContaining('Start pressure (psi)'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('blender-line-cylinder')),
        '10',
      );
      await tester.enterText(
        find.byKey(const Key('blender-line-start-pressure')),
        '0',
      );
      await tester.enterText(
        find.byKey(const Key('blender-line-end-pressure')),
        '3000',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final fill = ref.read(blenderBilledFillsProvider).single;
      const bar = 3000 / 14.5038;
      expect(fill.manualGasLine!.addedBar, closeTo(bar, 0.01));
      expect(fill.total, closeTo(10 * bar / 100, 0.01));
      expect(fill.label, endsWith('psi'));
    });

    testWidgets('reopening a gas fill to change only its description keeps '
        'what it was billed at (#2302 review)', (tester) async {
      final ref = await _pump(tester);
      // Priced since at a rate that would make this line 41.85.
      ref.read(blenderGasPricesProvider.notifier).state = const [1.0, 1.5, 0.1];
      ref.read(blenderBilledFillsProvider.notifier).state = const [
        BilledFill(
          id: 'a',
          label: 'Twinset',
          lines: [
            BilledGasLine(
              gas: 'Helium',
              addedBar: 232.5,
              cost: 27,
              freeGasLiters: 2790,
              cylinderLiters: 12,
              role: BlenderGasRole.he,
              startBar: 0,
            ),
          ],
          total: 27,
        ),
      ];
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Actions for Twinset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Twinset'));
      await tester.pumpAndSettle();

      // Not rounded to a whole number, so an untouched save cannot move it.
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('blender-line-end-pressure')),
            )
            .controller!
            .text,
        '232.5',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('blender-line-computed-amount')))
            .data,
        contains('27.00'),
      );

      await tester.enterText(
        find.byKey(const Key('blender-line-description')),
        'Doubles',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final fill = ref.read(blenderBilledFillsProvider).single;
      expect(fill.label, 'Doubles');
      expect(fill.total, 27);
      expect(fill.manualGasLine!.addedBar, 232.5);
      expect(fill.manualGasLine!.cost, 27);
    });

    testWidgets('switching a gas fill to a free amount starts from what it '
        'cost (#2302 review)', (tester) async {
      final ref = await _pump(tester);
      ref.read(blenderBilledFillsProvider.notifier).state = const [
        BilledFill(
          id: 'a',
          label: 'Twinset',
          lines: [
            BilledGasLine(
              gas: 'Helium',
              addedBar: 150,
              cost: 27,
              cylinderLiters: 12,
              role: BlenderGasRole.he,
              startBar: 50,
            ),
          ],
          total: 27,
        ),
      ];
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Actions for Twinset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Twinset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Free amount'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('blender-line-amount')))
            .controller!
            .text,
        '27',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final fill = ref.read(blenderBilledFillsProvider).single;
      expect(fill.isManual, isTrue);
      expect(fill.total, 27);
    });

    testWidgets('an empty pressure asks for one rather than blaming the '
        'order (#2302 review)', (tester) async {
      final ref = await _pump(tester);
      await _openAddLine(tester);

      await tester.enterText(
        find.byKey(const Key('blender-line-start-pressure')),
        '',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Enter a start and an end pressure'),
        findsOneWidget,
      );
      expect(ref.read(blenderBilledFillsProvider), isEmpty);
    });

    testWidgets('a preset picked in cubic feet bills its exact water volume '
        '(#2302 review)', (tester) async {
      final ref = await _pump(
        tester,
        settings: const AppSettings(
          defaultCurrency: 'CHF',
          volumeUnit: VolumeUnit.cubicFeet,
        ),
        presets: [
          TankPresetEntity(
            id: 'al80',
            name: 'al80',
            displayName: 'AL80',
            volumeLiters: 11.1,
            workingPressureBar: 207,
            material: TankMaterial.aluminum,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ],
      );
      await _openAddLine(tester);

      await tester.tap(find.byKey(const Key('blender-line-cylinder-presets')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('AL80').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final line = ref.read(blenderBilledFillsProvider).single.manualGasLine!;
      expect(line.cylinderLiters, 11.1);
      expect(line.addedBar, 207);
    });

    testWidgets('a generated label saved in bar still regenerates once the '
        'diver has switched to psi (#2302 review)', (tester) async {
      final ref = await _pump(
        tester,
        settings: const AppSettings(
          defaultCurrency: 'CHF',
          pressureUnit: PressureUnit.psi,
        ),
      );
      ref.read(blenderBilledFillsProvider.notifier).state = const [
        BilledFill(
          id: 'a',
          label: 'Helium · 12 L · 150.0 bar',
          lines: [
            BilledGasLine(
              gas: 'Helium',
              addedBar: 150,
              cost: 0,
              cylinderLiters: 12,
              role: BlenderGasRole.he,
              startBar: 0,
            ),
          ],
          total: 0,
        ),
      ];
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Actions for Helium · 12 L · 150.0 bar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Helium · 12 L · 150.0 bar'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('blender-line-description')),
            )
            .controller!
            .text,
        isEmpty,
      );
      await tester.enterText(
        find.byKey(const Key('blender-line-end-pressure')),
        '1000',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        ref.read(blenderBilledFillsProvider).single.label,
        endsWith('1000 psi'),
      );
    });

    testWidgets('switching a gas fill with a generated label to a free '
        'amount keeps its label (#2302 review)', (tester) async {
      final ref = await _pump(tester);
      ref.read(blenderBilledFillsProvider.notifier).state = const [
        BilledFill(
          id: 'a',
          label: 'Helium · 12 L · 150.0 bar',
          lines: [
            BilledGasLine(
              gas: 'Helium',
              addedBar: 150,
              cost: 27,
              cylinderLiters: 12,
              role: BlenderGasRole.he,
              startBar: 0,
            ),
          ],
          total: 27,
        ),
      ];
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Actions for Helium · 12 L · 150.0 bar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Helium · 12 L · 150.0 bar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Free amount'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final fill = ref.read(blenderBilledFillsProvider).single;
      expect(fill.label, 'Helium · 12 L · 150.0 bar');
      expect(fill.isManual, isTrue);
      expect(fill.total, 27);
    });

    testWidgets('editing only the pressure of a gas fill saved in cubic feet '
        'keeps its exact volume (#2302 review)', (tester) async {
      final ref = await _pump(
        tester,
        settings: const AppSettings(
          defaultCurrency: 'CHF',
          volumeUnit: VolumeUnit.cubicFeet,
        ),
      );
      ref.read(blenderBilledFillsProvider.notifier).state = const [
        BilledFill(
          id: 'a',
          label: 'AL80',
          lines: [
            BilledGasLine(
              gas: 'O₂',
              addedBar: 100,
              cost: 0,
              cylinderLiters: 11.1,
              role: BlenderGasRole.o2,
              startBar: 0,
            ),
          ],
          total: 0,
        ),
      ];
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Actions for AL80'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit AL80'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('blender-line-end-pressure')),
        '150',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final line = ref.read(blenderBilledFillsProvider).single.manualGasLine!;
      expect(line.addedBar, 150);
      expect(line.cylinderLiters, 11.1);
      expect(line.freeGasLiters, closeTo(1665, 1e-9));
    });

    testWidgets('saving an untouched gas fill after a unit change keeps its '
        'generated label as saved (#2302 review)', (tester) async {
      final ref = await _pump(
        tester,
        settings: const AppSettings(
          defaultCurrency: 'CHF',
          pressureUnit: PressureUnit.psi,
        ),
      );
      ref.read(blenderBilledFillsProvider.notifier).state = const [
        BilledFill(
          id: 'a',
          label: 'Helium · 12 L · 150.0 bar',
          lines: [
            BilledGasLine(
              gas: 'Helium',
              addedBar: 150,
              cost: 27,
              cylinderLiters: 12,
              role: BlenderGasRole.he,
              startBar: 0,
            ),
          ],
          total: 27,
        ),
      ];
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Actions for Helium · 12 L · 150.0 bar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Helium · 12 L · 150.0 bar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final fill = ref.read(blenderBilledFillsProvider).single;
      expect(fill.label, 'Helium · 12 L · 150.0 bar');
      expect(fill.total, 27);
    });

    testWidgets('a dot typed under a German locale is read as the decimal '
        'separator in every field of the line form (#2302 review)', (
      tester,
    ) async {
      // Under de, '.' is the grouping separator, but "12.5" cannot be a
      // well-formed grouping, so it unambiguously means 12,5 -- the same
      // correction the blender's other fields apply.
      final previousLocale = Intl.defaultLocale;
      Intl.defaultLocale = 'de';
      addTearDown(() => Intl.defaultLocale = previousLocale);
      final ref = await _pump(tester);
      ref.read(blenderGasPricesProvider.notifier).state = const [1.0, 1.5, 0.1];

      await _openAddLine(tester);
      await tester.enterText(
        find.byKey(const Key('blender-line-cylinder')),
        '12.5',
      );
      await tester.enterText(
        find.byKey(const Key('blender-line-start-pressure')),
        '0.5',
      );
      await tester.enterText(
        find.byKey(const Key('blender-line-end-pressure')),
        '200.5',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final line = ref.read(blenderBilledFillsProvider).single.manualGasLine!;
      expect(line.cylinderLiters, 12.5);
      expect(line.startBar, 0.5);
      expect(line.addedBar, 200);

      await _openAddLine(tester, freeAmount: true);
      await tester.enterText(
        find.byKey(const Key('blender-line-description')),
        'Analyser cell',
      );
      await tester.enterText(
        find.byKey(const Key('blender-line-amount')),
        '12.5',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(ref.read(blenderBilledFillsProvider).last.total, 12.5);
    });

    testWidgets('a fractional fill pressure is shown and labelled to the '
        'blender\'s tenth of a bar (#2302 review)', (tester) async {
      final ref = await _pump(tester);
      await _openAddLine(tester);
      await tester.enterText(
        find.byKey(const Key('blender-line-cylinder')),
        '12',
      );
      await tester.enterText(
        find.byKey(const Key('blender-line-start-pressure')),
        '50.25',
      );
      await tester.enterText(
        find.byKey(const Key('blender-line-end-pressure')),
        '200.75',
      );
      await tester.pumpAndSettle();

      // Rounded to whole bar this would read 151, a fill that was not made.
      expect(
        tester
            .widget<Text>(find.byKey(const Key('blender-line-fill-pressure')))
            .data,
        contains('150.5 bar'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final fill = ref.read(blenderBilledFillsProvider).single;
      expect(fill.manualGasLine!.addedBar, closeTo(150.5, 1e-9));
      expect(fill.label, endsWith('150.5 bar'));
    });

    testWidgets('a label generated under a comma-decimal locale still '
        'regenerates after the app language changes (#2302 review)', (
      tester,
    ) async {
      final previousLocale = Intl.defaultLocale;
      addTearDown(() => Intl.defaultLocale = previousLocale);
      Intl.defaultLocale = 'de';
      final ref = await _pump(tester);

      await _openAddLine(tester);
      await _pickGas(tester, 'Helium');
      await tester.enterText(
        find.byKey(const Key('blender-line-cylinder')),
        '12,5',
      );
      await tester.enterText(
        find.byKey(const Key('blender-line-start-pressure')),
        '0',
      );
      await tester.enterText(
        find.byKey(const Key('blender-line-end-pressure')),
        '150',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      final saved = ref.read(blenderBilledFillsProvider).single.label;
      expect(saved, 'Helium · 12,5 L · 150,0 bar');

      Intl.defaultLocale = 'en';
      await tester.tap(find.byTooltip('Actions for $saved'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit $saved'));
      await tester.pumpAndSettle();

      // Recognised as generated, so it is left blank to be regenerated.
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('blender-line-description')),
            )
            .controller!
            .text,
        isEmpty,
      );
      await tester.enterText(
        find.byKey(const Key('blender-line-end-pressure')),
        '200',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        ref.read(blenderBilledFillsProvider).single.label,
        'Helium · 12.5 L · 200.0 bar',
      );
    });

    testWidgets('a computed fill offers neither the kind switch nor the gas '
        'fields when re-edited', (tester) async {
      final ref = await _pump(tester);
      ref.read(blenderBilledFillsProvider.notifier).state = const [
        BilledFill(
          id: 'a',
          label: 'Tx 18/45',
          lines: [BilledGasLine(gas: 'O₂', addedBar: 10, cost: 10)],
          total: 10,
        ),
      ];
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Actions for Tx 18/45'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Tx 18/45'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('blender-line-kind')), findsNothing);
      expect(find.byKey(const Key('blender-line-cylinder')), findsNothing);
      expect(find.byKey(const Key('blender-line-amount')), findsOneWidget);

      // Saving keeps the itemisation it was computed with.
      await tester.enterText(find.byKey(const Key('blender-line-amount')), '9');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      final fill = ref.read(blenderBilledFillsProvider).single;
      expect(fill.lines, hasLength(1));
      expect(fill.total, 9);
    });

    testWidgets('paying asks first, then archives and empties the bill', (
      tester,
    ) async {
      final ref = await _pump(tester);
      ref.read(blenderBilledToProvider.notifier).state = 'Ada';
      ref.read(blenderBilledFillsProvider.notifier).state = const [
        BilledFill(id: 'a', label: 'Tx 18/45', lines: [], total: 35),
      ];
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('blender-pay')));
      await tester.pumpAndSettle();
      expect(find.textContaining('archives all 1'), findsOneWidget);
      expect(ref.read(blenderBilledFillsProvider), hasLength(1));

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Pay'),
        ),
      );
      await tester.pumpAndSettle();
      expect(ref.read(blenderBilledFillsProvider), isEmpty);

      final archived = ref.read(blenderArchivedInvoicesProvider);
      expect(archived, hasLength(1));
      expect(archived.single.billedTo, 'Ada');
      expect(archived.single.fills.single.label, 'Tx 18/45');
      expect(archived.single.total, 35);
      // Snapshotted from the currency configured at the moment of paying, so
      // a later change to the default currency cannot silently relabel an
      // already-paid total.
      expect(archived.single.currencyCode, 'CHF');
    });

    testWidgets(
      'paying archives the flush fee as a line, not only inside the total',
      (tester) async {
        // PR #1359 review: the fee was folded into the archived total while
        // the archived fills carried no line for it, so a paid invoice could
        // never be reconciled from its own itemisation.
        final ref = await _pump(tester);
        ref.read(blenderFlushFeeEnabledProvider.notifier).state = true;
        ref.read(blenderGasPricesProvider.notifier).state = const [
          7.5,
          15.0,
          1.0,
        ];
        ref.read(blenderBilledFillsProvider.notifier).state = const [
          BilledFill(id: 'a', label: 'Tx 18/45', lines: [], total: 35),
        ];
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('blender-pay')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, 'Pay'),
          ),
        );
        await tester.pumpAndSettle();

        final archived = ref.read(blenderArchivedInvoicesProvider).single;
        expect(archived.fills.map((f) => f.label), [
          'Tx 18/45',
          'O\u2082 hose purge',
          'Helium hose purge',
          'Topup hose purge',
        ]);
        // 35 + the three 20 L purges at 7.50, 15.00 and 1.00 per 100 L.
        expect(archived.total, closeTo(39.7, 1e-9));
        // The point of the fix: the stored lines add up to the stored total.
        expect(totalOf(archived.fills).amount, closeTo(archived.total!, 1e-9));
      },
    );

    testWidgets('an unpriced fill flags the total as incomplete', (
      tester,
    ) async {
      final ref = await _pump(tester);
      ref.read(blenderBilledFillsProvider.notifier).state = const [
        BilledFill(id: 'a', label: 'Tx 18/45', lines: [], total: 35),
        BilledFill(id: 'b', label: 'Tx 15/55', lines: [], total: null),
      ];
      await tester.pumpAndSettle();

      expect(find.textContaining('incomplete'), findsOneWidget);
    });

    testWidgets('the heading shows the invoice date, editable via the icon', (
      tester,
    ) async {
      final ref = await _pump(tester);
      final today = DateTime(2026, 3, 5);
      ref.read(blenderBilledDateProvider.notifier).state = today;
      await tester.pumpAndSettle();

      expect(find.textContaining('Mar 5, 2026'), findsOneWidget);
      expect(find.byKey(const Key('blender-billed-date-edit')), findsOneWidget);
    });

    testWidgets('a configured price shows up in the tariff summary', (
      tester,
    ) async {
      final ref = await _pump(tester);
      ref.read(blenderGasPricesProvider.notifier).state = const [
        1.2,
        null,
        null,
      ];
      await tester.pumpAndSettle();

      expect(find.text('Current tariff'), findsOneWidget);
      // The unit and currency sit once in the column header now, not
      // repeated after every priced gas.
      expect(find.textContaining('CHF/100L'), findsOneWidget);
      expect(find.text('1.20'), findsOneWidget);
      // Unpriced banks are left out rather than shown as a placeholder row.
      expect(find.textContaining('null'), findsNothing);
    });

    testWidgets('no tariff line is shown when nothing is priced', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.textContaining('Current tariff'), findsNothing);
    });

    testWidgets('a saved line with a volume shows litres, not pressure', (
      tester,
    ) async {
      final ref = await _pump(tester);
      ref.read(blenderBilledFillsProvider.notifier).state = const [
        BilledFill(
          id: 'a',
          label: 'Tx 18/45',
          lines: [
            BilledGasLine(gas: 'O₂', addedBar: 10, cost: 10, freeGasLiters: 30),
          ],
          total: 10,
        ),
      ];
      await tester.pumpAndSettle();

      // The unit sits in the column header now, not repeated per cell.
      expect(find.text('30'), findsOneWidget);
    });

    testWidgets(
      'a saved line shows the cylinder size it was filled into, with a '
      'header for the column',
      (tester) async {
        final ref = await _pump(tester);
        ref.read(blenderBilledFillsProvider.notifier).state = const [
          BilledFill(
            id: 'a',
            label: 'Tx 18/45',
            lines: [
              BilledGasLine(
                gas: 'O₂',
                addedBar: 10,
                cost: 10,
                freeGasLiters: 30,
                // Distinct from the default cylinder-volume field's value,
                // so this assertion cannot pass by matching that field.
                cylinderLiters: 15,
              ),
            ],
            total: 10,
          ),
        ];
        await tester.pumpAndSettle();

        expect(find.text('15'), findsOneWidget);
      },
    );

    testWidgets(
      'a line saved before #1876 shows a dash for the cylinder size, not '
      'a crash or a guessed value',
      (tester) async {
        final ref = await _pump(tester);
        ref.read(blenderBilledFillsProvider.notifier).state = const [
          BilledFill(
            id: 'a',
            label: 'Tx 18/45',
            lines: [
              BilledGasLine(
                gas: 'O₂',
                addedBar: 10,
                cost: 10,
                freeGasLiters: 30,
              ),
            ],
            total: 10,
          ),
        ];
        await tester.pumpAndSettle();

        expect(find.text('—'), findsOneWidget);
      },
    );

    testWidgets('an older line with no volume falls back to pressure', (
      tester,
    ) async {
      final ref = await _pump(tester);
      ref.read(blenderBilledFillsProvider.notifier).state = const [
        BilledFill(
          id: 'a',
          label: 'Tx 18/45',
          lines: [BilledGasLine(gas: 'O₂', addedBar: 10, cost: 10)],
          total: 10,
        ),
      ];
      await tester.pumpAndSettle();

      expect(find.textContaining('bar'), findsWidgets);
    });

    testWidgets('export and pay only appear once something is billed', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byKey(const Key('blender-export')), findsNothing);
      expect(find.byKey(const Key('blender-pay')), findsNothing);
    });
  });

  group('export', () {
    late Directory documents;
    final platform = _FakeSharePlatform();

    setUpAll(() => SharePlatform.instance = platform);

    setUp(() {
      documents = Directory.systemTemp.createTempSync('blender_invoice_test');
      PathProviderPlatform.instance = _FakePathProvider(documents.path);
      platform.calls.clear();
    });

    tearDown(() => documents.deleteSync(recursive: true));

    /// Fills the running bill with one manual line so the export button is
    /// on screen, then opens the export picker.
    Future<void> addLineAndOpenPicker(WidgetTester tester) async {
      await _pump(tester);
      await _openAddLine(tester, freeAmount: true);
      await tester.enterText(
        find.byKey(const Key('blender-line-description')),
        'Analyser cell',
      );
      await tester.enterText(
        find.byKey(const Key('blender-line-amount')),
        '12.50',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('blender-export')));
      await tester.pumpAndSettle();
    }

    /// A bounded pump loop rather than [WidgetTester.pumpAndSettle]: the
    /// export button shows a [CircularProgressIndicator] while its future is
    /// in flight, and that ticks forever, so `pumpAndSettle` never sees "no
    /// more frames scheduled" and times out even once the real work
    /// underneath is done. Runs inside [WidgetTester.runAsync] so the real
    /// file I/O and PDF/Excel encoding behind the export actually get to
    /// complete - plain `pump()` only flushes work already done, it does not
    /// wait for it.
    ///
    /// Pumps with an explicit duration, not a bare `pump()`: `_runExport`
    /// (issue #44 follow-up) waits out a real `Future.delayed` before it
    /// shares, to give the OS window back its focus after the export picker
    /// closes, and that delayed Future is bound to the test binding's fake
    /// clock rather than wall time. A bare `pump()` never advances that
    /// clock, so the delay would only resolve once enough zero-duration
    /// pumps happened to accumulate the needed time - here, driven straight
    /// off the elapsed real time, it resolves in step with it.
    Future<void> settleWithLoadingIndicator(WidgetTester tester) async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('tapping PDF shares a PDF', (tester) async {
      await addLineAndOpenPicker(tester);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('blender-export-pdf')));
        await settleWithLoadingIndicator(tester);
      });
      await tester.pumpAndSettle();

      expect(platform.calls, hasLength(1));
      expect(platform.calls.single.files!.single.mimeType, 'application/pdf');
    });

    testWidgets('tapping Excel shares a spreadsheet', (tester) async {
      await addLineAndOpenPicker(tester);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('blender-export-excel')));
        await settleWithLoadingIndicator(tester);
      });
      await tester.pumpAndSettle();

      expect(platform.calls, hasLength(1));
      expect(
        platform.calls.single.files!.single.mimeType,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    });

    testWidgets('an exported invoice itemises the flush fee it charges for', (
      tester,
    ) async {
      // PR #1359 review: the export took its total from a flush-inclusive
      // sum but its lines from the fills alone, so a shared invoice listed
      // less than it charged.
      final ref = await _pump(tester);
      ref.read(blenderFlushFeeEnabledProvider.notifier).state = true;
      ref.read(blenderGasPricesProvider.notifier).state = const [
        7.5,
        15.0,
        1.0,
      ];
      ref.read(blenderBilledFillsProvider.notifier).state = const [
        BilledFill(id: 'a', label: 'Tx 18/45', lines: [], total: 35),
      ];
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('blender-export')));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('blender-export-excel')));
        await settleWithLoadingIndicator(tester);
      });
      await tester.pumpAndSettle();

      final shared = File(platform.calls.single.files!.single.path);
      final sheet = xl.Excel.decodeBytes(shared.readAsBytesSync())['Invoice'];
      String? cell(int row, int col) {
        final value = sheet.rows[row][col]?.value;
        return value is xl.TextCellValue ? value.value.toString() : null;
      }

      // Row 4 is the column header; the fill leads, then one row per purge.
      expect(cell(5, 0), 'Tx 18/45');
      expect(cell(6, 0), 'O\u2082 hose purge');
      expect(cell(7, 0), 'Helium hose purge');
      expect(cell(8, 0), 'Topup hose purge');
      // And the grand total is the sum of exactly those four rows.
      expect(
        sheet.rows.any(
          (row) => row.any(
            (c) =>
                c?.value is xl.TextCellValue &&
                (c!.value as xl.TextCellValue).value.toString().contains(
                  '39.70',
                ),
          ),
        ),
        isTrue,
      );
    });

    testWidgets('tapping Image captures the boundary and shares a PNG', (
      tester,
    ) async {
      await addLineAndOpenPicker(tester);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('blender-export-image')));
        await settleWithLoadingIndicator(tester);
      });
      await tester.pumpAndSettle();

      expect(platform.calls, hasLength(1));
      expect(platform.calls.single.files!.single.mimeType, 'image/png');
    });

    testWidgets(
      'the picker closes and the export button starts spinning before '
      'anything is shared',
      (tester) async {
        // Regression test for issue #44: the OS share sheet used to be
        // invoked only after `action(anchor)` resolved, with the picker
        // popped afterwards - so sharing raced the picker's own dismissal.
        // Now the tile pops the picker synchronously on tap, before any
        // export work starts, so by the very next frame the export button
        // is already spinning (proof the picker's future already resolved)
        // while nothing has been shared yet.
        await addLineAndOpenPicker(tester);

        await tester.runAsync(() async {
          await tester.tap(find.byKey(const Key('blender-export-pdf')));
          await tester.pump();

          expect(
            find.descendant(
              of: find.byKey(const Key('blender-export')),
              matching: find.byType(CircularProgressIndicator),
            ),
            findsOneWidget,
          );
          expect(platform.calls, isEmpty);

          await settleWithLoadingIndicator(tester);
        });
        await tester.pumpAndSettle();

        expect(find.byType(BlenderInvoiceExportSheet), findsNothing);

        expect(platform.calls, hasLength(1));
      },
    );
  });

  group('review findings', () {
    test('an amount can be cleared on an edited line', () {
      // Raised in review on PR #1215. Null marks a line as not yet priced,
      // which is what makes the grand total report itself incomplete, so
      // copyWith has to be able to express it.
      const fill = BilledFill(id: 'a', label: 'Tx 18/45', lines: [], total: 35);
      expect(fill.copyWith(label: 'x').total, 35);
      expect(fill.copyWith(clearTotal: true).total, isNull);
      expect(fill.copyWith(total: 40.0).total, 40.0);
    });

    test('appending past the cap drops the oldest, not the newest', () {
      var fills = <BilledFill>[];
      for (var i = 0; i < kMaxBilledFills + 5; i++) {
        fills = appendCapped(
          fills,
          BilledFill(id: '$i', label: 'fill $i', lines: const [], total: 1),
        );
      }
      expect(fills, hasLength(kMaxBilledFills));
      expect(fills.last.label, 'fill ${kMaxBilledFills + 4}');
      expect(fills.first.label, 'fill 5');
    });
  });

  group('flush fee', () {
    testWidgets('is off by default', (tester) async {
      await _pump(tester);
      expect(
        find.byKey(const Key('blender-flush-fee-liters-o2')),
        findsNothing,
      );
    });

    testWidgets(
      'once enabled and priced, a bill-once line appears even with nothing filled yet',
      (tester) async {
        final ref = await _pump(tester);
        await tester.tap(find.byKey(const Key('blender-flush-fee-enabled')));
        await tester.pumpAndSettle();
        // Issue #42: the flush fee's price is no longer entered here -- it
        // is read from the same role-keyed price used to cost a fill.
        ref.read(blenderGasPricesProvider.notifier).state = const [
          7.5,
          null,
          null,
        ];
        await tester.pumpAndSettle();

        // The default purge volume is 20 L, so 20 / 100 * 7.5 = 1.50.
        expect(
          find.byKey(const Key('blender-flush-fee-liters-o2')),
          findsOneWidget,
        );
        expect(find.textContaining('1.50'), findsWidgets);
      },
    );

    testWidgets('per-fill mode charges nothing until a fill is saved', (
      tester,
    ) async {
      final ref = await _pump(tester);
      ref.read(blenderFlushFeeEnabledProvider.notifier).state = true;
      ref.read(blenderFlushFeeModeProvider.notifier).state =
          FlushFeeMode.perFill;
      ref.read(blenderGasPricesProvider.notifier).state = const [
        7.5,
        null,
        null,
      ];
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('blender-flush-fee-liters-o2')),
        findsNothing,
      );

      ref.read(blenderBilledFillsProvider.notifier).state = const [
        BilledFill(id: 'a', label: 'Tx 18/45', lines: [], total: 35),
      ];
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('blender-flush-fee-liters-o2')),
        findsOneWidget,
      );
      expect(find.textContaining('1.50'), findsWidgets);
    });

    testWidgets(
      'changing the purge volume setting re-prices the invoice line',
      (tester) async {
        // Issue #42 follow-up: the invoice line's volume is read-only,
        // sourced from the same setting the Fill gases settings card's
        // field writes to (blender-flush-fee-volume-o2, on
        // BlenderSettingsPage), not a second entry point.
        final ref = await _pump(tester);
        ref.read(blenderFlushFeeEnabledProvider.notifier).state = true;
        ref.read(blenderGasPricesProvider.notifier).state = const [
          7.5,
          null,
          null,
        ];
        await tester.pumpAndSettle();

        ref.read(blenderFlushFeeGasesProvider.notifier).state = const [
          FlushFeeGasSetting(volumeLiters: 40),
          FlushFeeGasSetting(volumeLiters: 20),
          FlushFeeGasSetting(volumeLiters: 20),
        ];
        await tester.pumpAndSettle();

        // 40 / 100 * 7.5 = 3.00.
        expect(find.textContaining('3.00'), findsWidgets);
      },
    );

    testWidgets('the invoice line shows the purge volume as read-only text', (
      tester,
    ) async {
      final ref = await _pump(tester);
      ref.read(blenderFlushFeeEnabledProvider.notifier).state = true;
      ref.read(blenderGasPricesProvider.notifier).state = const [
        7.5,
        null,
        null,
      ];
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('blender-flush-fee-liters-o2')),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('blender-flush-fee-liters-o2')),
          matching: find.byType(InputDecorator),
        ),
        findsNothing,
      );
      expect(find.textContaining('20'), findsWidgets);
    });
  });
}
