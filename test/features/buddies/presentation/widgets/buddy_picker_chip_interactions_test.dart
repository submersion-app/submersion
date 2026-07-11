import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_picker.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

final _now = DateTime(2024, 1, 1);

final _alice = Buddy(id: 'b1', name: 'Alice', createdAt: _now, updatedAt: _now);

Future<void> _insertDiver() async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
}

void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(640, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _buildPicker({
  required List<BuddyWithRole> selectedBuddies,
  required ValueChanged<List<BuddyWithRole>> onChanged,
  required MockCurrentDiverIdNotifier diverIdNotifier,
  String? validatedDiverId = 'diver-1',
}) {
  return ProviderScope(
    overrides: [
      currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
      validatedCurrentDiverIdProvider.overrideWith(
        (ref) async => validatedDiverId,
      ),
      allBuddiesProvider.overrideWith((ref) async => [_alice]),
      buddySearchProvider.overrideWith((ref, q) async => const []),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BuddyPicker(
          selectedBuddies: selectedBuddies,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;

  setUp(() async {
    await setUpTestDatabase();
    await _insertDiver();
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  BuddyWithRole aliceAs(DiveRole role) =>
      BuddyWithRole(buddy: _alice, role: role);

  testWidgets('tapping a buddy chip opens the role selector and changing '
      'the role calls onChanged with the new role', (tester) async {
    _useTallScreen(tester);
    List<BuddyWithRole>? changed;
    await tester.pumpWidget(
      _buildPicker(
        selectedBuddies: [aliceAs(DiveRole.builtInBuddy())],
        onChanged: (v) => changed = v,
        diverIdNotifier: diverIdNotifier,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rear Guard'));
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changed!.single.role.id, DiveRole.rearGuardId);
  });

  testWidgets('removing a buddy chip calls onChanged without that buddy', (
    tester,
  ) async {
    List<BuddyWithRole>? changed;
    await tester.pumpWidget(
      _buildPicker(
        selectedBuddies: [aliceAs(DiveRole.builtInBuddy())],
        onChanged: (v) => changed = v,
        diverIdNotifier: diverIdNotifier,
      ),
    );
    await tester.pumpAndSettle();

    // InputChip delete affordance (Material 3 uses Icons.clear).
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changed, isEmpty);
  });

  testWidgets('adding a custom role from the chip selector creates it and '
      'applies it to the buddy', (tester) async {
    _useTallScreen(tester);
    List<BuddyWithRole>? changed;
    await tester.pumpWidget(
      _buildPicker(
        selectedBuddies: [aliceAs(DiveRole.builtInBuddy())],
        onChanged: (v) => changed = v,
        diverIdNotifier: diverIdNotifier,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add custom role...'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Hekkensluiter');
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Add')),
    );
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changed!.single.role.name, 'Hekkensluiter');
    expect(changed!.single.role.isBuiltIn, isFalse);
  });

  testWidgets('custom role creation failure shows an error snackbar and '
      'does not change the selection', (tester) async {
    _useTallScreen(tester);
    List<BuddyWithRole>? changed;
    await tester.pumpWidget(
      _buildPicker(
        selectedBuddies: [aliceAs(DiveRole.builtInBuddy())],
        onChanged: (v) => changed = v,
        diverIdNotifier: diverIdNotifier,
        // No valid diver profile: addDiveRoleByName throws.
        validatedDiverId: null,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add custom role...'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Hekkensluiter');
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Add')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Error adding dive role'), findsOneWidget);
    expect(changed, isNull);
  });

  testWidgets('custom role creation failure inside the selection sheet '
      'shows an error snackbar', (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(
      _buildPicker(
        selectedBuddies: const [],
        onChanged: (_) {},
        diverIdNotifier: diverIdNotifier,
        // No valid diver profile: addDiveRoleByName throws.
        validatedDiverId: null,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add custom role...'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Hekkensluiter');
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Add')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Error adding dive role'), findsOneWidget);
  });

  testWidgets('adding a custom role from the selection sheet adds the buddy '
      'with that role', (tester) async {
    _useTallScreen(tester);
    List<BuddyWithRole>? changed;
    await tester.pumpWidget(
      _buildPicker(
        selectedBuddies: const [],
        onChanged: (v) => changed = v,
        diverIdNotifier: diverIdNotifier,
      ),
    );
    await tester.pumpAndSettle();

    // Open the buddy selection sheet and pick Alice.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add custom role...'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Hekkensluiter');
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Add')),
    );
    await tester.pumpAndSettle();

    // Alice is now selected with the custom role; Done returns the list.
    expect(find.text('Hekkensluiter'), findsWidgets);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changed!.single.buddy.id, 'b1');
    expect(changed!.single.role.name, 'Hekkensluiter');
  });
}
