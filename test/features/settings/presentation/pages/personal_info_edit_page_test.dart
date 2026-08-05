import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/personal_info_edit_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _CapturingNotifier extends StateNotifier<AsyncValue<List<Diver>>>
    implements DiverListNotifier {
  _CapturingNotifier(List<Diver> divers) : super(AsyncValue.data(divers));

  Diver? updated;
  Diver? added;

  @override
  Future<Diver> addDiver(Diver diver) async {
    added = diver;
    return diver;
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

void main() {
  final now = DateTime.now();

  Diver makeDiver({String name = 'Alice Alpha', String? email, String? phone}) {
    return Diver(
      id: 'diver-1',
      name: name,
      email: email,
      phone: phone,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<_CapturingNotifier> pump(
    WidgetTester tester,
    Diver diver, {
    bool isNewDiver = false,
  }) async {
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
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PersonalInfoEditPage(isNewDiver: isNewDiver),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  testWidgets('populates the fields from the existing diver', (tester) async {
    final notifier = await pump(
      tester,
      makeDiver(email: 'alice@example.com', phone: '555-0100'),
    );

    expect(find.widgetWithText(AppBar, 'Personal Info'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Alice Alpha'), findsOneWidget);
    expect(find.text('alice@example.com'), findsOneWidget);
    expect(find.text('555-0100'), findsOneWidget);
    expect(notifier.updated, isNull);
  });

  testWidgets('saving persists the edited name, email and phone', (
    tester,
  ) async {
    final notifier = await pump(tester, makeDiver());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name *'),
      '  Bruna Bravo  ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'bruna@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone'),
      '555-0199',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNotNull);
    expect(notifier.updated!.id, 'diver-1');
    expect(notifier.updated!.name, 'Bruna Bravo');
    expect(notifier.updated!.email, 'bruna@example.com');
    expect(notifier.updated!.phone, '555-0199');
  });

  testWidgets('clearing an optional field persists null', (tester) async {
    final notifier = await pump(
      tester,
      makeDiver(email: 'alice@example.com', phone: '555-0100'),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNotNull);
    expect(notifier.updated!.email, isNull);
    expect(notifier.updated!.phone, '555-0100');
  });

  testWidgets('an empty name blocks the save', (tester) async {
    final notifier = await pump(tester, makeDiver());

    await tester.enterText(find.widgetWithText(TextFormField, 'Name *'), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNull);
    expect(find.text('Name is required'), findsOneWidget);
  });

  testWidgets('a malformed email blocks the save', (tester) async {
    final notifier = await pump(tester, makeDiver());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'not-an-email',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNull);
    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('new-diver mode creates a diver instead of updating one', (
    tester,
  ) async {
    final notifier = await pump(tester, makeDiver(), isNewDiver: true);

    expect(find.widgetWithText(AppBar, 'Create Diver'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name *'),
      'Carlos Charlie',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.added, isNotNull);
    expect(notifier.added!.name, 'Carlos Charlie');
    expect(notifier.added!.id, isNotEmpty);
    expect(notifier.updated, isNull);
  });
}
