import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/emergency_contacts_edit_page.dart';
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
    EmergencyContact primary = const EmergencyContact(),
    EmergencyContact secondary = const EmergencyContact(),
  }) {
    return Diver(
      id: 'diver-1',
      name: 'Alice Alpha',
      createdAt: now,
      updatedAt: now,
      emergencyContact: primary,
      emergencyContact2: secondary,
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
          home: EmergencyContactsEditPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  /// Finds a field by label inside the card headed by [cardTitle], so the
  /// primary and secondary contact forms can be told apart.
  Finder fieldIn(String cardTitle, String label) {
    return find.descendant(
      of: find
          .ancestor(of: find.text(cardTitle), matching: find.byType(Card))
          .first,
      matching: find.widgetWithText(TextFormField, label),
    );
  }

  testWidgets('populates both contact cards from the existing diver', (
    tester,
  ) async {
    final notifier = await pump(
      tester,
      makeDiver(
        primary: const EmergencyContact(
          name: 'Bruna Bravo',
          phone: '555-0100',
          relation: 'Spouse',
        ),
        secondary: const EmergencyContact(
          name: 'Carlos Charlie',
          phone: '555-0200',
          relation: 'Brother',
        ),
      ),
    );

    expect(find.widgetWithText(AppBar, 'Emergency Contacts'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Bruna Bravo'), findsOneWidget);
    expect(find.text('555-0200'), findsOneWidget);
    expect(find.text('Brother'), findsOneWidget);
    expect(notifier.updated, isNull);
  });

  testWidgets('saving persists the primary contact and leaves the secondary '
      'null when blank', (tester) async {
    final notifier = await pump(tester, makeDiver());

    await tester.enterText(
      fieldIn('Primary Contact', 'Contact Name'),
      '  Bruna Bravo  ',
    );
    await tester.enterText(
      fieldIn('Primary Contact', 'Contact Phone'),
      '555-0100',
    );
    await tester.enterText(
      fieldIn('Primary Contact', 'Relationship'),
      'Spouse',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNotNull);
    expect(notifier.updated!.emergencyContact.name, 'Bruna Bravo');
    expect(notifier.updated!.emergencyContact.phone, '555-0100');
    expect(notifier.updated!.emergencyContact.relation, 'Spouse');
    expect(notifier.updated!.emergencyContact2.name, isNull);
    expect(notifier.updated!.emergencyContact2.phone, isNull);
  });

  testWidgets('saving persists an edited secondary contact independently', (
    tester,
  ) async {
    final notifier = await pump(
      tester,
      makeDiver(
        primary: const EmergencyContact(name: 'Bruna Bravo', phone: '555-0100'),
      ),
    );

    await tester.enterText(
      fieldIn('Secondary Contact', 'Contact Name'),
      'Carlos Charlie',
    );
    await tester.enterText(
      fieldIn('Secondary Contact', 'Contact Phone'),
      '555-0200',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNotNull);
    expect(notifier.updated!.emergencyContact.name, 'Bruna Bravo');
    expect(notifier.updated!.emergencyContact2.name, 'Carlos Charlie');
    expect(notifier.updated!.emergencyContact2.phone, '555-0200');
  });

  testWidgets('clearing a stored contact persists null', (tester) async {
    final notifier = await pump(
      tester,
      makeDiver(
        primary: const EmergencyContact(
          name: 'Bruna Bravo',
          phone: '555-0100',
          relation: 'Spouse',
        ),
      ),
    );

    await tester.enterText(fieldIn('Primary Contact', 'Contact Name'), '');
    await tester.enterText(fieldIn('Primary Contact', 'Contact Phone'), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNotNull);
    expect(notifier.updated!.emergencyContact.name, isNull);
    expect(notifier.updated!.emergencyContact.phone, isNull);
    expect(notifier.updated!.emergencyContact.relation, 'Spouse');
  });
}
