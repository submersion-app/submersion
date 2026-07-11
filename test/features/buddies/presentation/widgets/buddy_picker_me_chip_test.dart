import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_picker.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _now = DateTime(2024, 1, 1);

final _testRoles = [
  for (final (i, id) in DiveRole.builtInIds.indexed)
    DiveRole(
      id: id,
      name: id,
      isBuiltIn: true,
      sortOrder: i,
      createdAt: _now,
      updatedAt: _now,
    ),
];

Widget _buildPicker({
  List<BuddyWithRole> selectedBuddies = const [],
  String? diverRoleId,
  ValueChanged<String?>? onDiverRoleChanged,
  Diver? diver,
}) {
  return ProviderScope(
    overrides: [
      allDiveRolesProvider.overrideWith((ref) async => _testRoles),
      allBuddiesProvider.overrideWith((ref) async => const <Buddy>[]),
      currentDiverProvider.overrideWith((ref) async => diver),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BuddyPicker(
          selectedBuddies: selectedBuddies,
          onChanged: (_) {},
          diverRoleId: diverRoleId,
          onDiverRoleChanged: onDiverRoleChanged,
        ),
      ),
    ),
  );
}

void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(640, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('Me chip hidden when onDiverRoleChanged is null', (tester) async {
    await tester.pumpWidget(_buildPicker());
    await tester.pumpAndSettle();

    expect(find.text('Me'), findsNothing);
    expect(find.text('Set my role'), findsNothing);
  });

  testWidgets('Me chip shows Set my role when diverRoleId is null', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPicker(onDiverRoleChanged: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('Me'), findsOneWidget);
    expect(find.text('Set my role'), findsOneWidget);
  });

  testWidgets('Me chip shows the diver name and localized role when set', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPicker(
        diverRoleId: DiveRole.rearGuardId,
        onDiverRoleChanged: (_) {},
        diver: Diver(
          id: 'diver-1',
          name: 'Eric G',
          createdAt: _now,
          updatedAt: _now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Eric G'), findsOneWidget);
    expect(find.text('Rear Guard'), findsOneWidget);
  });

  testWidgets('tapping Me chip and choosing a role calls onDiverRoleChanged '
      'with its id', (tester) async {
    _useTallScreen(tester);
    String? changed = 'sentinel';
    await tester.pumpWidget(
      _buildPicker(onDiverRoleChanged: (v) => changed = v),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rear Guard'));
    await tester.pumpAndSettle();

    expect(changed, DiveRole.rearGuardId);
  });

  testWidgets('choosing No role calls onDiverRoleChanged(null)', (
    tester,
  ) async {
    _useTallScreen(tester);
    String? changed = 'sentinel';
    await tester.pumpWidget(
      _buildPicker(
        diverRoleId: DiveRole.rearGuardId,
        onDiverRoleChanged: (v) => changed = v,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('No role'));
    await tester.pumpAndSettle();

    expect(changed, isNull);
  });
}
