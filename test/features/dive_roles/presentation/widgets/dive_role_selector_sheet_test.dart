import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/widgets/dive_role_selector_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _now = DateTime(2024, 1, 1);

DiveRole _builtIn(String id, String name, int sortOrder) => DiveRole(
  id: id,
  name: name,
  isBuiltIn: true,
  sortOrder: sortOrder,
  createdAt: _now,
  updatedAt: _now,
);

final _roles = [
  _builtIn(DiveRole.buddyId, 'Buddy', 0),
  _builtIn(DiveRole.instructorId, 'Instructor', 2),
  _builtIn(DiveRole.rearGuardId, 'Rear Guard', 6),
  DiveRole(
    id: 'uuid-1',
    name: 'Hekkensluiter',
    diverId: 'diver-1',
    sortOrder: 9,
    createdAt: _now,
    updatedAt: _now,
  ),
];

Widget _harness({
  required void Function(DiveRoleSelection?) onResult,
  bool allowNone = false,
  Set<String> credentialRoleIds = const {},
  String? selectedRoleId,
  Future<DiveRole?> Function(String name)? onCreateCustomRole,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              final result = await showDiveRoleSelector(
                context,
                title: 'Select role',
                roles: _roles,
                allowNone: allowNone,
                credentialRoleIds: credentialRoleIds,
                selectedRoleId: selectedRoleId,
                onCreateCustomRole: onCreateCustomRole,
              );
              onResult(result);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {});

  testWidgets('lists roles and returns the tapped role', (tester) async {
    DiveRoleSelection? result;
    await tester.pumpWidget(_harness(onResult: (r) => result = r));
    await _open(tester);

    expect(find.text('Buddy'), findsOneWidget);
    expect(find.text('Hekkensluiter'), findsOneWidget);

    await tester.tap(find.text('Hekkensluiter'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.role!.id, 'uuid-1');
  });

  testWidgets('shows No role entry when allowNone and returns null role', (
    tester,
  ) async {
    DiveRoleSelection? result;
    await tester.pumpWidget(
      _harness(onResult: (r) => result = r, allowNone: true),
    );
    await _open(tester);

    await tester.tap(find.text('No role'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.role, isNull);
  });

  testWidgets('dismissing the sheet returns null (cancelled)', (tester) async {
    DiveRoleSelection? result = const DiveRoleSelection(null);
    await tester.pumpWidget(_harness(onResult: (r) => result = r));
    await _open(tester);

    // Tap outside the sheet to dismiss.
    await tester.tapAt(const Offset(400, 20));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('Add custom role flow creates and returns the new role', (
    tester,
  ) async {
    DiveRoleSelection? result;
    await tester.pumpWidget(
      _harness(
        onResult: (r) => result = r,
        onCreateCustomRole: (name) async => DiveRole(
          id: 'uuid-new',
          name: name,
          diverId: 'diver-1',
          sortOrder: 10,
          createdAt: _now,
          updatedAt: _now,
        ),
      ),
    );
    await _open(tester);

    await tester.tap(find.text('Add custom role...'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Scooter Pilot');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.role!.id, 'uuid-new');
    expect(result!.role!.name, 'Scooter Pilot');
  });

  testWidgets('credential roles float to the top with premium icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(onResult: (_) {}, credentialRoleIds: {DiveRole.instructorId}),
    );
    await _open(tester);

    final instructorCenter = tester.getCenter(find.text('Instructor')).dy;
    final buddyCenter = tester.getCenter(find.text('Buddy')).dy;
    expect(instructorCenter, lessThan(buddyCenter));

    final instructorTile = find.ancestor(
      of: find.text('Instructor'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(
        of: instructorTile,
        matching: find.byIcon(Icons.workspace_premium),
      ),
      findsOneWidget,
    );
  });
}
