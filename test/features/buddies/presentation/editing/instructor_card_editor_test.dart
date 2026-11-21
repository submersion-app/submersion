import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/instructor_card_editor.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// A small record with an instructor, standing for a certification or a
/// course.
class _Record {
  const _Record({this.id, this.name, this.number, this.notes = ''});

  final String? id;
  final String? name;
  final String? number;
  final String notes;
}

final _instructor = EditField<_Record, InstructorValue>(
  id: 'instructor',
  cardId: 'instructor',
  read: (r) => (id: r.id, name: r.name, number: r.number),
  write: (r, v) =>
      _Record(id: v.id, name: v.name, number: v.number, notes: r.notes),
);

/// One instructor editor serves every record with an instructor (issue
/// #4527, phase 3).
void main() {
  final now = DateTime(2024);
  final alice = Buddy(
    id: 'buddy-1',
    name: 'Alice Instructor',
    createdAt: now,
    updatedAt: now,
  );
  final bob = Buddy(
    id: 'buddy-2',
    name: 'Bob NoCert',
    createdAt: now,
    updatedAt: now,
  );
  final aliceCert = Certification(
    id: 'buddy-1-instructor',
    buddyId: 'buddy-1',
    name: 'Instructor',
    agency: CertificationAgency.padi.name,
    level: CertificationLevel.instructor.name,
    cardNumber: '999-PADI',
    createdAt: now,
    updatedAt: now,
  );
  const aliceLabel = 'Alice Instructor (PADI Instructor #999-PADI)';

  Future<EditSession<_Record>> pumpEditor(
    WidgetTester tester, [
    _Record record = const _Record(),
  ]) async {
    final session = EditSession(record);
    addTearDown(session.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          allBuddiesProvider.overrideWith((ref) async => [alice, bob]),
          allBuddyCertificationsProvider.overrideWith(
            (ref) async => {
              'buddy-1': [aliceCert],
            },
          ),
        ],
        child: Scaffold(
          body: SingleChildScrollView(
            child: InstructorCardEditor<_Record>(
              session: session,
              field: _instructor,
              nameLabel: 'Instructor name',
              numberLabel: 'Instructor number',
              keyPrefix: 'test',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  Future<void> pick(WidgetTester tester, String label) async {
    final dropdown = find.byType(DropdownButtonFormField<String?>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

  testWidgets('picking a credentialed buddy fills name and number', (
    tester,
  ) async {
    final session = await pumpEditor(tester);

    await pick(tester, aliceLabel);

    expect(textOf(tester, 'test-instructor-name'), 'Alice Instructor');
    expect(textOf(tester, 'test-instructor-number'), '999-PADI');
    expect(session.working.id, 'buddy-1');
  });

  testWidgets('switching to a buddy without a credential clears the number', (
    tester,
  ) async {
    final session = await pumpEditor(tester);
    await pick(tester, aliceLabel);

    await pick(tester, 'Bob NoCert');

    expect(textOf(tester, 'test-instructor-name'), 'Bob NoCert');
    expect(textOf(tester, 'test-instructor-number'), '');
    expect(session.working.number, isNull);
  });

  testWidgets('a buddy with no credential is still offered', (tester) async {
    await pumpEditor(tester);

    final dropdown = find.byType(DropdownButtonFormField<String?>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    expect(find.text('Bob NoCert').last, findsOneWidget);
  });

  testWidgets('clearing the pick keeps the text', (tester) async {
    final session = await pumpEditor(
      tester,
      const _Record(id: 'buddy-1', name: 'Alice Instructor', number: '9'),
    );

    await pick(tester, 'None (manual entry)');

    expect(session.working.id, isNull);
    expect(session.working.name, 'Alice Instructor');
    expect(session.working.number, '9');
  });

  testWidgets('typing the name after a pick keeps the buddy picked', (
    tester,
  ) async {
    final session = await pumpEditor(tester);
    await pick(tester, aliceLabel);

    await tester.enterText(
      find.byKey(const ValueKey('test-instructor-name')),
      'Alice I.',
    );
    await tester.pump();

    expect(session.working.id, 'buddy-1');
    expect(session.working.name, 'Alice I.');
    expect(
      find.descendant(
        of: find.byType(DropdownButtonFormField<String?>),
        matching: find.text(aliceLabel),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a stored instructor opens picked', (tester) async {
    await pumpEditor(
      tester,
      const _Record(id: 'buddy-1', name: 'Alice Instructor', number: '9'),
    );

    expect(
      find.descendant(
        of: find.byType(DropdownButtonFormField<String?>),
        matching: find.text(aliceLabel),
      ),
      findsOneWidget,
    );
  });

  testWidgets('typing the name is one change of the field\'s card', (
    tester,
  ) async {
    final session = await pumpEditor(tester);

    await tester.enterText(
      find.byKey(const ValueKey('test-instructor-name')),
      'Jo',
    );
    await tester.pump();

    expect(session.changedCardIds, {'instructor'});
    expect(session.working.name, 'Jo');
  });
}
