import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/medical_info_edit_page.dart';
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

  Diver makeDiver({
    String? bloodType,
    String? allergies,
    String? medications,
    String medicalNotes = '',
    DateTime? clearanceExpiry,
  }) {
    return Diver(
      id: 'diver-1',
      name: 'Alice Alpha',
      createdAt: now,
      updatedAt: now,
      bloodType: bloodType,
      allergies: allergies,
      medications: medications,
      medicalNotes: medicalNotes,
      medicalClearanceExpiryDate: clearanceExpiry,
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
          home: MedicalInfoEditPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  testWidgets('populates the medical fields from the existing diver', (
    tester,
  ) async {
    final notifier = await pump(
      tester,
      makeDiver(
        bloodType: 'O+',
        allergies: 'Penicillin',
        medications: 'None',
        medicalNotes: 'Cleared for deep diving',
        clearanceExpiry: DateTime(2030, 6, 15),
      ),
    );

    expect(find.widgetWithText(AppBar, 'Medical Information'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('O+'), findsOneWidget);
    expect(find.text('Penicillin'), findsOneWidget);
    expect(find.text('Cleared for deep diving'), findsOneWidget);
    expect(find.textContaining('2030'), findsOneWidget);
    expect(notifier.updated, isNull);
  });

  testWidgets('flags a clearance date that has already passed', (tester) async {
    await pump(
      tester,
      makeDiver(clearanceExpiry: now.subtract(const Duration(days: 1))),
    );

    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Expiring Soon'), findsNothing);
  });

  testWidgets('flags a clearance date that is about to lapse', (tester) async {
    await pump(
      tester,
      makeDiver(clearanceExpiry: now.add(const Duration(days: 7))),
    );

    expect(find.text('Expiring Soon'), findsOneWidget);
    expect(find.text('Expired'), findsNothing);
  });

  testWidgets('saving persists the trimmed medical details', (tester) async {
    final expiry = DateTime(2030, 6, 15);
    final notifier = await pump(tester, makeDiver(clearanceExpiry: expiry));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Blood Type'),
      '  AB-  ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Allergies'),
      'Latex',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Medications'),
      'Antihistamine',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Medical Notes'),
      'Annual physical on file',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNotNull);
    expect(notifier.updated!.bloodType, 'AB-');
    expect(notifier.updated!.allergies, 'Latex');
    expect(notifier.updated!.medications, 'Antihistamine');
    expect(notifier.updated!.medicalNotes, 'Annual physical on file');
    expect(
      notifier.updated!.medicalClearanceExpiryDate,
      expiry,
      reason: 'an untouched clearance date must survive the save',
    );
  });

  testWidgets('clearing the clearance date persists null', (tester) async {
    final notifier = await pump(
      tester,
      makeDiver(bloodType: 'O+', clearanceExpiry: DateTime(2030, 6, 15)),
    );

    await tester.tap(find.byTooltip('Clear medical clearance date'));
    await tester.pumpAndSettle();
    expect(find.text('Not set'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNotNull);
    expect(notifier.updated!.medicalClearanceExpiryDate, isNull);
    expect(notifier.updated!.bloodType, 'O+');
  });

  testWidgets('clearing an optional field persists null', (tester) async {
    final notifier = await pump(
      tester,
      makeDiver(bloodType: 'O+', allergies: 'Penicillin'),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Allergies'), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNotNull);
    expect(notifier.updated!.allergies, isNull);
    expect(notifier.updated!.bloodType, 'O+');
  });

  testWidgets('the clearance-date button opens the date picker (#765)', (
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
