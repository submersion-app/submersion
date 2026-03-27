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
  });
}
