import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/appearance_page.dart';
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
      home: AppearancePage(),
    ),
  );
}

void main() {
  group('AppearancePage dive detail sections', () {
    testWidgets('shows Dive Details section header', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Dive Details'), findsOneWidget);
    });

    testWidgets('shows Section Order & Visibility tile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Section Order & Visibility'), findsOneWidget);
      expect(
        find.text('Choose which sections appear and their order'),
        findsOneWidget,
      );
    });

    testWidgets('shows reorder icon on dive details tile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.reorder), findsOneWidget);
    });
  });

  group('AppearancePage details pane toggles', () {
    testWidgets('shows details pane toggle header', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Show details pane in table mode'), findsOneWidget);
    });

    testWidgets('shows toggle tiles for all 8 entity sections', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // All 8 section labels should be present as SwitchListTile titles
      // Note: some of these labels may also appear elsewhere in the page
      // (e.g., 'Dive Sites' as a section header) so we check for the
      // specific toggle tiles by finding SwitchListTile widgets.
      final switchTiles = find.byType(SwitchListTile);
      expect(switchTiles, findsAtLeastNWidgets(8));

      // Verify each section label is present somewhere on the page
      for (final label in [
        'Dives',
        'Sites',
        'Buddies',
        'Trips',
        'Equipment',
        'Dive Centers',
        'Certifications',
        'Courses',
      ]) {
        expect(find.text(label), findsAtLeastNWidgets(1));
      }
    });
  });
}
