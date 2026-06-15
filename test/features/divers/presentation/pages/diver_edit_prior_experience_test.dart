import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/pages/diver_edit_page.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

class _CapturingNotifier extends StateNotifier<AsyncValue<List<Diver>>>
    implements DiverListNotifier {
  _CapturingNotifier() : super(const AsyncValue.data([]));
  Diver? added;
  Diver? updated;

  @override
  Future<Diver> addDiver(Diver diver) async {
    added = diver;
    return diver.copyWith(id: 'new-id');
  }

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

Future<_CapturingNotifier> _pumpEdit(
  WidgetTester tester, {
  String? diverId,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final notifier = _CapturingNotifier();
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        diverListNotifierProvider.overrideWith((ref) => notifier),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DiverEditPage(
            embedded: true,
            diverId: diverId,
            onSaved: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return notifier;
}

void main() {
  testWidgets('entering prior experience saves it onto the new Diver', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifier = _CapturingNotifier();
    final overrides = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diverListNotifierProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiverEditPage(embedded: true, onSaved: (_) {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Test Diver');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prior dives'),
      '1200',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prior hours'),
      '1150',
    );
    await tester.pumpAndSettle();

    final addBtn = find.widgetWithText(FilledButton, 'Add Diver');
    await tester.ensureVisible(addBtn);
    await tester.pumpAndSettle();
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    expect(notifier.added, isNotNull);
    expect(notifier.added!.priorDiveCount, 1200);
    expect(notifier.added!.priorDiveTimeSeconds, 1150 * 3600);
  });

  testWidgets('edit mode loads prior experience and clears diving-since', (
    tester,
  ) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final created = await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'Old Salt',
        priorDiveCount: 1200,
        priorDiveTimeSeconds: 1150 * 3600,
        divingSince: DateTime(1990),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await _pumpEdit(tester, diverId: created.id);

    // initState populated the fields from the loaded diver.
    expect(find.text('1200'), findsOneWidget);
    expect(find.text('1990'), findsOneWidget);

    // Clear the "diving since" year.
    final clearBtn = find.descendant(
      of: find.widgetWithText(ListTile, 'Diving since'),
      matching: find.byIcon(Icons.clear),
    );
    expect(clearBtn, findsOneWidget);
    await tester.tap(clearBtn);
    await tester.pumpAndSettle();
    expect(find.text('1990'), findsNothing); // year cleared
  });

  testWidgets('rejects invalid prior numbers (blocks save)', (tester) async {
    final notifier = await _pumpEdit(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Bad Numbers');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prior dives'),
      '-5',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Minutes'), '99');
    await tester.pumpAndSettle();

    final addBtn = find.widgetWithText(FilledButton, 'Add Diver');
    await tester.ensureVisible(addBtn);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    expect(notifier.added, isNull); // validation failed -> not saved
    expect(find.text('Enter a valid number'), findsWidgets);
  });

  testWidgets('year picker sets diving-since on save', (tester) async {
    final notifier = await _pumpEdit(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Picker Diver');
    await tester.ensureVisible(find.text('Diving since'));
    await tester.tap(find.text('Diving since'));
    await tester.pumpAndSettle();
    // Date picker opens in year mode; confirm the default initial date.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final addBtn = find.widgetWithText(FilledButton, 'Add Diver');
    await tester.ensureVisible(addBtn);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    expect(notifier.added?.divingSince, isNotNull);
    expect(notifier.added!.divingSince!.year, DateTime.now().year - 10);
  });
}
