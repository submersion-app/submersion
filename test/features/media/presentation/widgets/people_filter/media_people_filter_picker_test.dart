import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/widgets/people_filter/media_people_filter_picker.dart';
import 'package:submersion/features/media/presentation/widgets/people_filter/media_people_selection.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The People picker of the library filter: a searchable multi-select list
/// that holds hundreds of tagged buddies (issue #4148).
void main() {
  final now = DateTime(2026);
  Buddy buddy(String id, String name) =>
      Buddy(id: id, name: name, createdAt: now, updatedAt: now);
  final alex = buddy('alex', 'Alex');
  final bea = buddy('bea', 'Bea');
  final cal = buddy('cal', 'Cal');
  final zoe = buddy('zoe', 'Zoe');

  Finder buddyRow(String id) =>
      find.byKey(ValueKey('media_people_pick_buddy_$id'));

  /// The pinned rows by name (`none`, `me`), any other key a buddy id.
  Finder row(String key) => key == 'none' || key == 'me'
      ? find.byKey(ValueKey('media_people_pick_$key'))
      : buddyRow(key);
  bool ticked(WidgetTester tester, String key) =>
      tester.widget<CheckboxListTile>(row(key)).value ?? false;

  /// Opens the picker on [initial]; the returned future completes with what
  /// the picker returned once it closes.
  Future<Future<MediaPeopleSelection?>> open(
    WidgetTester tester, {
    MediaPeopleSelection initial = MediaPeopleSelection.none,
    FutureOr<List<Buddy>> Function()? buddies,
    Set<String> tagged = const {'alex', 'bea', 'zoe'},
    Future<Set<String>>? taggedLater,
    // Off while a list is pending: the progress bar never settles.
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    late Future<MediaPeopleSelection?> result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allBuddiesProvider.overrideWith(
            (ref) async => await (buddies?.call() ?? [zoe, bea, alex, cal]),
          ),
          taggedBuddyIdsProvider.overrideWith(
            (ref) async => await (taggedLater ?? Future.value(tagged)),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => result = showMediaPeopleFilterPicker(
                  context,
                  initial: initial,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
    return result;
  }

  Future<void> done(WidgetTester tester) async {
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  }

  double y(WidgetTester tester, String key) => tester.getTopLeft(row(key)).dy;

  testWidgets('lists "No one tagged", Me, then tagged buddies by name', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('No one tagged'), findsOneWidget);
    expect(y(tester, 'none'), lessThan(y(tester, 'me')));
    expect(y(tester, 'me'), lessThan(y(tester, 'alex')));
    expect(y(tester, 'alex'), lessThan(y(tester, 'bea')));
    expect(y(tester, 'bea'), lessThan(y(tester, 'zoe')));
  });

  testWidgets('a buddy never tagged is not offered', (tester) async {
    await open(tester);
    expect(row('cal'), findsNothing);
  });

  testWidgets('people already picked come first, ticked', (tester) async {
    await open(tester, initial: const MediaPeopleSelection(buddyIds: {'zoe'}));
    expect(ticked(tester, 'zoe'), isTrue);
    expect(y(tester, 'me'), lessThan(y(tester, 'zoe')));
    expect(y(tester, 'zoe'), lessThan(y(tester, 'alex')));
  });

  testWidgets('a row does not jump when it is ticked', (tester) async {
    await open(tester);
    final before = y(tester, 'zoe');
    await tester.tap(row('zoe'));
    await tester.pumpAndSettle();
    expect(ticked(tester, 'zoe'), isTrue);
    expect(y(tester, 'zoe'), before);
  });

  testWidgets('Done returns the ticks', (tester) async {
    final result = await open(tester);
    await tester.tap(row('me'));
    await tester.tap(row('bea'));
    await tester.pumpAndSettle();
    await done(tester);
    expect(
      await result,
      const MediaPeopleSelection(includeMe: true, buddyIds: {'bea'}),
    );
  });

  testWidgets('dismissing returns nothing', (tester) async {
    final result = await open(tester);
    await tester.tap(row('bea'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('"No one tagged" and a person exclude each other', (
    tester,
  ) async {
    final result = await open(
      tester,
      initial: const MediaPeopleSelection(includeMe: true, buddyIds: {'alex'}),
    );
    await tester.tap(row('none'));
    await tester.pumpAndSettle();
    expect(ticked(tester, 'none'), isTrue);
    expect(ticked(tester, 'me'), isFalse);
    expect(ticked(tester, 'alex'), isFalse);

    await tester.tap(row('bea'));
    await tester.pumpAndSettle();
    expect(ticked(tester, 'none'), isFalse);
    await done(tester);
    expect(await result, const MediaPeopleSelection(buddyIds: {'bea'}));
  });

  group('search', () {
    testWidgets('narrows the list by name, ignoring case', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'ZO');
      await tester.pumpAndSettle();
      expect(row('zoe'), findsOneWidget);
      expect(row('alex'), findsNothing);
      expect(row('bea'), findsNothing);
      expect(row('none'), findsNothing);
      expect(row('me'), findsNothing);
    });

    testWidgets('keeps Me when it matches', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'me');
      await tester.pumpAndSettle();
      expect(row('me'), findsOneWidget);
    });

    testWidgets('keeps the ticks made before and after it', (tester) async {
      final result = await open(tester);
      await tester.tap(row('alex'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zoe');
      await tester.pumpAndSettle();
      await tester.tap(row('zoe'));
      await tester.pumpAndSettle();
      await done(tester);
      expect(
        await result,
        const MediaPeopleSelection(buddyIds: {'alex', 'zoe'}),
      );
    });

    testWidgets('says so when nobody matches', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'qqq');
      await tester.pumpAndSettle();
      expect(find.text('No people match'), findsOneWidget);
    });
  });

  group('while the people are still loading', () {
    testWidgets('shows progress, never that nobody matches', (tester) async {
      final pending = Completer<Set<String>>();
      await open(tester, taggedLater: pending.future, settle: false);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zoe');
      await tester.pump();
      expect(find.text('No people match'), findsNothing);

      pending.complete({'zoe'});
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(row('zoe'), findsOneWidget);
    });
  });

  testWidgets('a buddy whose id reads "me" is still a buddy', (tester) async {
    final result = await open(
      tester,
      buddies: () => [buddy('me', 'Mel'), buddy('none', 'Nell')],
      tagged: {'me', 'none'},
    );
    // Each pinned row and each buddy row is its own row, never a pair
    // sharing one key.
    expect(row('me'), findsOneWidget);
    expect(row('none'), findsOneWidget);
    expect(buddyRow('me'), findsOneWidget);
    expect(buddyRow('none'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(4));

    await tester.tap(buddyRow('me'));
    await tester.pumpAndSettle();
    await done(tester);
    expect(await result, const MediaPeopleSelection(buddyIds: {'me'}));
  });

  group('a buddy picked but since deleted', () {
    testWidgets('reads as removed and can be unticked', (tester) async {
      final result = await open(
        tester,
        initial: const MediaPeopleSelection(buddyIds: {'gone', 'alex'}),
      );
      expect(find.text('Removed buddy'), findsOneWidget);
      expect(ticked(tester, 'gone'), isTrue);
      await tester.tap(row('gone'));
      await tester.pumpAndSettle();
      await done(tester);
      expect(await result, const MediaPeopleSelection(buddyIds: {'alex'}));
    });

    testWidgets('is not called removed while the buddies load', (tester) async {
      final pending = Completer<List<Buddy>>();
      await open(
        tester,
        initial: const MediaPeopleSelection(buddyIds: {'alex'}),
        buddies: () => pending.future,
        settle: false,
      );
      expect(find.text('Removed buddy'), findsNothing);
    });
  });

  group('with hundreds of tagged buddies', () {
    final many = [
      for (var i = 0; i < 500; i++)
        buddy('b$i', 'Buddy ${i.toString().padLeft(3, '0')}'),
    ];

    testWidgets('builds only the rows on screen', (tester) async {
      await open(
        tester,
        buddies: () => many,
        tagged: {for (final b in many) b.id},
      );
      expect(row('b0'), findsOneWidget);
      expect(find.byType(CheckboxListTile).evaluate().length, lessThan(100));
    });

    testWidgets('search reaches a buddy far down the list', (tester) async {
      final result = await open(
        tester,
        buddies: () => many,
        tagged: {for (final b in many) b.id},
      );
      expect(row('b487'), findsNothing);
      await tester.enterText(find.byType(TextField), '487');
      await tester.pumpAndSettle();
      await tester.tap(row('b487'));
      await tester.pumpAndSettle();
      await done(tester);
      expect(await result, const MediaPeopleSelection(buddyIds: {'b487'}));
    });
  });
}
