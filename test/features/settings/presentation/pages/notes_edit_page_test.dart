import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/notes_edit_page.dart';
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

  Diver makeDiver({String notes = ''}) {
    return Diver(
      id: 'diver-1',
      name: 'Alice Alpha',
      createdAt: now,
      updatedAt: now,
      notes: notes,
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
          home: NotesEditPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  testWidgets('populates the notes field from the existing diver', (
    tester,
  ) async {
    final notifier = await pump(
      tester,
      makeDiver(notes: 'Prefers early morning boat dives'),
    );

    expect(find.widgetWithText(AppBar, 'Notes'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Prefers early morning boat dives'), findsOneWidget);
    expect(notifier.updated, isNull);
  });

  testWidgets('saving persists the trimmed notes onto the diver', (
    tester,
  ) async {
    final notifier = await pump(tester, makeDiver());

    await tester.enterText(
      find.byType(TextField),
      '  Nitrox refresher due in spring  ',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNotNull);
    expect(notifier.updated!.notes, 'Nitrox refresher due in spring');
    expect(notifier.updated!.id, 'diver-1');
  });

  testWidgets('clearing existing notes persists an empty string', (
    tester,
  ) async {
    final notifier = await pump(tester, makeDiver(notes: 'Old note'));

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNotNull);
    expect(notifier.updated!.notes, isEmpty);
  });
}
