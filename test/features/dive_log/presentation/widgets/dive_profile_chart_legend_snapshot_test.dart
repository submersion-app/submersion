import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/info/dive_profile_info.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The chart publishes the overlays it draws for the card header's info
/// icon, and takes them back when it stops drawing a profile.
void main() {
  final profile = List.generate(
    10,
    (i) => DiveProfilePoint(
      timestamp: i * 30,
      depth: i < 5 ? i * 3.0 : (10 - i) * 3.0,
    ),
  );

  late ProfileLegendSnapshot? snapshot;

  Future<void> pumpChart(
    WidgetTester tester,
    List<DiveProfilePoint> points,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProfileLegendSnapshotScope(
              child: Builder(
                builder: (context) {
                  snapshot = ProfileLegendSnapshotScope.maybeOf(context);
                  return SizedBox(
                    width: 400,
                    height: 300,
                    child: DiveProfileChart(profile: points),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a chart drawing a profile publishes its legend', (tester) async {
    await pumpChart(tester, profile);

    expect(snapshot?.config, isNotNull);
  });

  testWidgets('a chart left with no profile takes its legend back', (
    tester,
  ) async {
    await pumpChart(tester, profile);
    // Same chart, now drawing nothing: a source with no samples.
    await pumpChart(tester, const []);

    expect(snapshot?.config, isNull);
  });
}
