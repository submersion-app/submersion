import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/dive_detail_sections_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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

Widget _buildTestWidget() {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
    ],
    child: const MaterialApp(home: DiveDetailSectionsPage()),
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
