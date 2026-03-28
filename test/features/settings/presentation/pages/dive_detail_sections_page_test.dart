import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/dive_detail_sections_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Mock SettingsNotifier that doesn't access the database
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setDiveDetailSections(
    List<DiveDetailSectionConfig> sections,
  ) async => state = state.copyWith(diveDetailSections: sections);

  @override
  Future<void> resetDiveDetailSections() async =>
      state = state.copyWith(clearDiveDetailSections: true);

  // Stub remaining SettingsNotifier methods
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock with custom initial sections for testing custom order
class _MockSettingsNotifierWithSections extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifierWithSections(List<DiveDetailSectionConfig> sections)
    : super(AppSettings(diveDetailSections: sections));

  @override
  Future<void> setDiveDetailSections(
    List<DiveDetailSectionConfig> sections,
  ) async => state = state.copyWith(diveDetailSections: sections);

  @override
  Future<void> resetDiveDetailSections() async =>
      state = state.copyWith(clearDiveDetailSections: true);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildTestWidget() {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DiveDetailSectionsPage(),
    ),
  );
}

void main() {
  group('DiveDetailSectionsPage', () {
    testWidgets('renders all 17 section names', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      for (final id in DiveDetailSectionId.values) {
        expect(find.text(id.displayName), findsOneWidget);
      }
    });

    testWidgets('renders 17 switches', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsNWidgets(17));
    });

    testWidgets('renders drag handles', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.drag_handle), findsNWidgets(17));
    });

    testWidgets('shows fixed sections note', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Header'), findsOneWidget);
      expect(find.textContaining('Dive Profile'), findsOneWidget);
    });

    testWidgets('all switches are initially on', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      final switches = tester.widgetList<Switch>(find.byType(Switch));
      for (final s in switches) {
        expect(s.value, true);
      }
    });

    testWidgets('toggling a switch updates section visibility', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // Find the first switch and tap it off
      final firstSwitch = find.byType(Switch).first;
      await tester.tap(firstSwitch);
      await tester.pumpAndSettle();

      // After toggling, the first switch should now be off
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[0].value, false);
      // Others remain on
      expect(switches[1].value, true);
    });

    testWidgets('hidden section has reduced opacity', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // Toggle first section off
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      // Find AnimatedOpacity widgets
      final opacities = tester.widgetList<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      final opacityList = opacities.toList();
      // First section should be dimmed
      expect(opacityList[0].opacity, 0.5);
      // Second section should be full opacity
      expect(opacityList[1].opacity, 1.0);
    });

    testWidgets('reset to default restores all sections visible', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // Toggle first section off
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      // Verify it's off
      var switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[0].value, false);

      // Tap the overflow menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Tap "Reset to Default"
      await tester.tap(find.text('Reset to Default'));
      await tester.pumpAndSettle();

      // All switches should be back on
      switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      for (final s in switches) {
        expect(s.value, true);
      }
    });

    testWidgets('toggling switch back on restores full opacity', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // Toggle off
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .first
            .opacity,
        0.5,
      );

      // Toggle back on
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .first
            .opacity,
        1.0,
      );

      // Switch should be on again
      expect(tester.widgetList<Switch>(find.byType(Switch)).first.value, true);
    });

    testWidgets('multiple sections can be toggled off independently', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // Toggle first and third switches off
      final switches = find.byType(Switch);
      await tester.tap(switches.at(0));
      await tester.pumpAndSettle();
      await tester.tap(switches.at(2));
      await tester.pumpAndSettle();

      final switchList = tester
          .widgetList<Switch>(find.byType(Switch))
          .toList();
      expect(switchList[0].value, false);
      expect(switchList[1].value, true);
      expect(switchList[2].value, false);
      expect(switchList[3].value, true);
    });

    testWidgets('overflow menu button is present', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    testWidgets('shows configurable sections subheading', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.text('Configurable sections (drag to reorder)'),
        findsOneWidget,
      );
    });

    testWidgets('sections render with custom initial order', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Create a custom order: tanks first, then decoO2
      final customSections = [
        const DiveDetailSectionConfig(
          id: DiveDetailSectionId.tanks,
          visible: true,
        ),
        const DiveDetailSectionConfig(
          id: DiveDetailSectionId.decoO2,
          visible: false,
        ),
        ...DiveDetailSectionId.values
            .where(
              (id) =>
                  id != DiveDetailSectionId.tanks &&
                  id != DiveDetailSectionId.decoO2,
            )
            .map((id) => DiveDetailSectionConfig(id: id, visible: true)),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => _MockSettingsNotifierWithSections(customSections),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiveDetailSectionsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First section should be Tanks, second should be Deco Status
      final titles = tester.widgetList<Text>(
        find.descendant(of: find.byType(ListTile), matching: find.byType(Text)),
      );
      // Find display names in order
      final displayNames = titles
          .map((t) => t.data)
          .where(
            (d) =>
                d != null &&
                DiveDetailSectionId.values.any((id) => id.displayName == d),
          )
          .toList();
      expect(displayNames.first, 'Tanks');
    });

    testWidgets('shows app bar title', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Section Order & Visibility'), findsOneWidget);
    });

    testWidgets('shows section descriptions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      for (final id in DiveDetailSectionId.values) {
        expect(find.text(id.description), findsOneWidget);
      }
    });
  });
}
