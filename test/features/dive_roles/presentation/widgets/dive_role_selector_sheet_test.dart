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
  _builtIn(DiveRole.diveGuideId, 'Dive Guide', 1),
  _builtIn(DiveRole.instructorId, 'Instructor', 2),
  _builtIn(DiveRole.diveMasterId, 'Divemaster', 4),
  _builtIn(DiveRole.soloId, 'Solo', 5),
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

/// Holds the sheet's result: [opened] tells "never returned" apart from a
/// null (dismissed) result.
class _Result {
  bool opened = false;
  List<DiveRole>? roles;
}

Widget _harness(
  _Result result, {
  bool allowEmpty = false,
  Set<String> credentialRoleIds = const {},
  List<String> selectedRoleIds = const [],
  Future<DiveRole?> Function(String name)? onCreateCustomRole,
  Set<String> hiddenRoleIds = const {},
  List<String> keepRoleIds = const [],
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              result.roles = await showDiveRoleSelector(
                context,
                title: 'Select role',
                roles: _roles,
                allowEmpty: allowEmpty,
                credentialRoleIds: credentialRoleIds,
                selectedRoleIds: selectedRoleIds,
                onCreateCustomRole: onCreateCustomRole,
                hiddenRoleIds: hiddenRoleIds,
                keepRoleIds: keepRoleIds,
              );
              result.opened = true;
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

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

bool _ticked(WidgetTester tester, String label) => tester
    .widget<CheckboxListTile>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(CheckboxListTile),
      ),
    )
    .value!;

void main() {
  testWidgets('ticks several roles and returns them on Done', (tester) async {
    final result = _Result();
    await tester.pumpWidget(_harness(result));
    await _open(tester);

    await _tap(tester, 'Divemaster');
    await _tap(tester, 'Dive Guide');
    await _tap(tester, 'Done');

    expect(result.roles!.map((r) => r.id), [
      DiveRole.diveGuideId,
      DiveRole.diveMasterId,
    ]);
  });

  testWidgets('starts with the selected roles ticked', (tester) async {
    final result = _Result();
    await tester.pumpWidget(
      _harness(result, selectedRoleIds: const ['uuid-1', 'instructor']),
    );
    await _open(tester);

    expect(_ticked(tester, 'Hekkensluiter'), isTrue);
    expect(_ticked(tester, 'Instructor'), isTrue);
    expect(_ticked(tester, 'Buddy'), isFalse);
  });

  testWidgets('ticking Solo clears the others; another role clears Solo', (
    tester,
  ) async {
    final result = _Result();
    await tester.pumpWidget(
      _harness(result, selectedRoleIds: const [DiveRole.diveMasterId]),
    );
    await _open(tester);

    await _tap(tester, 'Solo');
    expect(_ticked(tester, 'Solo'), isTrue);
    expect(_ticked(tester, 'Divemaster'), isFalse);

    await _tap(tester, 'Dive Guide');
    expect(_ticked(tester, 'Solo'), isFalse);
    await _tap(tester, 'Done');

    expect(result.roles!.map((r) => r.id), [DiveRole.diveGuideId]);
  });

  testWidgets('No role clears every tick when empty is allowed', (
    tester,
  ) async {
    final result = _Result();
    await tester.pumpWidget(
      _harness(
        result,
        allowEmpty: true,
        selectedRoleIds: const [DiveRole.diveMasterId],
      ),
    );
    await _open(tester);

    await _tap(tester, 'No role');
    expect(_ticked(tester, 'Divemaster'), isFalse);
    await _tap(tester, 'Done');

    expect(result.roles, isEmpty);
  });

  testWidgets('without allowEmpty there is no No role row', (tester) async {
    final result = _Result();
    await tester.pumpWidget(_harness(result));
    await _open(tester);
    expect(find.text('No role'), findsNothing);
  });

  testWidgets('dismissing the sheet returns null (cancelled)', (tester) async {
    final result = _Result()..roles = const [];
    await tester.pumpWidget(_harness(result));
    await _open(tester);

    // Tap outside the sheet to dismiss.
    await tester.tapAt(const Offset(400, 20));
    await tester.pumpAndSettle();

    expect(result.opened, isTrue);
    expect(result.roles, isNull);
  });

  testWidgets('Add custom role creates the role and ticks it', (tester) async {
    final result = _Result();
    await tester.pumpWidget(
      _harness(
        result,
        selectedRoleIds: const [DiveRole.instructorId],
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

    await _tap(tester, 'Add custom role...');
    await tester.enterText(find.byType(TextField), 'Scooter Pilot');
    await _tap(tester, 'Add');

    expect(_ticked(tester, 'Scooter Pilot'), isTrue);
    await _tap(tester, 'Done');

    expect(result.roles!.map((r) => r.id), [DiveRole.instructorId, 'uuid-new']);
    expect(result.roles!.last.name, 'Scooter Pilot');
  });

  testWidgets('credential roles float to the top with premium icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(_Result(), credentialRoleIds: {DiveRole.instructorId}),
    );
    await _open(tester);

    final instructorCenter = tester.getCenter(find.text('Instructor')).dy;
    final buddyCenter = tester.getCenter(find.text('Buddy')).dy;
    expect(instructorCenter, lessThan(buddyCenter));

    final instructorTile = find.ancestor(
      of: find.text('Instructor'),
      matching: find.byType(CheckboxListTile),
    );
    expect(
      find.descendant(
        of: instructorTile,
        matching: find.byIcon(Icons.workspace_premium),
      ),
      findsOneWidget,
    );
  });

  testWidgets('leaves out hidden built-in roles', (tester) async {
    await tester.pumpWidget(
      _harness(_Result(), hiddenRoleIds: {DiveRole.rearGuardId}),
    );
    await _open(tester);
    expect(find.text('Rear Guard'), findsNothing);
    expect(find.text('Instructor'), findsOneWidget);
    expect(find.text('Hekkensluiter'), findsOneWidget);
  });

  testWidgets('keeps a hidden role that is currently selected', (tester) async {
    await tester.pumpWidget(
      _harness(
        _Result(),
        hiddenRoleIds: {DiveRole.buddyId, DiveRole.rearGuardId},
        selectedRoleIds: const [DiveRole.buddyId],
      ),
    );
    await _open(tester);
    expect(find.text('Buddy'), findsOneWidget);
    expect(find.text('Rear Guard'), findsNothing);
  });

  testWidgets('keeps a hidden role the record had, even once changed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _Result(),
        hiddenRoleIds: {DiveRole.rearGuardId},
        selectedRoleIds: const [DiveRole.buddyId],
        keepRoleIds: [DiveRole.rearGuardId],
      ),
    );
    await _open(tester);
    expect(find.text('Rear Guard'), findsOneWidget);
  });

  testWidgets('keeps every ticked role that is hidden (#1221)', (tester) async {
    await tester.pumpWidget(
      _harness(
        _Result(),
        hiddenRoleIds: {
          DiveRole.diveGuideId,
          DiveRole.diveMasterId,
          DiveRole.rearGuardId,
        },
        selectedRoleIds: const [DiveRole.diveGuideId, DiveRole.diveMasterId],
      ),
    );
    await _open(tester);
    expect(_ticked(tester, 'Dive Guide'), isTrue);
    expect(_ticked(tester, 'Divemaster'), isTrue);
    expect(find.text('Rear Guard'), findsNothing);
  });
}
