import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/settings/presentation/pages/section_appearance_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Mock SettingsNotifier that doesn't access the database
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setDiveListViewMode(ListViewMode mode) async =>
      state = state.copyWith(diveListViewMode: mode);

  @override
  Future<void> setSiteListViewMode(ListViewMode mode) async =>
      state = state.copyWith(siteListViewMode: mode);

  @override
  Future<void> setTripListViewMode(ListViewMode mode) async =>
      state = state.copyWith(tripListViewMode: mode);

  @override
  Future<void> setEquipmentListViewMode(ListViewMode mode) async =>
      state = state.copyWith(equipmentListViewMode: mode);

  @override
  Future<void> setBuddyListViewMode(ListViewMode mode) async =>
      state = state.copyWith(buddyListViewMode: mode);

  @override
  Future<void> setDiveCenterListViewMode(ListViewMode mode) async =>
      state = state.copyWith(diveCenterListViewMode: mode);

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

Widget _buildTestWidget(String sectionKey, {bool embedded = false}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionAppearancePage(sectionKey: sectionKey, embedded: embedded),
    ),
  );
}

void main() {
  group('SectionAppearancePage - Dives section', () {
    testWidgets('shows all 5 section headers and dive-specific settings', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('dives'));
      await tester.pumpAndSettle();

      // 5 section headers: List View, Cards, Table Mode, Dive Profile,
      // Dive Details
      expect(find.text('List View'), findsOneWidget);
      expect(find.text('Cards'), findsOneWidget);
      expect(find.text('Table Mode'), findsOneWidget);
      expect(find.text('Dive Profile'), findsOneWidget);
      expect(find.text('Dive Details'), findsOneWidget);

      // Dive-specific settings
      expect(find.text('Show Profile Panel in Table View'), findsOneWidget);
      expect(find.text('Show data source badges'), findsOneWidget);
    });
  });

  group('SectionAppearancePage - Sites section', () {
    testWidgets(
      'shows List View, Cards, Table Mode but NOT Dive Profile or Dive Details',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 4000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_buildTestWidget('sites'));
        await tester.pumpAndSettle();

        expect(find.text('List View'), findsOneWidget);
        expect(find.text('Cards'), findsOneWidget);
        expect(find.text('Table Mode'), findsOneWidget);

        // Should NOT have dive-specific sections
        expect(find.text('Dive Profile'), findsNothing);
        expect(find.text('Dive Details'), findsNothing);
      },
    );
  });

  group('SectionAppearancePage - Buddies section', () {
    testWidgets('shows List View and Table Mode only (no Cards)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('buddies'));
      await tester.pumpAndSettle();

      expect(find.text('List View'), findsOneWidget);
      expect(find.text('Table Mode'), findsOneWidget);

      // No Cards section for buddies
      expect(find.text('Cards'), findsNothing);
    });
  });

  group('SectionAppearancePage - Certifications section', () {
    testWidgets('shows View Mode and List Fields', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('certifications'));
      await tester.pumpAndSettle();

      // Should have the View Mode dropdown
      expect(find.text('List View'), findsOneWidget);
      expect(find.byType(DropdownButton<ListViewMode>), findsOneWidget);

      // Should have the list fields navigation tile
      expect(find.text('Certification List Fields'), findsOneWidget);
    });
  });

  group('SectionAppearancePage - Embedded mode', () {
    testWidgets('omits Scaffold AppBar when embedded', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('dives', embedded: true));
      await tester.pumpAndSettle();

      // In embedded mode, there should be no AppBar
      expect(find.byType(AppBar), findsNothing);

      // But the content should still be present
      expect(find.text('List View'), findsOneWidget);
    });
  });
}
