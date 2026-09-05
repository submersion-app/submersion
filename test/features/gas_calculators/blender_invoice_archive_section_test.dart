import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_invoice_archive_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';

ArchivedInvoice _invoice({
  required String id,
  required DateTime date,
  String billedTo = '',
  double? total = 35,
}) => ArchivedInvoice(
  id: id,
  date: date,
  billedTo: billedTo,
  fills: const [BilledFill(id: 'f', label: 'Tx 18/45', lines: [], total: 35)],
  total: total,
);

Future<WidgetRef> _pump(WidgetTester tester) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        settingsProvider.overrideWith(
          (ref) =>
              MockSettingsNotifier(const AppSettings(defaultCurrency: 'CHF')),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          captured = ref;
          return const BlenderInvoiceArchiveSection();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

Future<void> _expand(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('blender-invoice-archive-section-toggle')),
  );
  await tester.pumpAndSettle();
}

Future<void> _pickYear(WidgetTester tester, String label) async {
  await tester.tap(
    find.byKey(const Key('blender-invoice-archive-section-year')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _pickMonth(WidgetTester tester, String label) async {
  await tester.tap(
    find.byKey(const Key('blender-invoice-archive-section-month')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// The total row's text, scoped to `BlenderArchiveTotalsSummary` - a per-line
/// invoice can show the same amount as the (single-invoice) filtered total,
/// so a bare `find.text` would match both.
Finder _totalText(String text) => find.descendant(
  of: find.byKey(const Key('blender-archive-totals-summary')),
  matching: find.text(text),
);

void main() {
  group('BlenderInvoiceArchiveSection', () {
    testWidgets('renders nothing when nothing has been paid yet', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('is collapsed by default, hiding the invoice list', (
      tester,
    ) async {
      final ref = await _pump(tester);
      ref.read(blenderArchivedInvoicesProvider.notifier).state = [
        _invoice(id: 'a', date: DateTime(2026, 3, 5), billedTo: 'Ada'),
      ];
      await tester.pumpAndSettle();

      expect(find.text('Ada'), findsNothing);

      await _expand(tester);
      expect(find.text('Ada'), findsOneWidget);
    });

    testWidgets(
      'defaults to the newest year and month, with a total for just that '
      'month',
      (tester) async {
        final ref = await _pump(tester);
        ref.read(blenderArchivedInvoicesProvider.notifier).state = [
          _invoice(
            id: 'a',
            date: DateTime(2026, 1, 10),
            billedTo: 'Ada',
            total: 10,
          ),
          _invoice(
            id: 'b',
            date: DateTime(2026, 3, 5),
            billedTo: 'Bob',
            total: 25,
          ),
        ];
        await tester.pumpAndSettle();
        await _expand(tester);

        // Newest month (March) is preselected, so only that invoice shows.
        expect(find.text('Bob'), findsOneWidget);
        expect(find.text('Ada'), findsNothing);
        expect(find.text('2026'), findsOneWidget);
        expect(find.text('March'), findsOneWidget);
        expect(_totalText(formatMoney(25, 'CHF')), findsOneWidget);
      },
    );

    testWidgets(
      'picking a year narrows the month options to that year, defaulting '
      'back to its newest month',
      (tester) async {
        final ref = await _pump(tester);
        ref.read(blenderArchivedInvoicesProvider.notifier).state = [
          _invoice(
            id: 'a',
            date: DateTime(2025, 12, 1),
            billedTo: 'Old',
            total: 20,
          ),
          _invoice(
            id: 'b',
            date: DateTime(2026, 1, 5),
            billedTo: 'New',
            total: 15,
          ),
        ];
        await tester.pumpAndSettle();
        await _expand(tester);

        expect(find.text('New'), findsOneWidget);
        expect(find.text('Old'), findsNothing);

        await _pickYear(tester, '2025');

        expect(find.text('Old'), findsOneWidget);
        expect(find.text('New'), findsNothing);
        expect(find.text('December'), findsOneWidget);
        expect(_totalText(formatMoney(20, 'CHF')), findsOneWidget);
      },
    );

    testWidgets(
      'picking "all years" shows every invoice, defaults the month filter '
      'to "all months", and totals the whole archive',
      (tester) async {
        final ref = await _pump(tester);
        ref.read(blenderArchivedInvoicesProvider.notifier).state = [
          _invoice(
            id: 'a',
            date: DateTime(2025, 12, 1),
            billedTo: 'Old',
            total: 20,
          ),
          _invoice(
            id: 'b',
            date: DateTime(2026, 1, 5),
            billedTo: 'New',
            total: 15,
          ),
        ];
        await tester.pumpAndSettle();
        await _expand(tester);

        await _pickYear(tester, 'All years');

        expect(find.text('Old'), findsOneWidget);
        expect(find.text('New'), findsOneWidget);
        expect(find.text('All months'), findsOneWidget);
        expect(_totalText(formatMoney(35, 'CHF')), findsOneWidget);
      },
    );

    testWidgets(
      'picking a month under "all years" narrows the list to that month '
      'across every year',
      (tester) async {
        final ref = await _pump(tester);
        ref.read(blenderArchivedInvoicesProvider.notifier).state = [
          _invoice(
            id: 'a',
            date: DateTime(2025, 12, 1),
            billedTo: 'Old',
            total: 20,
          ),
          _invoice(
            id: 'b',
            date: DateTime(2026, 1, 5),
            billedTo: 'New',
            total: 15,
          ),
        ];
        await tester.pumpAndSettle();
        await _expand(tester);
        await _pickYear(tester, 'All years');
        await _pickMonth(tester, 'December');

        expect(find.text('Old'), findsOneWidget);
        expect(find.text('New'), findsNothing);
        expect(_totalText(formatMoney(20, 'CHF')), findsOneWidget);
      },
    );

    testWidgets('tapping an invoice opens its detail route', (tester) async {
      final router = GoRouter(
        initialLocation: '/planning/gas-calculators/blender',
        routes: [
          GoRoute(
            path: '/planning/gas-calculators/blender',
            builder: (context, state) =>
                const Scaffold(body: BlenderInvoiceArchiveSection()),
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
      await _expand(tester);

      await tester.tap(find.text('Ada'));
      await tester.pumpAndSettle();

      expect(find.text('detail-inv-1'), findsOneWidget);
    });
  });
}
