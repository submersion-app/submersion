import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

Widget _harness(
  Widget child, {
  bool navOn = false,
  bool headerOn = false,
  bool listOn = false,
  Brightness brightness = Brightness.light,
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(
        (ref) => _StubSettingsNotifier(
          AppSettings(
            accentNavIcons: navOn,
            accentSectionHeaders: headerOn,
            accentListIcons: listOn,
          ),
        ),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        extensions: <ThemeExtension<dynamic>>[
          brightness == Brightness.light
              ? FeatureAccentColors.light
              : FeatureAccentColors.dark,
        ],
      ),
      home: Scaffold(body: child),
    ),
  );
}

class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('FeatureAccentIcon', () {
    testWidgets('uses the accent color when its surface toggle is on', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const FeatureAccentIcon(
            Icons.backpack,
            featureId: 'equipment',
            surface: AccentSurface.list,
          ),
          listOn: true,
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.backpack));
      expect(icon.color, FeatureAccentColors.light.of('equipment'));
    });

    testWidgets('falls back to the ambient color when the toggle is off', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const FeatureAccentIcon(
            Icons.backpack,
            featureId: 'equipment',
            surface: AccentSurface.list,
          ),
        ),
      );

      expect(tester.widget<Icon>(find.byIcon(Icons.backpack)).color, isNull);
    });

    testWidgets('falls back for an unknown feature id', (tester) async {
      await tester.pumpWidget(
        _harness(
          const FeatureAccentIcon(
            Icons.backpack,
            featureId: 'nonexistent',
            surface: AccentSurface.list,
          ),
          listOn: true,
        ),
      );

      expect(tester.widget<Icon>(find.byIcon(Icons.backpack)).color, isNull);
    });

    testWidgets('each surface is gated by its own toggle', (tester) async {
      // The list toggle must not colour a nav-surface icon.
      await tester.pumpWidget(
        _harness(
          const FeatureAccentIcon(
            Icons.backpack,
            featureId: 'equipment',
            surface: AccentSurface.nav,
          ),
          listOn: true,
        ),
      );

      expect(tester.widget<Icon>(find.byIcon(Icons.backpack)).color, isNull);
    });

    testWidgets('resolves against the dark palette in dark mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const FeatureAccentIcon(
            Icons.backpack,
            featureId: 'equipment',
            surface: AccentSurface.list,
          ),
          listOn: true,
          brightness: Brightness.dark,
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.backpack));
      expect(icon.color, FeatureAccentColors.dark.of('equipment'));
      expect(icon.color, isNot(FeatureAccentColors.light.of('equipment')));
    });

    testWidgets('falls back when no accent extension is registered', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => _StubSettingsNotifier(
                const AppSettings(accentListIcons: true),
              ),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.light),
            home: const Scaffold(
              body: FeatureAccentIcon(
                Icons.backpack,
                featureId: 'equipment',
                surface: AccentSurface.list,
              ),
            ),
          ),
        ),
      );

      expect(tester.widget<Icon>(find.byIcon(Icons.backpack)).color, isNull);
    });
  });

  group('FeatureAppBarTitle', () {
    testWidgets('is text-only when the header toggle is off', (tester) async {
      await tester.pumpWidget(
        _harness(const FeatureAppBarTitle(featureId: 'dives', title: 'Dives')),
      );

      expect(find.text('Dives'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('shows the tinted feature icon when the toggle is on', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const FeatureAppBarTitle(featureId: 'dives', title: 'Dives'),
          headerOn: true,
        ),
      );

      expect(find.text('Dives'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.scuba_diving);
      expect(icon.color, FeatureAccentColors.light.of('dives'));
    });

    testWidgets('stays text-only for an id with no nav destination', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const FeatureAppBarTitle(featureId: 'nonexistent', title: 'Other'),
          headerOn: true,
        ),
      );

      expect(find.text('Other'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });
  });
}
