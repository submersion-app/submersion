import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_twin_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_header_actions.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_weights_buoyancy_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_figure.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';

import '../../../../../helpers/mock_providers.dart';
import '../buoyancy_outcome_fixture.dart';

/// The one card that holds a dive's weights and its buoyancy model
/// (issue #5005).
void main() {
  final weighted = Dive(
    id: 'd1',
    dateTime: DateTime.utc(2026, 3, 15, 10),
    weights: const [
      DiveWeight(
        id: 'w1',
        diveId: 'd1',
        weightType: WeightType.belt,
        amountKg: 4,
      ),
      DiveWeight(
        id: 'w2',
        diveId: 'd1',
        weightType: WeightType.trimWeights,
        amountKg: 2,
      ),
    ],
  );

  Future<void> pump(
    WidgetTester tester, {
    required BuoyancyTwinOutcome? outcome,
    bool showWeights = true,
    bool unlocked = false,
    Locale locale = const Locale('en'),
    double? width,
  }) async {
    if (width != null) {
      tester.view.physicalSize = Size(width * 2, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
    }
    Widget card = DiveWeightsBuoyancyCard(
      dive: weighted,
      stored: weighted,
      showWeights: showWeights,
    );
    if (unlocked) {
      // What a RecordCardFrame provides while the dive is unlocked: the
      // header then draws its pencil.
      card = RecordCardFrameScope(
        data: RecordCardFrameData(
          isOpen: false,
          isChanged: false,
          onOpen: () {},
          onDone: () {},
        ),
        child: card,
      );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          buoyancyTwinProvider('d1').overrideWith((ref) async => outcome),
          latestDiverWeightProvider.overrideWith((ref) async => null),
          latestDiverHeightProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          // Pinned so the asserted strings do not depend on the host locale.
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: card)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the weights list above the model, in one card', (
    tester,
  ) async {
    await pump(tester, outcome: buoyancyOutcome());

    expect(find.byType(Card), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Weight Belt')).dy,
      lessThan(tester.getTopLeft(find.text('Lead for next time')).dy),
    );
    expect(find.byType(BuoyancyHeaderActions), findsOneWidget);
  });

  testWidgets('is titled Weights and buoyancy', (tester) async {
    await pump(tester, outcome: buoyancyOutcome());

    expect(find.text('Weights and buoyancy'), findsOneWidget);
    expect(find.text('BUOYANCY'), findsNothing);
    expect(find.text('Weight'), findsNothing);
  });

  testWidgets('with no model shows the list only, with no What if?', (
    tester,
  ) async {
    await pump(tester, outcome: null);

    expect(find.text('Weight Belt'), findsOneWidget);
    expect(find.text('Trim Weights'), findsOneWidget);
    expect(find.text('What if?'), findsNothing);
    expect(find.text('Lead for next time'), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('with no weights to show shows the model only', (tester) async {
    await pump(tester, outcome: buoyancyOutcome(), showWeights: false);

    expect(find.text('Weight Belt'), findsNothing);
    expect(find.text('Lead for next time'), findsOneWidget);
  });

  for (final width in [360.0, 1100.0]) {
    testWidgets('nothing overflows at ${width.round()} px, unlocked', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pump(tester, outcome: buoyancyOutcome(), unlocked: true);

      expect(tester.takeException(), isNull);
      expect(find.text('Weights and buoyancy'), findsOneWidget);
    });
  }

  testWidgets('a narrow card keeps only the What if? icon in German', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pump(
      tester,
      outcome: buoyancyOutcome(),
      unlocked: true,
      locale: const Locale('de'),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Was wäre, wenn?'), findsNothing);
    expect(find.byTooltip('Was wäre, wenn?'), findsOneWidget);
  });

  testWidgets('a wide card shows the What if? label', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pump(tester, outcome: buoyancyOutcome(), unlocked: true);

    expect(find.text('What if?'), findsOneWidget);
  });

  testWidgets('unlocking does not change the title row height', (tester) async {
    // Wide enough for the label beside the title and icon alone, too narrow
    // once the pencil's room is counted.
    await tester.binding.setSurfaceSize(const Size(400, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final header = find.byType(RecordCardHeader);

    await pump(tester, outcome: buoyancyOutcome());
    // The pencil's room is kept while locked, so the button already takes
    // the form it keeps once unlocked.
    expect(find.text('What if?'), findsNothing);
    expect(find.byTooltip('What if?'), findsOneWidget);
    final locked = tester.getSize(header).height;

    await pump(tester, outcome: buoyancyOutcome(), unlocked: true);
    expect(find.byTooltip('What if?'), findsOneWidget);
    expect(tester.getSize(header).height, locked);
  });

  testWidgets('many weights with long names fit a phone and total them', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final many = weighted.copyWith(
      weights: [
        for (var i = 0; i < 10; i++)
          DiveWeight(
            id: 'm$i',
            diveId: 'd1',
            weightType: WeightType.integrated,
            amountKg: 1.5,
            label: 'Left rear pocket of the travel harness number $i',
          ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          buoyancyTwinProvider(
            'd1',
          ).overrideWith((ref) async => buoyancyOutcome(leadKg: 15)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DiveWeightsBuoyancyCard(
                dive: many,
                stored: many,
                showWeights: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('1.5 kg'), findsNWidgets(10));
    expect(find.text('15.0 kg'), findsWidgets);
    expect(find.text('Total:'), findsOneWidget);
  });

  group('trim figure (#5028)', () {
    testWidgets('sits between the weights list and the model', (tester) async {
      await pump(tester, outcome: buoyancyOutcome(), width: 400);
      final figure = tester.getTopLeft(find.byType(TrimFigure)).dy;
      expect(
        figure,
        greaterThan(tester.getTopLeft(find.text('Weight Belt')).dy),
      );
      expect(
        figure,
        lessThan(tester.getTopLeft(find.text('Lead for next time')).dy),
      );
    });

    testWidgets('no model, no figure, and the list still shows', (
      tester,
    ) async {
      await pump(tester, outcome: null);
      expect(find.byType(TrimFigure), findsNothing);
      expect(find.text('Weight Belt'), findsOneWidget);
    });

    testWidgets('sits beside the list at 720 wide and over', (tester) async {
      await pump(tester, outcome: buoyancyOutcome(), width: 1000);
      final figure = tester.getRect(find.byType(TrimFigure));
      final list = tester.getRect(find.text('Weight Belt'));
      expect(figure.left, greaterThan(list.left));
      expect(figure.top, lessThan(list.bottom + 40));
    });

    testWidgets('stacks under the list when narrow', (tester) async {
      await pump(tester, outcome: buoyancyOutcome(), width: 400);
      final figure = tester.getRect(find.byType(TrimFigure));
      final list = tester.getRect(find.text('Weight Belt'));
      expect(figure.top, greaterThan(list.bottom));
    });

    testWidgets('shows with the model when there are no weights', (
      tester,
    ) async {
      await pump(tester, outcome: buoyancyOutcome(), showWeights: false);
      expect(find.byType(TrimFigure), findsOneWidget);
    });
  });
}
