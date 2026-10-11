import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// A compact card slot can name any [DiveField], but [DiveSummary] carries
/// only a few of them. Fields it lacks (boat, operator, buddy, visibility and
/// the rest) come from the full dive, as they do on the detailed card, so the
/// slot is not left blank (#3229, PR review).
class _PaginatedNotifier
    extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _PaginatedNotifier(List<DiveSummary> dives)
    : super(
        AsyncValue.data(PaginatedDiveListState(dives: dives, hasMore: false)),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CompactConfigNotifier extends CardViewConfigNotifier {
  _CompactConfigNotifier(CardViewConfig config) {
    state = config;
  }
}

void main() {
  final dive = Dive(
    id: 'd1',
    diveNumber: 7,
    dateTime: DateTime(2026, 7, 1, 10),
    maxDepth: 18,
    bottomTime: const Duration(minutes: 40),
    diveOperator: 'Reef Divers',
    boatName: 'Blue Marlin',
  );

  testWidgets('a stat slot shows a field only the full dive carries', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: await getBaseOverrides(),
        child: CompactDiveListTile(
          diveId: dive.id,
          diveNumber: 7,
          dateTime: dive.dateTime,
          summary: DiveSummary.fromDive(dive),
          fullDive: dive,
          titleField: DiveField.diveOperator,
          stat1Field: DiveField.boatName,
        ),
      ),
    );

    expect(find.text('Reef Divers'), findsOneWidget);
    expect(find.textContaining('Blue Marlin'), findsOneWidget);
  });

  testWidgets('an RMV slot follows the diver\'s gas model', (tester) async {
    final tankDive = Dive(
      id: 'd2',
      dateTime: DateTime(2026, 7, 1, 10),
      avgDepth: 18.2,
      runtime: const Duration(minutes: 52),
      tanks: const [
        DiveTank(
          id: 't1',
          volume: 12,
          startPressure: 200,
          endPressure: 50,
          gasMix: GasMix(o2: 32, he: 0),
          role: TankRole.backGas,
        ),
      ],
    );
    const settings = AppSettings(
      hasAcceptedPlanningDisclaimer: true,
      gasModel: GasModel.ideal,
    );
    const units = UnitFormatter(settings);
    final ideal = DiveField.rmv.formatValue(
      tankDive.rmvFor(GasModel.ideal),
      units,
    );
    final real = DiveField.rmv.formatValue(
      tankDive.rmvFor(GasModel.real),
      units,
    );
    expect(ideal, isNot(real), reason: 'the two models must differ here');

    await tester.pumpWidget(
      testApp(
        overrides: await getBaseOverrides(
          settingsNotifier: MockSettingsNotifier(settings),
        ),
        child: CompactDiveListTile(
          diveId: tankDive.id,
          diveNumber: 8,
          dateTime: tankDive.dateTime,
          summary: DiveSummary.fromDive(tankDive),
          fullDive: tankDive,
          stat1Field: DiveField.rmv,
        ),
      ),
    );

    expect(find.textContaining(ideal), findsOneWidget);
  });

  testWidgets('the list loads full dives for a compact slot that needs one', (
    tester,
  ) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.compact),
          highlightedDiveIdProvider.overrideWith((ref) => null),
          paginatedDiveListProvider.overrideWith(
            (ref) => _PaginatedNotifier([DiveSummary.fromDive(dive)]),
          ),
          allDivesForTableProvider.overrideWithValue(AsyncValue.data([dive])),
          compactCardConfigProvider.overrideWith(
            (ref) => _CompactConfigNotifier(
              const CardViewConfig(
                mode: ListViewMode.compact,
                slots: [
                  CardSlotConfig(slotId: 'title', field: DiveField.siteName),
                  CardSlotConfig(slotId: 'date', field: DiveField.dateTime),
                  CardSlotConfig(slotId: 'stat1', field: DiveField.boatName),
                  CardSlotConfig(slotId: 'stat2', field: DiveField.bottomTime),
                ],
              ),
            ),
          ),
        ],
        locale: const Locale('en'),
        child: const DiveListContent(showAppBar: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CompactDiveListTile), findsOneWidget);
    expect(find.textContaining('Blue Marlin'), findsOneWidget);
  });
}
