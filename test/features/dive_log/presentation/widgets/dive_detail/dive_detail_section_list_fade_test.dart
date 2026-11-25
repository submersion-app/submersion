import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';
import 'dive_detail_section_list_harness.dart';

class _Settings extends StateNotifier<AppSettings> implements SettingsNotifier {
  _Settings(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Cards with nothing to edit fade while the dive is unlocked, and say why
/// (issue #4527, plan 6).
void main() {
  final dive = createTestDiveWithBottomTime().copyWith(
    tanks: const [DiveTank(id: 't1', volume: 12.0, startPressure: 200)],
    profile: [
      for (var i = 0; i <= 10; i++)
        DiveProfilePoint(timestamp: i * 60, depth: i < 5 ? i * 4.0 : 18.0),
    ],
    weightAmount: 6,
  );

  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Widget harness({
    RecordEditController<Dive>? controller,
    DiveDetailSectionId visible = DiveDetailSectionId.decoStatus,
  }) {
    final list = sectionListFor(dive);
    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _Settings(
            AppSettings(
              diveDetailSections: [
                for (final id in DiveDetailSectionId.values)
                  DiveDetailSectionConfig(id: id, visible: id == visible),
              ],
            ),
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: controller == null
                ? list
                : RecordEditScope<Dive>(controller: controller, child: list),
          ),
        ),
      ),
    );
  }

  test('the four calculated and two imported cards, and no other', () {
    expect(
      {
        for (final id in DiveDetailSectionId.values)
          id: ?diveCardFadeReason(id),
      },
      {
        DiveDetailSectionId.decoStatus: RecordCardFadeReason.calculated,
        DiveDetailSectionId.tissueLoading: RecordCardFadeReason.calculated,
        DiveDetailSectionId.sacSegments: RecordCardFadeReason.calculated,
        DiveDetailSectionId.tide: RecordCardFadeReason.calculated,
        DiveDetailSectionId.health: RecordCardFadeReason.imported,
        DiveDetailSectionId.surfaceGps: RecordCardFadeReason.imported,
      },
    );
  });

  testWidgets('editing off: no fade anywhere', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(RecordCardFade<Dive>),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
    expect(find.text('Calculated'), findsNothing);
  });

  testWidgets(
    'unlocked: a calculated card says Calculated, and does not move or '
    'change height',
    (tester) async {
      final controller = RecordEditController<Dive>(onSave: (_) async {});
      addTearDown(controller.dispose);
      await tester.pumpWidget(harness(controller: controller));
      await tester.pumpAndSettle();
      final section = find.byKey(const ValueKey('diveSection_decoStatus'));
      expect(section, findsOneWidget);
      final before = tester.getRect(section);
      expect(find.text('Calculated'), findsNothing);

      controller.unlock(dive);
      await tester.pumpAndSettle();

      expect(find.text('Calculated'), findsOneWidget);
      expect(tester.getRect(section), before);
    },
  );

  testWidgets('unlocked: the Weights and buoyancy card does not fade', (
    tester,
  ) async {
    // It holds the weights editor, so it is not a calculated card even
    // though the buoyancy model inside it is (issue #5005).
    final controller = RecordEditController<Dive>(onSave: (_) async {});
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(controller: controller, visible: DiveDetailSectionId.weights),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('diveSection_weights')), findsOneWidget);

    controller.unlock(dive);
    await tester.pumpAndSettle();

    expect(find.text('Calculated'), findsNothing);
    expect(find.byType(RecordCardFade<Dive>), findsNothing);
  });
}
