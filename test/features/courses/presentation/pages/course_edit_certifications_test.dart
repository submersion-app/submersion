import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide Certification, Diver;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/domain/entities/course.dart'
    as domain;
import 'package:submersion/features/courses/presentation/pages/course_edit_page.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_multi_select_field.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// A course earns several certifications from its editor (#2515).
void main() {
  late AppDatabase db;
  late String diverId;

  setUp(() async {
    db = await setUpTestDatabase();
    final now = DateTime(2026, 9, 1);
    diverId = (await DiverRepository().createDiver(
      Diver(id: '', name: 'D', isDefault: true, createdAt: now, updatedAt: now),
    )).id;
    await CourseRepository().createCourse(
      domain.Course(
        id: 'andp',
        diverId: diverId,
        name: 'TDI AN/DP',
        agency: 'tdi',
        startDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    for (final (id, name) in [
      ('k-an', 'Advanced Nitrox'),
      ('k-dp', 'Decompression Procedures'),
    ]) {
      await db
          .into(db.certifications)
          .insert(
            CertificationsCompanion(
              id: Value(id),
              diverId: Value(diverId),
              name: Value(name),
              agency: const Value('tdi'),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  Future<String?> courseOf(String certId) async => (await (db.select(
    db.certifications,
  )..where((t) => t.id.equals(certId))).getSingle()).courseId;

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CourseEditPage(
              courseId: 'andp',
              embedded: true,
              onSavedWithId: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.text('Save Changes');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('ticking two certifications links both to the course', (
    tester,
  ) async {
    await pumpEditor(tester);
    expect(find.text('Earned Certifications'), findsOneWidget);

    final field = find.text('Tap to link to an earned certification');
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced Nitrox'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decompression Procedures'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await save(tester);

    expect(await courseOf('k-an'), 'andp');
    expect(await courseOf('k-dp'), 'andp');
  });

  testWidgets('removing a certification chip unlinks it on save', (
    tester,
  ) async {
    await CourseRepository().setCourseCertifications('andp', ['k-an', 'k-dp']);
    await pumpEditor(tester);

    final chip = find.widgetWithText(InputChip, 'Advanced Nitrox');
    await tester.ensureVisible(chip);
    await tester.tap(
      find.descendant(of: chip, matching: find.byIcon(Icons.clear)),
    );
    await tester.pumpAndSettle();
    await save(tester);

    expect(await courseOf('k-an'), isNull);
    expect(await courseOf('k-dp'), 'andp');
  });

  testWidgets('the field stays inert until the course set has loaded', (
    tester,
  ) async {
    // Opening the sheet before the existing set arrives would start it from
    // nothing, and a save would then unlink every earned certification.
    await CourseRepository().setCourseCertifications('andp', ['k-an']);
    final pending = Completer<List<Certification>>();
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast(),
          certificationsForCourseProvider(
            'andp',
          ).overrideWith((ref) => pending.future),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CourseEditPage(
              courseId: 'andp',
              embedded: true,
              onSavedWithId: (_) {},
            ),
          ),
        ),
      ),
    );
    // Bounded pumps: the loading indicator animates, so nothing settles.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(CertificationMultiSelectField), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsWidgets);

    final button = find.text('Save Changes');
    await tester.ensureVisible(button);
    await tester.tap(button);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(await courseOf('k-an'), 'andp');
  });
}
