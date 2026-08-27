import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/insurance_edit_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _CapturingNotifier extends StateNotifier<AsyncValue<List<Diver>>>
    implements DiverListNotifier {
  _CapturingNotifier(List<Diver> divers) : super(AsyncValue.data(divers));

  Diver? updated;

  @override
  Future<Diver> addDiver(Diver diver) async => diver;

  @override
  Future<void> updateDiver(Diver diver) async => updated = diver;

  @override
  Future<void> refresh() async {}

  @override
  Future<DeleteDiverResult> deleteDiver(String id) async =>
      const DeleteDiverResult(reassignedTripsCount: 0, reassignedSitesCount: 0);

  @override
  Future<void> setAsDefault(String id) async {}
}

void main() {
  final now = DateTime.now();

  Diver makeDiver({DiverInsurance insurance = const DiverInsurance()}) {
    return Diver(
      id: 'diver-1',
      name: 'Alice Alpha',
      createdAt: now,
      updatedAt: now,
      insurance: insurance,
    );
  }

  Future<_CapturingNotifier> pump(WidgetTester tester, Diver diver) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifier = _CapturingNotifier([diver]);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          currentDiverProvider.overrideWith((_) async => diver),
          diverListNotifierProvider.overrideWith((_) => notifier),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InsuranceEditPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  testWidgets('populates the policy fields and expiry from the diver', (
    tester,
  ) async {
    final expiry = DateTime(2030, 6, 15);
    final notifier = await pump(
      tester,
      makeDiver(
        insurance: DiverInsurance(
          provider: 'DAN',
          policyNumber: 'POL-12345',
          expiryDate: expiry,
        ),
      ),
    );

    expect(find.widgetWithText(AppBar, 'Insurance'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('DAN'), findsOneWidget);
    expect(find.text('POL-12345'), findsOneWidget);
    expect(find.textContaining('2030'), findsOneWidget);
    expect(notifier.updated, isNull);
  });

  testWidgets('shows the not-set placeholder when no expiry is stored', (
    tester,
  ) async {
    await pump(tester, makeDiver());

    expect(find.text('Not set'), findsOneWidget);
    expect(
      find.byTooltip('Clear insurance expiry date'),
      findsNothing,
      reason: 'the clear button only makes sense once an expiry exists',
    );
  });

  testWidgets('saving persists the trimmed provider and policy number', (
    tester,
  ) async {
    final expiry = DateTime(2030, 6, 15);
    final notifier = await pump(
      tester,
      makeDiver(insurance: DiverInsurance(expiryDate: expiry)),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Insurance Provider'),
      '  DiveAssure  ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Policy Number'),
      'POL-99',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNotNull);
    expect(notifier.updated!.insurance.provider, 'DiveAssure');
    expect(notifier.updated!.insurance.policyNumber, 'POL-99');
    expect(
      notifier.updated!.insurance.expiryDate,
      expiry,
      reason: 'an untouched expiry must survive the save',
    );
  });

  testWidgets('clearing the expiry date persists a null expiry', (
    tester,
  ) async {
    final notifier = await pump(
      tester,
      makeDiver(
        insurance: DiverInsurance(
          provider: 'DAN',
          expiryDate: DateTime(2030, 6, 15),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Clear insurance expiry date'));
    await tester.pumpAndSettle();
    expect(find.text('Not set'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNotNull);
    expect(notifier.updated!.insurance.expiryDate, isNull);
    expect(notifier.updated!.insurance.provider, 'DAN');
  });

  testWidgets('clearing the provider persists null', (tester) async {
    final notifier = await pump(
      tester,
      makeDiver(
        insurance: const DiverInsurance(
          provider: 'DAN',
          policyNumber: 'POL-12345',
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Insurance Provider'),
      '',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNotNull);
    expect(notifier.updated!.insurance.provider, isNull);
    expect(notifier.updated!.insurance.policyNumber, 'POL-12345');
  });

  testWidgets('the expiry-date button opens the date picker (#765)', (
    tester,
  ) async {
    await pump(tester, makeDiver());

    await tester.tap(find.byIcon(Icons.edit_calendar));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
  });
}
