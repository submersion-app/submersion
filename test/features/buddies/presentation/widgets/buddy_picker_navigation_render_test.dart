import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_picker.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

// Regression coverage for the bug where "Add New Buddy" during bulk dive
// editing pushed a new-buddy screen that rendered underneath the still-open
// dialog/bottom sheet -- the user had to back out twice to see it.
//
// Root cause: bulk-edit opens BuddyPicker inside showDialog (root navigator
// by default); the buddy-selection bottom sheet then also resolves to that
// root navigator. But 'newBuddy' is a GoRoute nested under the app's
// ShellRoute, which -- absent a parentNavigatorKey override -- mounts pages
// on the shell's own nested navigator instead of root. That nested
// navigator's overlay paints underneath the root navigator's, so the new
// page rendered, but hidden behind the still-open dialog/sheet.
//
// The fix (app_router.dart) gives 'newBuddy' `parentNavigatorKey:
// rootNavigatorKey` so it always mounts on the root navigator, matching
// wherever the dialog/sheet actually are.
//
// A go_router push does temporarily elide the dialog/sheet from the render
// tree while BuddyEditPage (fully opaque) covers them -- confirmed via a
// NavigatorObserver to be Flutter's standard "don't paint/build routes
// fully covered by an opaque route" behavior, NOT a pop: the DialogRoute is
// never popped or removed, and reappears with its state intact as soon as
// the covering route is popped. These tests assert on that full round
// trip -- the real proof the fix works, rather than just checking router
// config.

/// Mirrors DiveEditPage._bulkAddBuddies: an AlertDialog hosting BuddyPicker,
/// opened via showDialog's default useRootNavigator: true.
class _BulkAddBuddiesHost extends StatelessWidget {
  const _BulkAddBuddiesHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            var picked = <BuddyWithRole>[];
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                content: SizedBox(
                  width: 400,
                  height: 500,
                  child: StatefulBuilder(
                    builder: (ctx, setSt) => BuddyPicker(
                      selectedBuddies: picked,
                      onChanged: (b) => setSt(() => picked = b),
                    ),
                  ),
                ),
              ),
            );
          },
          child: const Text('Open bulk add buddies'),
        ),
      ),
    );
  }
}

/// Mirrors the single-dive-edit flow: BuddyPicker embedded directly in the
/// page, with no dialog wrapper.
class _EmbeddedPickerHost extends StatefulWidget {
  const _EmbeddedPickerHost();

  @override
  State<_EmbeddedPickerHost> createState() => _EmbeddedPickerHostState();
}

class _EmbeddedPickerHostState extends State<_EmbeddedPickerHost> {
  var _selected = <BuddyWithRole>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BuddyPicker(
        selectedBuddies: _selected,
        onChanged: (b) => setState(() => _selected = b),
      ),
    );
  }
}

void main() {
  late BuddyRepository buddyRepo;
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    buddyRepo = BuddyRepository();

    final diver = await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    await prefs.setString(currentDiverIdKey, diver.id);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // Mirrors the app's real router shape (see app_router.dart): a ShellRoute
  // with a nested navigator, and 'newBuddy' escaping to the root navigator
  // via parentNavigatorKey.
  Widget buildApp(Widget host) {
    final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
    final router = GoRouter(
      navigatorKey: rootKey,
      initialLocation: '/host',
      routes: [
        ShellRoute(
          builder: (context, state, child) => child,
          routes: [
            GoRoute(path: '/host', builder: (context, state) => host),
            GoRoute(
              path: '/buddies',
              builder: (context, state) => const Text('Buddies list'),
              routes: [
                GoRoute(
                  path: 'new',
                  name: 'newBuddy',
                  parentNavigatorKey: rootKey,
                  builder: (context, state) => const BuddyEditPage(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets(
    'Add New Buddy pushed from inside the bulk-edit dialog renders the real '
    'BuddyEditPage on top, and the dialog/sheet reappear intact once it is '
    'saved and popped',
    (tester) async {
      // BuddyEditPage's form is taller than the default 800x600 test
      // surface, so its Save button sits below the fold; widen the surface
      // rather than fight scroll offsets to reach it.
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(buildApp(const _BulkAddBuddiesHost()));
      await tester.pumpAndSettle();

      // Mirrors DiveEditPage._bulkAddBuddies opening the buddies dialog.
      await tester.tap(find.text('Open bulk add buddies'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      // Open the buddy-selection bottom sheet from inside the dialog.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);

      // Tap "Add New Buddy" -- BuddyPicker pushes the real BuddyEditPage.
      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pumpAndSettle();

      // The real proof of the fix: BuddyEditPage is on top and interactive.
      // (The dialog/sheet are elided from the tree while it's on top -- a
      // harmless Flutter optimization for fully-opaque covering routes, not
      // a dismissal -- so they are deliberately not asserted on here.)
      expect(find.byType(BuddyEditPage), findsOneWidget);

      // Complete the round trip: save a new buddy so it pops back via
      // context.pop(savedBuddy), and confirm the dialog/sheet reappear with
      // their original state intact -- proving nothing was lost while
      // covered.
      await tester.enterText(find.byType(TextFormField).first, 'New Diver');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.byType(BuddyEditPage), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(find.text('New Diver'), findsOneWidget);
      expect((await buddyRepo.getAllBuddies()).single.name, 'New Diver');
    },
  );

  testWidgets(
    'Add New Buddy pushed with no dialog involved (single-dive-edit style) '
    'still shows the real BuddyEditPage on top -- the root-navigator fix '
    'does not regress this flow',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(buildApp(const _EmbeddedPickerHost()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pumpAndSettle();

      expect(find.byType(BuddyEditPage), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Another One');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.byType(BuddyEditPage), findsNothing);
      expect((await buddyRepo.getAllBuddies()).single.name, 'Another One');
    },
  );
}
