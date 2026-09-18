import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_centers/domain/services/rental_memory_resolver.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_gear_note_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_memory_card.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  final center = DiveCenter(
    id: 'c1',
    name: 'Reef Divers',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final last = LastDiveAtCenter(
    diveId: 'd0',
    dateTime: DateTime(2026, 3, 12),
    weights: const [
      DiveWeight(
        id: 'w1',
        diveId: 'd0',
        weightType: WeightType.belt,
        amountKg: 6,
      ),
      DiveWeight(
        id: 'w2',
        diveId: 'd0',
        weightType: WeightType.trimWeights,
        amountKg: 2,
      ),
    ],
    weightingFeedback: WeightingFeedback.overweighted,
    weightingFeedbackKg: 1,
    tanks: const [
      DiveTank(
        id: 't1',
        volume: 11.1,
        workingPressure: 207,
        presetName: 'al80',
      ),
    ],
  );

  final notes = [
    DiveCenterGearNote(
      id: 'n1',
      diveCenterId: 'c1',
      gearType: EquipmentType.regulator,
      label: '14',
      verdict: RentalVerdict.avoid,
      note: 'breathes wet',
      notedAt: DateTime(2026, 3, 12),
      createdAt: DateTime(2026, 3, 12),
      updatedAt: DateTime(2026, 3, 12),
    ),
    DiveCenterGearNote(
      id: 'n2',
      diveCenterId: 'c1',
      gearType: EquipmentType.bcd,
      size: 'L',
      verdict: RentalVerdict.worked,
      leadAdjustmentKg: 2,
      notedAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    required LastDiveAtCenter? lastDive,
    required List<DiveCenterGearNote> withNotes,
    void Function(LastDiveAtCenter)? onApply,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          diveCenterGearNotesProvider(
            'c1',
          ).overrideWith((ref) async => withNotes),
          lastDiveAtCenterProvider((
            centerId: 'c1',
            excludingDiveId: 'd1',
          )).overrideWith((ref) async => lastDive),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RentalMemoryCard(
                center: center,
                currentDiveId: 'd1',
                onApplyLastDive: onApply ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the last dive facts and the notes', (tester) async {
    await pump(tester, lastDive: last, withNotes: notes);
    expect(find.text('Last time at Reef Divers'), findsOneWidget);
    expect(find.textContaining('Last dive here:'), findsOneWidget);
    expect(find.text('Lead: 8.0 kg'), findsOneWidget);
    expect(find.text('1.0 kg over'), findsOneWidget);
    expect(find.textContaining('11 L'), findsOneWidget);
    expect(find.text('Apply last dive'), findsOneWidget);
    // Notes, newest first, with their verdicts and numbers.
    expect(find.text('14'), findsOneWidget);
    expect(find.text('breathes wet'), findsOneWidget);
    expect(find.text('Avoid'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
    expect(find.text('Worked'), findsOneWidget);
    expect(find.text('2.0 kg extra lead'), findsOneWidget);
    expect(find.text('Add rental note'), findsOneWidget);
  });

  testWidgets('apply hands the last dive to the page', (tester) async {
    LastDiveAtCenter? applied;
    await pump(
      tester,
      lastDive: last,
      withNotes: const [],
      onApply: (l) => applied = l,
    );
    await tester.tap(find.text('Apply last dive'));
    await tester.pump();
    expect(applied, same(last));
  });

  testWidgets('with no history and no notes only the add button shows', (
    tester,
  ) async {
    await pump(tester, lastDive: null, withNotes: const []);
    expect(find.text('Add rental note'), findsOneWidget);
    expect(find.text('Apply last dive'), findsNothing);
    expect(find.text('Last time at Reef Divers'), findsNothing);
    expect(find.textContaining('Lead:'), findsNothing);
  });

  testWidgets('notes without history still show under the header', (
    tester,
  ) async {
    await pump(tester, lastDive: null, withNotes: notes);
    expect(find.text('Last time at Reef Divers'), findsOneWidget);
    expect(find.text('No other dives logged here yet.'), findsOneWidget);
    expect(find.text('breathes wet'), findsOneWidget);
    expect(find.text('Apply last dive'), findsNothing);
  });

  testWidgets('shows under, bare over, less lead and actual capacity', (
    tester,
  ) async {
    final under = LastDiveAtCenter(
      diveId: 'd0',
      dateTime: DateTime(2026, 3, 12),
      weights: last.weights,
      weightingFeedback: WeightingFeedback.underweighted,
      weightingFeedbackKg: 1.5,
      tanks: const [],
    );
    final tankNote = DiveCenterGearNote(
      id: 'n3',
      diveCenterId: 'c1',
      gearType: EquipmentType.tank,
      label: 'AL80',
      verdict: RentalVerdict.worked,
      leadAdjustmentKg: -1,
      volumeLiters: 11.1,
      notedAt: DateTime(2026, 3, 12),
      createdAt: DateTime(2026, 3, 12),
      updatedAt: DateTime(2026, 3, 12),
    );
    await pump(tester, lastDive: under, withNotes: [tankNote]);
    expect(find.text('1.5 kg under'), findsOneWidget);
    expect(
      find.text('1.0 kg less lead\nActual capacity 11.1 L'),
      findsOneWidget,
    );
  });

  testWidgets('feedback without an amount uses the plain label', (
    tester,
  ) async {
    final bareOver = LastDiveAtCenter(
      diveId: 'd0',
      dateTime: DateTime(2026, 3, 12),
      weights: last.weights,
      weightingFeedback: WeightingFeedback.overweighted,
      weightingFeedbackKg: null,
      tanks: const [],
    );
    await pump(tester, lastDive: bareOver, withNotes: const []);
    expect(find.text('Overweighted'), findsOneWidget);
  });

  testWidgets('add opens a new note and a tapped note opens its editor', (
    tester,
  ) async {
    await pump(tester, lastDive: last, withNotes: notes);
    await tester.tap(find.text('Add rental note'));
    await tester.pumpAndSettle();
    expect(find.text('New rental note'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('breathes wet'));
    await tester.pumpAndSettle();
    expect(find.text('Edit rental note'), findsOneWidget);
  });
}
