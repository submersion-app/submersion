import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_list_page.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void _setMobileTestSurfaceSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _MockBuddyListNotifier extends StateNotifier<AsyncValue<List<Buddy>>>
    implements BuddyListNotifier {
  _MockBuddyListNotifier(AsyncValue<List<Buddy>> state) : super(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<List<Override>> _buildOverrides({
  List<BuddyWithDiveCount> buddies = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    allBuddiesWithDiveCountProvider.overrideWith((ref) => buddies),
    buddyListNotifierProvider.overrideWith(
      (ref) => _MockBuddyListNotifier(
        AsyncValue.data(buddies.map((b) => b.buddy).toList()),
      ),
    ),
    buddyListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
  ];
}

void main() {
  group('BuddyListPage', () {
    testWidgets('shows Buddies title in app bar', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BuddyListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Buddies'), findsOneWidget);
    });

    testWidgets('shows Add Buddy FAB', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BuddyListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add Buddy'), findsOneWidget);
    });

    testWidgets('shows empty state when no buddies', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BuddyListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No dive buddies yet'), findsOneWidget);
    });

    testWidgets('shows loading indicator while loading', (tester) async {
      _setMobileTestSurfaceSize(tester);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            allBuddiesWithDiveCountProvider.overrideWith(
              (ref) async {
                await Future.delayed(const Duration(days: 1));
                return <BuddyWithDiveCount>[];
              },
            ),
            buddyListNotifierProvider.overrideWith(
              (ref) =>
                  _MockBuddyListNotifier(const AsyncValue.loading()),
            ),
            buddyListViewModeProvider.overrideWith(
              (ref) => ListViewMode.detailed,
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BuddyListPage(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows buddy names when data loaded', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final now = DateTime.now();
      final testBuddies = [
        BuddyWithDiveCount(
          buddy: Buddy(
            id: '1',
            name: 'Alice Smith',
            notes: '',
            createdAt: now,
            updatedAt: now,
          ),
          diveCount: 5,
        ),
        BuddyWithDiveCount(
          buddy: Buddy(
            id: '2',
            name: 'Bob Jones',
            notes: '',
            createdAt: now,
            updatedAt: now,
          ),
          diveCount: 10,
        ),
      ];
      final overrides = await _buildOverrides(buddies: testBuddies);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BuddyListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Bob Jones'), findsOneWidget);
    });
  });
}
