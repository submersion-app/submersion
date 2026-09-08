import 'dart:convert';
import 'dart:io';

import 'package:excel_community/excel_community.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/blending/flush_fee.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_billing_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_invoice_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_invoice_export_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
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

Future<WidgetRef> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(900, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) =>
              _TestSettingsNotifier(const AppSettings(defaultCurrency: 'CHF')),
        ),
        tankPresetsProvider.overrideWith((ref) async => const []),
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
          BilledGasLine(gas: 'O₂', addedBar: 10, cost: 10, freeGasLiters: 30),
          BilledGasLine(gas: 'He', addedBar: 80, cost: 20, freeGasLiters: 240),
        ],
        total: 35,
      );
      final decoded = BilledFill.fromJson(
        jsonDecode(jsonEncode(fill.toJson())) as Map<String, dynamic>,
      )!;
      expect(decoded.label, 'Tx 18/45');
      expect(decoded.lines, hasLength(2));
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

    test('a manual line has no itemisation', () {
      const fill = BilledFill(
        id: 'b',
        label: 'Analyser cell',
        lines: [],
        total: 40,
      );
      expect(fill.isManual, isTrue);
    });

    test('a custom mix round-trips through JSON alongside the fill', () {
      const fill = BilledFill(
        id: 'c',
        label: 'Tx 21/35',
        lines: [],
        total: 40,
        customMix: BilledCustomMix(cylinderLiters: 11.1, o2: 21, he: 35),
      );
      final decoded = BilledFill.fromJson(
        jsonDecode(jsonEncode(fill.toJson())) as Map<String, dynamic>,
      )!;
      expect(decoded.customMix, isNotNull);
      expect(decoded.customMix!.cylinderLiters, 11.1);
      expect(decoded.customMix!.o2, 21);
      expect(decoded.customMix!.he, 35);
    });

    test('a fill without a custom mix decodes with none', () {
      const fill = BilledFill(id: 'd', label: 'x', lines: [], total: 1);
      final decoded = BilledFill.fromJson(
        jsonDecode(jsonEncode(fill.toJson())) as Map<String, dynamic>,
      )!;
      expect(decoded.customMix, isNull);
    });

    test('copyWith can clear a custom mix', () {
      const fill = BilledFill(
        id: 'e',
        label: 'Tx 21/35',
        lines: [],
        total: 40,
        customMix: BilledCustomMix(cylinderLiters: 11.1, o2: 21, he: 35),
      );
      expect(fill.copyWith(label: 'x').customMix, isNotNull);
      expect(fill.copyWith(clearCustomMix: true).customMix, isNull);
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

      await tester.tap(find.byTooltip('Delete Tx 18/45'));
      await tester.pumpAndSettle();

      expect(ref.read(blenderBilledFillsProvider), isEmpty);
    });

    testWidgets('a manual line can be added', (tester) async {
      final ref = await _pump(tester);
      await tester.tap(find.byKey(const Key('blender-add-manual-line')));
      await tester.pumpAndSettle();

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

    testWidgets('saving a line with nothing to name it says so', (
      tester,
    ) async {
      // PR #1359 review: with no description and no usable mix there was
      // nothing to label the line with, and Save simply returned - no line,
      // no message, a button that reads as broken.
      await _pump(tester);
      await tester.tap(find.byKey(const Key('blender-add-manual-line')));
      await tester.pumpAndSettle();
      // The mix fields are pre-filled, so the label can fall back to them
      // until one of them is cleared.
      await tester.enterText(find.widgetWithText(TextField, 'O\u2082 (%)'), '');
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
    });

    testWidgets('a custom mix line records the cylinder and gas entered', (
      tester,
    ) async {
      final ref = await _pump(tester);
      await tester.tap(find.byKey(const Key('blender-add-manual-line')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('blender-line-cylinder')),
        '11.1',
      );
      await tester.enterText(
        find.byKey(const Key('blender-line-amount')),
        '30',
      );
      // Description left blank on purpose: the label falls back to the mix.
      await tester.enterText(find.widgetWithText(TextField, 'O₂ (%)'), '21');
      await tester.enterText(find.widgetWithText(TextField, 'He (%)'), '35');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final fills = ref.read(blenderBilledFillsProvider);
      expect(fills, hasLength(1));
      expect(fills.single.label, 'Tx 21/35');
      expect(fills.single.customMix, isNotNull);
      expect(fills.single.customMix!.cylinderLiters, closeTo(11.1, 0.001));
      expect(fills.single.customMix!.o2, 21);
      expect(fills.single.customMix!.he, 35);
    });

    testWidgets('re-editing a manual line pre-fills its saved mix', (
      tester,
    ) async {
      final ref = await _pump(tester);
      ref.read(blenderBilledFillsProvider.notifier).state = const [
        BilledFill(
          id: 'a',
          label: 'Tx 21/35',
          lines: [],
          total: 30,
          customMix: BilledCustomMix(cylinderLiters: 11.1, o2: 21, he: 35),
        ),
      ];
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit Tx 21/35'));
      await tester.pumpAndSettle();

      final o2Field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'O₂ (%)'),
      );
      expect(o2Field.controller!.text, '21');
      final heField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'He (%)'),
      );
      expect(heField.controller!.text, '35');

      // Changing the mix and saving updates the stored fill rather than
      // adding a second one.
      await tester.enterText(find.widgetWithText(TextField, 'He (%)'), '45');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final fills = ref.read(blenderBilledFillsProvider);
      expect(fills, hasLength(1));
      expect(fills.single.customMix!.he, 45);
    });

    testWidgets('a computed fill offers no mix fields when re-edited', (
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

      await tester.tap(find.byTooltip('Edit Tx 18/45'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('blender-line-cylinder')), findsNothing);
      expect(find.widgetWithText(TextField, 'O₂ (%)'), findsNothing);
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

      expect(find.textContaining('Current tariff'), findsOneWidget);
      expect(find.textContaining('1.20/100L'), findsOneWidget);
      // Unpriced banks are left out rather than shown as a placeholder.
      final tariffLine = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data?.contains('Current tariff') ?? false)
          .single;
      expect(tariffLine.data, isNot(contains('null')));
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

      expect(find.textContaining('30 L'), findsOneWidget);
    });

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
      await tester.tap(find.byKey(const Key('blender-add-manual-line')));
      await tester.pumpAndSettle();
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
