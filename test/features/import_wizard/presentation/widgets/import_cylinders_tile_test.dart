import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/features/equipment/domain/services/tank_cylinder_matching.dart';
import 'package:submersion/features/equipment/presentation/providers/cylinder_proposal_providers.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/import_cylinders_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  const ids = ['a', 'b'];

  Future<void> pumpTile(
    WidgetTester tester,
    List<CylinderProposal> proposals,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      testApp(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          importCylinderProposalsProvider(
            const ImportedDiveIds(ids),
          ).overrideWith((ref) async => proposals),
        ],
        child: const ImportCylindersTile(importedDiveIds: ids),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('counts the unmatched tanks and opens the review', (
    tester,
  ) async {
    final proposals = proposeCylinders(
      [
        for (final d in ids)
          TankRef(
            diveId: d,
            tank: DiveTank(id: 't-$d', volume: 11.1),
          ),
      ],
      owned: const [],
      ownedPairs: const [],
    );
    await pumpTile(tester, proposals);

    expect(find.text("2 tanks aren't in your gear"), findsOneWidget);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Add cylinders to your gear'), findsOneWidget);
  });

  testWidgets('shows nothing when every tank is in the gear', (tester) async {
    await pumpTile(tester, const []);
    expect(find.byKey(const Key('import_summary_cylinders')), findsNothing);
  });
}
