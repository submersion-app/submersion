import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/pages/nav_customization_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

class _FakeRepo implements AppSettingsRepository {
  List<String>? stored;
  @override
  Future<List<String>?> getNavPrimaryIdsRaw() async => stored;
  @override
  Future<void> setNavPrimaryIds(List<String> ids) async {
    stored = List<String>.from(ids);
  }

  @override
  Future<bool> getShareByDefault() async => false;
  @override
  Future<void> setShareByDefault(bool value) async {}
}

void main() {
  group('applyReorderPreservingDivider', () {
    // Movable items: [a, b, c, d, e, f]; divider sits at dividerIndex=3.
    // Flat list shown to user: [a, b, c, DIVIDER, d, e, f].

    test('drop above divider stays above divider', () {
      // Move 'e' (flat index 5) to position 1 (before 'b')
      final result = applyReorderPreservingDivider(
        movable: const ['a', 'b', 'c', 'd', 'e', 'f'],
        dividerIndex: 3,
        oldIndex: 5,
        newIndex: 1,
      );
      expect(result, ['a', 'e', 'b', 'c', 'd', 'f']);
    });

    test('drop below divider stays below divider', () {
      // Move 'a' (flat index 0) to position 5 (between 'd' and 'e' below divider)
      final result = applyReorderPreservingDivider(
        movable: const ['a', 'b', 'c', 'd', 'e', 'f'],
        dividerIndex: 3,
        oldIndex: 0,
        newIndex: 5,
      );
      expect(result, ['b', 'c', 'd', 'a', 'e', 'f']);
    });

    test('attempting to drag the divider itself is a no-op', () {
      final result = applyReorderPreservingDivider(
        movable: const ['a', 'b', 'c', 'd', 'e', 'f'],
        dividerIndex: 3,
        oldIndex: 3, // divider's position
        newIndex: 1,
      );
      expect(result, ['a', 'b', 'c', 'd', 'e', 'f']);
    });

    test('Flutter-style newIndex > oldIndex accounts for the shift', () {
      // Flutter convention: when moving down, newIndex is post-removal.
      // Move 'a' (0) to just above 'e': newIndex=5 in the flat list means
      // position 4 in the movable list after removal.
      final result = applyReorderPreservingDivider(
        movable: const ['a', 'b', 'c', 'd', 'e', 'f'],
        dividerIndex: 3,
        oldIndex: 0,
        newIndex: 5,
      );
      expect(result, ['b', 'c', 'd', 'a', 'e', 'f']);
    });
  });

  group('NavCustomizationPage widget', () {
    Widget buildHarness(AppSettingsRepository repo) {
      return ProviderScope(
        overrides: [appSettingsRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NavCustomizationPage(),
        ),
      );
    }

    testWidgets('shows pinned Home and More rows', (tester) async {
      final repo = _FakeRepo();
      await tester.pumpWidget(buildHarness(repo));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      // Lock icons render for pinned rows.
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
    });

    testWidgets('shows the divider row with correct label', (tester) async {
      final repo = _FakeRepo();
      await tester.pumpWidget(buildHarness(repo));
      await tester.pumpAndSettle();

      expect(find.text('Items below appear in the More menu'), findsOneWidget);
    });

    testWidgets('Reset button is disabled when list matches defaults', (
      tester,
    ) async {
      final repo = _FakeRepo(); // empty store -> defaults after load
      await tester.pumpWidget(buildHarness(repo));
      await tester.pumpAndSettle();

      final resetButton = find.widgetWithText(TextButton, 'Reset to defaults');
      expect(resetButton, findsOneWidget);
      final button = tester.widget<TextButton>(resetButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('Reset button is enabled after customization', (tester) async {
      final repo = _FakeRepo()..stored = ['equipment', 'buddies', 'statistics'];
      await tester.pumpWidget(buildHarness(repo));
      await tester.pumpAndSettle();

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Reset to defaults'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping Reset restores defaults via the repository', (
      tester,
    ) async {
      final repo = _FakeRepo()..stored = ['equipment', 'buddies', 'statistics'];
      await tester.pumpWidget(buildHarness(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Reset to defaults'));
      await tester.pumpAndSettle();

      expect(repo.stored, kDefaultPrimaryIds);
    });
  });
}
