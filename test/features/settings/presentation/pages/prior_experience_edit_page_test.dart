import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/prior_experience_edit_page.dart';
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
    int? priorDiveCount,
    int? priorDiveTimeSeconds,
    DateTime? divingSince,
  }) {
    return Diver(
      id: 'diver-1',
      name: 'Alice Alpha',
      createdAt: now,
      updatedAt: now,
      priorDiveCount: priorDiveCount,
      priorDiveTimeSeconds: priorDiveTimeSeconds,
      divingSince: divingSince,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PriorExperienceEditPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  testWidgets('populates fields from the existing diver', (tester) async {
    final notifier = await pump(
      tester,
      makeDiver(
        priorDiveCount: 42,
        priorDiveTimeSeconds: 2 * 3600 + 30 * 60,
        divingSince: DateTime(2008),
      ),
    );

    expect(find.widgetWithText(TextFormField, '42'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '2'), findsOneWidget); // hours
    expect(find.widgetWithText(TextFormField, '30'), findsOneWidget); // minutes
    expect(find.textContaining('2008'), findsWidgets);
    expect(notifier.updated, isNull);
  });

  testWidgets('entering prior experience saves it onto the diver', (
    tester,
  ) async {
    final notifier = await pump(tester, makeDiver());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prior dives'),
      '150',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prior hours'),
      '75',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Minutes'), '45');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNotNull);
    expect(notifier.updated!.priorDiveCount, 150);
    expect(notifier.updated!.priorDiveTimeSeconds, 75 * 3600 + 45 * 60);
  });

  testWidgets('rejects negative dive counts and does not save', (tester) async {
    final notifier = await pump(tester, makeDiver());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prior dives'),
      '-5',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNull);
    expect(find.text('Enter a valid number'), findsOneWidget);
  });

  testWidgets('rejects minutes greater than 59', (tester) async {
    final notifier = await pump(tester, makeDiver());

    await tester.enterText(find.widgetWithText(TextFormField, 'Minutes'), '90');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNull);
  });

  testWidgets('clearing a previously-set dive count persists null', (
    tester,
  ) async {
    final notifier = await pump(tester, makeDiver(priorDiveCount: 80));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prior dives'),
      '',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNotNull);
    expect(notifier.updated!.priorDiveCount, isNull);
  });
}
