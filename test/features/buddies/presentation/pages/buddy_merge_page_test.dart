import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_routes.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_merge_page.dart';
import 'package:submersion/features/buddies/presentation/widgets/linked_profile_field.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Buddy merge has a page of its own (issue #4527, phase 3), holding only
/// what a merge uses.
void main() {
  final l = AppLocalizationsEn();
  late SharedPreferences prefs;
  late String ownerId;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    ownerId = (await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    )).id;
    await prefs.setString(currentDiverIdKey, ownerId);
  });
  tearDown(() async => tearDownTestDatabase());

  Future<Buddy> buddy(
    String name, {
    String? email,
    String? phone,
    String? country,
    String? socialHandle,
    String notes = '',
    String? linkedDiverId,
  }) => BuddyRepository().createBuddy(
    Buddy(
      id: '',
      diverId: ownerId,
      name: name,
      email: email,
      phone: phone,
      country: country,
      socialHandle: socialHandle,
      notes: notes,
      linkedDiverId: linkedDiverId,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    ),
  );

  Future<Diver> diver(String name) => DiverRepository().createDiver(
    Diver(
      id: '',
      name: name,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    ),
  );

  /// Pushes the merge of [buddies] over a home page, so it can pop its
  /// result; [results] collects what it pops.
  Future<void> pumpMerge(
    WidgetTester tester,
    List<Buddy> buddies, {
    List<Object?>? results,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 2000);
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final result = await context.push<Object?>('/merge');
                  results?.add(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/merge',
          builder: (context, state) => BuddyMergeForm(buddies: buddies),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  String textOf(WidgetTester tester, String label) => tester
      .widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, label),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  Future<void> cycle(WidgetTester tester, String label) async {
    final field = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(field);
    await tester.tap(
      find.descendant(of: field, matching: find.byIcon(Icons.sync_alt)),
    );
    await tester.pumpAndSettle();
  }

  /// Runs [action] for real, pumping until [done] or a second has passed:
  /// the merge waits on the database.
  Future<void> drive(
    WidgetTester tester,
    Future<void> Function() action,
    bool Function() done,
  ) => tester.runAsync(() async {
    await action();
    for (var i = 0; i < 50 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
    }
  });

  Finder confirmMerge() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, l.buddies_edit_merge_title),
  );

  testWidgets('the merge page cycles each text field', (tester) async {
    final buddies = await tester.runAsync(
      () async => [
        await buddy(
          'Marco',
          email: 'm@a.it',
          phone: '1',
          country: 'Italy',
          notes: 'First',
        ),
        await buddy(
          'M.',
          email: 'm@b.it',
          phone: '2',
          country: 'Malta',
          notes: 'Second',
        ),
      ],
    );
    await pumpMerge(tester, buddies!);

    for (final (label, first, second) in [
      (l.buddies_field_nameRequired, 'Marco', 'M.'),
      (l.buddies_field_email, 'm@a.it', 'm@b.it'),
      (l.buddies_field_phone, '1', '2'),
      (l.buddies_field_country, 'Italy', 'Malta'),
      (l.buddies_field_notes, 'First', 'Second'),
    ]) {
      expect(textOf(tester, label), first, reason: label);
      await cycle(tester, label);
      expect(textOf(tester, label), second, reason: label);
    }
  });

  testWidgets('the merge starts with a social handle one of them has', (
    tester,
  ) async {
    final buddies = await tester.runAsync(
      () async => [
        await buddy('Alice'),
        await buddy('Alice', socialHandle: '@alice'),
      ],
    );
    await pumpMerge(tester, buddies!);

    expect(textOf(tester, l.buddyShare_social), '@alice');
  });

  testWidgets('merging confirms, merges and pops the result', (tester) async {
    final buddies = await tester.runAsync(
      () async => [await buddy('Marco'), await buddy('M.')],
    );
    final results = <Object?>[];
    await pumpMerge(tester, buddies!, results: results);

    await drive(
      tester,
      () => tester.tap(find.text(l.common_action_save)),
      () => confirmMerge().evaluate().isNotEmpty,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    await drive(
      tester,
      () => tester.tap(confirmMerge()),
      () => results.isNotEmpty,
    );
    await tester.pumpAndSettle();

    final result = results.single as BuddyMergeResult;
    expect(result.survivorId, buddies.first.id);
    final left = await tester.runAsync(
      () => BuddyRepository().getBuddyById(buddies.last.id),
    );
    expect(left, isNull);
  });

  testWidgets('different linked profiles are refused', (tester) async {
    final buddies = await tester.runAsync(() async {
      final a = await diver('A');
      final b = await diver('B');
      return [
        await buddy('Marco', linkedDiverId: a.id),
        await buddy('M.', linkedDiverId: b.id),
      ];
    });
    await pumpMerge(tester, buddies!);

    await drive(
      tester,
      () => tester.tap(find.text(l.common_action_save)),
      () => confirmMerge().evaluate().isNotEmpty,
    );
    await drive(
      tester,
      () => tester.tap(confirmMerge()),
      () => find
          .text(l.buddies_merge_refusedDifferentLinks)
          .evaluate()
          .isNotEmpty,
    );
    expect(find.text(l.buddies_merge_refusedDifferentLinks), findsOneWidget);
    // A refused merge changed nothing: leaving asks nothing.
    await tester.tap(find.text(l.common_action_cancel));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BuddyMergeForm), findsNothing);
    final both = await tester.runAsync(
      () async => [
        for (final b in buddies) await BuddyRepository().getBuddyById(b.id),
      ],
    );
    expect(both!.nonNulls, hasLength(2));
  });

  testWidgets('a buddy linked to a profile merges with one that is not', (
    tester,
  ) async {
    final buddies = await tester.runAsync(() async {
      final a = await diver('A');
      return [await buddy('Marco'), await buddy('M.', linkedDiverId: a.id)];
    });
    final results = <Object?>[];
    await pumpMerge(tester, buddies!, results: results);

    await drive(
      tester,
      () => tester.tap(find.text(l.common_action_save)),
      () => confirmMerge().evaluate().isNotEmpty,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    await drive(
      tester,
      () => tester.tap(confirmMerge()),
      () => results.isNotEmpty,
    );
    await tester.pumpAndSettle();

    expect(results.single, isA<BuddyMergeResult>());
  });

  testWidgets('the merge page builds no linked profile or certifications '
      'section', (tester) async {
    final buddies = await tester.runAsync(
      () async => [await buddy('Marco'), await buddy('M.')],
    );
    await pumpMerge(tester, buddies!);

    expect(find.byType(LinkedProfileField), findsNothing);
    expect(find.text(l.buddies_section_certifications), findsNothing);
    expect(find.text(l.buddies_action_addCertification), findsNothing);
  });

  test('fewer than two ids is nothing to merge', () {
    expect(buddyMergeIds(['b1']), ['b1']);
    expect(buddyMergeIds(null), isEmpty);
    expect(buddyMergeIds(const <Object>[]), isEmpty);
    expect(buddyMergeIds(['b1', 'b2']), ['b1', 'b2']);
  });

  testWidgets('fewer than two ids goes back to the list', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/buddies',
          builder: (context, state) => const Text('LIST'),
          routes: [
            GoRoute(
              path: 'merge',
              redirect: buddyMergeRedirect,
              builder: (context, state) => const Text('MERGE'),
            ),
          ],
        ),
      ],
      initialLocation: '/buddies',
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    for (final extra in [
      ['b1'],
      <String>[],
      null,
    ]) {
      router.go('/buddies/merge', extra: extra);
      await tester.pumpAndSettle();
      expect(find.text('LIST'), findsOneWidget, reason: '$extra');
    }
    router.go('/buddies/merge', extra: ['b1', 'b2']);
    await tester.pumpAndSettle();
    expect(find.text('MERGE'), findsOneWidget);
  });
}
