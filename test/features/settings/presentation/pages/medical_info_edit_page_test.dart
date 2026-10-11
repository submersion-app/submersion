import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/medical_info_edit_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

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

  Document clearance(String id, DateTime? expiry) => Document(
    id: id,
    diverId: 'diver-1',
    owner: const DocumentOwner.personal(),
    type: DocumentType.medicalClearance,
    title: 'Clearance $id',
    expiryDate: expiry,
    createdAt: now,
    updatedAt: now,
  );

  Future<_CapturingNotifier> pump(
    WidgetTester tester,
    Diver diver, {
    List<Document> documents = const [],
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifier = _CapturingNotifier([diver]);
    final overrides = await getBaseOverrides(ownerDocuments: documents);
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
    expect(notifier.updated, isNull);
  });

  testWidgets('lists medical clearance documents with their badge (#2613)', (
    tester,
  ) async {
    await pump(
      tester,
      makeDiver(),
      documents: [
        clearance('old', now.subtract(const Duration(days: 1))),
        Document(
          id: 'permit',
          diverId: 'diver-1',
          owner: const DocumentOwner.personal(),
          type: DocumentType.permit,
          title: 'Park permit',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    expect(find.text('Medical clearances'), findsOneWidget);
    expect(find.text('Clearance old'), findsOneWidget);
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Park permit'), findsNothing);
  });

  testWidgets('with no clearance on record it says so', (tester) async {
    await pump(tester, makeDiver());
    expect(find.text('No medical clearance recorded'), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('Add clearance opens a new clearance document', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final diver = makeDiver();
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/medical',
      routes: [
        GoRoute(
          path: '/medical',
          builder: (context, state) => const MedicalInfoEditPage(),
        ),
        GoRoute(
          path: '/documents/new',
          builder: (context, state) =>
              Scaffold(body: Text('NEW ${state.uri.query}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          currentDiverProvider.overrideWith((_) async => diver),
          diverListNotifierProvider.overrideWith(
            (_) => _CapturingNotifier([diver]),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add clearance'));
    await tester.pumpAndSettle();
    expect(find.text('NEW type=medicalClearance'), findsOneWidget);
  });

  testWidgets('saving persists the trimmed medical details', (tester) async {
    final notifier = await pump(tester, makeDiver());

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
}
