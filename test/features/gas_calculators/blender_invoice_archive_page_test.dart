import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/features/gas_calculators/presentation/pages/blender_invoice_archive_page.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_invoice_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';
import '../../support/fake_app_settings_repository.dart';

ArchivedInvoice _invoice({
  required String id,
  required DateTime date,
  String billedTo = '',
  double? total = 35,
  String? currencyCode,
}) => ArchivedInvoice(
  id: id,
  date: date,
  billedTo: billedTo,
  fills: const [BilledFill(id: 'f', label: 'Tx 18/45', lines: [], total: 35)],
  total: total,
  currencyCode: currencyCode,
);

/// Pumps the archive page and hands back the [WidgetRef] so a test can push
/// invoices into [blenderArchivedInvoicesProvider] or drive the filter after
/// the first frame, matching [blender_invoice_test.dart]'s `_pump` shape.
Future<WidgetRef> _pump(WidgetTester tester) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) =>
              MockSettingsNotifier(const AppSettings(defaultCurrency: 'CHF')),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return const BlenderInvoiceArchivePage();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  group('BlenderInvoiceArchivePage', () {
    testWidgets('shows the empty state when nothing has been paid yet', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.textContaining('No paid invoices yet'), findsOneWidget);
    });

    testWidgets('lists invoices newest first with a fill count and total', (
      tester,
    ) async {
      final ref = await _pump(tester);
      ref.read(blenderArchivedInvoicesProvider.notifier).state = [
        _invoice(id: 'a', date: DateTime(2026, 1, 1), billedTo: 'Ada'),
        _invoice(id: 'b', date: DateTime(2026, 3, 5), billedTo: 'Ben'),
      ];
      await tester.pumpAndSettle();

      final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect(tiles, hasLength(2));
      // Newest (Ben, March) first.
      expect((tiles[0].title as Text).data, 'Ben');
      expect((tiles[1].title as Text).data, 'Ada');
      expect(find.textContaining('1 fills'), findsNWidgets(2));
    });

    testWidgets('an invoice with no billedTo falls back to "Untitled"', (
      tester,
    ) async {
      final ref = await _pump(tester);
      ref.read(blenderArchivedInvoicesProvider.notifier).state = [
        _invoice(id: 'a', date: DateTime(2026, 1, 1)),
      ];
      await tester.pumpAndSettle();

      expect(find.text('Untitled'), findsOneWidget);
    });

    testWidgets('an unpriced invoice shows Incomplete instead of an amount', (
      tester,
    ) async {
      final ref = await _pump(tester);
      ref.read(blenderArchivedInvoicesProvider.notifier).state = [
        _invoice(id: 'a', date: DateTime(2026, 1, 1), total: null),
      ];
      await tester.pumpAndSettle();

      expect(find.text('Incomplete'), findsOneWidget);
    });

    testWidgets(
      'the total is summed from the invoices actually shown, per currency, '
      'falling back to the current currency for a row saved before the '
      'snapshot existed',
      (tester) async {
        final ref = await _pump(tester);
        ref.read(blenderArchivedInvoicesProvider.notifier).state = [
          _invoice(
            id: 'a',
            date: DateTime(2026, 1, 1),
            total: 10,
            currencyCode: 'CHF',
          ),
          // No currencyCode: archived before #1335's snapshot, falls back to
          // the currently configured currency (also CHF here).
          _invoice(id: 'b', date: DateTime(2026, 1, 2), total: 5),
        ];
        await tester.pumpAndSettle();

        expect(find.textContaining('15'), findsOneWidget);
      },
    );

    testWidgets(
      'a date filter narrows the list, and its chip clears it again',
      (tester) async {
        final ref = await _pump(tester);
        ref.read(blenderArchivedInvoicesProvider.notifier).state = [
          _invoice(id: 'jan', date: DateTime(2026, 1, 1), billedTo: 'January'),
          _invoice(id: 'jul', date: DateTime(2026, 7, 1), billedTo: 'July'),
        ];
        ref
            .read(blenderInvoiceArchiveFilterProvider.notifier)
            .state = DateTimeRange(
          start: DateTime(2026, 6, 1),
          end: DateTime(2026, 8, 1),
        );
        await tester.pumpAndSettle();

        expect(find.text('July'), findsOneWidget);
        expect(find.text('January'), findsNothing);
        expect(find.byType(Chip), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(ref.read(blenderInvoiceArchiveFilterProvider), isNull);
        expect(find.text('January'), findsOneWidget);
        expect(find.text('July'), findsOneWidget);
      },
    );

    testWidgets('filtering to nothing shows the filtered empty state, not the '
        'general one', (tester) async {
      final ref = await _pump(tester);
      ref.read(blenderArchivedInvoicesProvider.notifier).state = [
        _invoice(id: 'jan', date: DateTime(2026, 1, 1)),
      ];
      ref.read(blenderInvoiceArchiveFilterProvider.notifier).state =
          DateTimeRange(start: DateTime(2026, 6, 1), end: DateTime(2026, 8, 1));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No invoices in this date range'),
        findsOneWidget,
      );
      expect(find.textContaining('No paid invoices yet'), findsNothing);
    });

    testWidgets('tapping an invoice opens its detail route', (tester) async {
      final router = GoRouter(
        initialLocation: kBlenderInvoiceArchiveRoute,
        routes: [
          GoRoute(
            path: kBlenderInvoiceArchiveRoute,
            builder: (context, state) => const BlenderInvoiceArchivePage(),
          ),
          GoRoute(
            path: '$kBlenderInvoiceArchiveRoute/:invoiceId',
            builder: (context, state) => Scaffold(
              body: Text('detail-${state.pathParameters['invoiceId']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        testAppRouter(
          router: router,
          overrides: [
            settingsProvider.overrideWith(
              (ref) => MockSettingsNotifier(
                const AppSettings(defaultCurrency: 'CHF'),
              ),
            ),
            blenderArchivedInvoicesProvider.overrideWith(
              (ref) => [
                _invoice(
                  id: 'inv-1',
                  date: DateTime(2026, 1, 1),
                  billedTo: 'Ada',
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ada'));
      await tester.pumpAndSettle();

      expect(find.text('detail-inv-1'), findsOneWidget);
    });
  });

  group('BlenderInvoiceCard entry point', () {
    testWidgets('the history icon navigates to the invoice archive', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/planning/gas-calculators/blender',
        routes: [
          GoRoute(
            path: '/planning/gas-calculators/blender',
            builder: (context, state) =>
                const Scaffold(body: BlenderInvoiceCard()),
          ),
          GoRoute(
            path: kBlenderInvoiceArchiveRoute,
            builder: (context, state) =>
                const Scaffold(body: Text('archive-reached')),
          ),
        ],
      );

      await tester.pumpWidget(
        testAppRouter(
          router: router,
          overrides: [
            settingsProvider.overrideWith(
              (ref) => MockSettingsNotifier(
                const AppSettings(defaultCurrency: 'CHF'),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('blender-invoice-archive')));
      await tester.pumpAndSettle();

      expect(find.text('archive-reached'), findsOneWidget);
    });
  });

  group('reached without the calculator', () {
    /// The archive route is a page of its own: a deep link, a restored route
    /// or the Settings entry can all reach it without GasBlenderCalculator
    /// ever mounting, and that calculator used to be the only thing that ran
    /// blenderPreferencesLoaderProvider (PR #1359 review).
    Future<void> pumpAlone(
      WidgetTester tester,
      FakeAppSettingsRepository repository,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => MockSettingsNotifier(
                const AppSettings(defaultCurrency: 'CHF'),
              ),
            ),
            appSettingsRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlenderInvoiceArchivePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('loads the stored invoices instead of showing empty', (
      tester,
    ) async {
      final repository = FakeAppSettingsRepository()
        ..blenderPreferences = _storedPreferences([
          _invoice(id: 'inv-1', date: DateTime(2026, 3, 5), billedTo: 'Ada'),
        ]);

      await pumpAlone(tester, repository);

      expect(find.text('Ada'), findsOneWidget);
      expect(find.textContaining('No paid invoices'), findsNothing);
    });

    testWidgets('still says so when nothing has been archived', (tester) async {
      final repository = FakeAppSettingsRepository()
        ..blenderPreferences = _storedPreferences(const []);

      await pumpAlone(tester, repository);

      expect(find.textContaining('No paid invoices'), findsOneWidget);
    });
  });
}

/// Preferences whose only interesting content is [archived], so a test can
/// tell "loaded from storage" apart from "left at the provider default".
BlenderPreferences _storedPreferences(List<ArchivedInvoice> archived) =>
    BlenderPreferences(
      templates: const [],
      gasPrices: const [null, null, null],
      fillTempC: kReferenceTempC,
      settledTempC: kReferenceTempC,
      cylinderWaterLiters: 12,
      model: BlendGasModel.zFactor,
      billedFills: const [],
      billedTo: '',
      startPressureBar: 0,
      startMix: const GasMix(o2: 21),
      targetPressureBar: 200,
      targetMix: const GasMix(o2: 32),
      topupO2Percent: 21,
      archivedInvoices: archived,
    );
