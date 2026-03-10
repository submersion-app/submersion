import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_legend.dart';

import '../../../../helpers/test_app.dart';

/// Minimal [SettingsNotifier] stub that returns default [AppSettings].
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DiveProfileLegend - primary toggles', () {
    testWidgets('shows Events toggle when hasEvents is true', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DiveProfileLegend(
            config: const ProfileLegendConfig(
              hasTemperatureData: true,
              hasEvents: true,
              hasCeilingCurve: true,
            ),
            zoomLevel: 1.0,
            onZoomIn: () {},
            onZoomOut: () {},
            onResetZoom: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Events should be in the primary legend
      expect(find.text('Events'), findsOneWidget);
    });

    testWidgets(
      'does NOT show Ceiling in primary legend even when data available',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            overrides: [
              settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            ],
            child: DiveProfileLegend(
              config: const ProfileLegendConfig(
                hasCeilingCurve: true,
                hasEvents: true,
              ),
              zoomLevel: 1.0,
              onZoomIn: () {},
              onZoomOut: () {},
              onResetZoom: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Events should appear, Ceiling should NOT (it moved to dialog)
        expect(find.text('Events'), findsOneWidget);
        expect(find.text('Ceiling'), findsNothing);
        expect(find.text('Ceiling (DC)'), findsNothing);
        expect(find.text('Ceiling (Calc)'), findsNothing);
        expect(find.text('Ceiling (Calc*)'), findsNothing);
      },
    );
  });
}
