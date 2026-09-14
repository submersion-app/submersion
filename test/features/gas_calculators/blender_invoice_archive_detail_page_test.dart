import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/presentation/pages/blender_invoice_archive_detail_page.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';

import '../../helpers/mock_providers.dart';
import '../../support/fake_app_settings_repository.dart';

Future<void> _pump(
  WidgetTester tester, {
  required String invoiceId,
  List<ArchivedInvoice> invoices = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) =>
              MockSettingsNotifier(const AppSettings(defaultCurrency: 'CHF')),
        ),
        blenderArchivedInvoicesProvider.overrideWith((ref) => invoices),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlenderInvoiceArchiveDetailPage(invoiceId: invoiceId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('BlenderInvoiceArchiveDetailPage', () {
    testWidgets('reports the invoice as not found for an unknown id', (
      tester,
    ) async {
      await _pump(tester, invoiceId: 'missing');
      expect(find.textContaining('Invoice not found'), findsOneWidget);
    });

    testWidgets(
      'shows the invoice date, billed-to, every itemised line and the total',
      (tester) async {
        await _pump(
          tester,
          invoiceId: 'inv-1',
          invoices: [
            ArchivedInvoice(
              id: 'inv-1',
              date: DateTime(2026, 3, 5),
              billedTo: 'Ada',
              fills: const [
                BilledFill(
                  id: 'f1',
                  label: 'Tx 18/45',
                  lines: [
                    BilledGasLine(
                      gas: 'O₂',
                      addedBar: 10,
                      cost: 10,
                      freeGasLiters: 30,
                      cylinderLiters: 12,
                    ),
                    BilledGasLine(gas: 'He', addedBar: 80, cost: 20),
                  ],
                  total: 30,
                ),
              ],
              total: 30,
              currencyCode: 'CHF',
            ),
          ],
        );

        expect(find.textContaining('Mar 5, 2026'), findsOneWidget);
        expect(find.textContaining('Billed to: Ada'), findsOneWidget);
        expect(find.text('Tx 18/45'), findsOneWidget);
        // The line saved with a volume and a cylinder size shows both,
        // units in the column header rather than repeated per cell...
        expect(find.text('30'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        // ...while the He line saved before #1335, with neither
        // freeGasLiters nor cylinderLiters, falls back to a dash in both
        // columns (see BlenderBilledLineRow). A bare
        // `find.textContaining('bar')` would pass regardless of either
        // fallback, since the "Hinzufügen (bar)" column header itself
        // contains that substring.
        expect(find.text('—'), findsNWidgets(2));
        expect(find.text('Total'), findsOneWidget);
      },
    );

    testWidgets('an unpriced invoice shows Incomplete instead of a total', (
      tester,
    ) async {
      await _pump(
        tester,
        invoiceId: 'inv-1',
        invoices: [
          ArchivedInvoice(
            id: 'inv-1',
            date: DateTime(2026, 3, 5),
            billedTo: '',
            fills: const [
              BilledFill(id: 'f1', label: 'Tx 18/45', lines: [], total: null),
            ],
            total: null,
          ),
        ],
      );

      expect(find.text('Incomplete'), findsOneWidget);
    });

    testWidgets(
      'the app bar delete action removes the invoice and pops back, once '
      'confirmed',
      (tester) async {
        // The app bar action shares deleteArchivedInvoice with the archive
        // list tile (issue #1876), so the running invoice's data stays in
        // sync from either entry point.
        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => MockSettingsNotifier(
                const AppSettings(defaultCurrency: 'CHF'),
              ),
            ),
            blenderArchivedInvoicesProvider.overrideWith(
              (ref) => [
                ArchivedInvoice(
                  id: 'inv-1',
                  date: DateTime(2026, 3, 5),
                  billedTo: 'Ada',
                  fills: const [
                    BilledFill(
                      id: 'f1',
                      label: 'Tx 18/45',
                      lines: [],
                      total: 30,
                    ),
                  ],
                  total: 30,
                  currencyCode: 'CHF',
                ),
              ],
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BlenderInvoiceArchiveDetailPage(
                        invoiceId: 'inv-1',
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('Tx 18/45'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('blender-archived-invoice-detail-delete')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(container.read(blenderArchivedInvoicesProvider), isEmpty);
        expect(find.text('open'), findsOneWidget);
        expect(find.text('Tx 18/45'), findsNothing);
      },
    );
  });

  group('reached without the calculator', () {
    /// The class doc promises a deep link resolves, and a deep link is
    /// exactly the case where GasBlenderCalculator never mounted to run
    /// blenderPreferencesLoaderProvider (PR #1359 review).
    testWidgets('resolves an invoice loaded straight from storage', (
      tester,
    ) async {
      final repository = FakeAppSettingsRepository()
        ..blenderPreferences = BlenderPreferences(
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
          archivedInvoices: [
            ArchivedInvoice(
              id: 'inv-1',
              date: DateTime(2026, 3, 5),
              billedTo: 'Ada',
              fills: const [
                BilledFill(id: 'f', label: 'Tx 18/45', lines: [], total: 35),
              ],
              total: 35,
              currencyCode: 'CHF',
            ),
          ],
        );

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
            home: BlenderInvoiceArchiveDetailPage(invoiceId: 'inv-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Invoice not found'), findsNothing);
      expect(find.text('Tx 18/45'), findsOneWidget);
    });
  });
}
