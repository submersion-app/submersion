import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_multi_select_field.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';

import '../../../../helpers/test_app.dart';

class _MockCertListNotifier
    extends StateNotifier<AsyncValue<List<Certification>>>
    implements CertificationListNotifier {
  _MockCertListNotifier(List<Certification> certs)
    : super(AsyncValue.data(certs));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _now = DateTime(2026, 8, 24);

Certification _makeCert({
  required String name,
  String id = 'c1',
  String? level,
  DateTime? issueDate,
  String agency = 'padi',
  String? courseId,
  List<CertificationCredential> additionalCredentials = const [],
}) {
  return Certification(
    id: id,
    courseId: courseId,
    name: name,
    agency: agency,
    level: level,
    issueDate: issueDate,
    additionalCredentials: additionalCredentials,
    createdAt: _now,
    updatedAt: _now,
  );
}

final _rescue = Course(
  id: 'rescue',
  diverId: 'd',
  name: 'Rescue course',
  agency: 'padi',
  startDate: _now,
  createdAt: _now,
  updatedAt: _now,
);

/// The sheet body directly, rather than through showModalBottomSheet: it is a
/// public widget, so rendering it avoids driving a modal route just to read
/// two lines of text off a tile.
Future<void> _pumpSheet(
  WidgetTester tester,
  List<Certification> certs, {
  List<String> selected = const [],
  ValueChanged<List<String>>? onChanged,
}) async {
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        certificationListNotifierProvider.overrideWith(
          (ref) => _MockCertListNotifier(certs),
        ),
        allCoursesProvider.overrideWith((ref) async => [_rescue]),
      ],
      child: CertificationMultiPickerSheet(
        courseId: 'this-course',
        selectedCertificationIds: selected,
        onChanged: onChanged ?? (_) {},
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

String _subtitleOf(WidgetTester tester, Finder tile) =>
    ((tester.widget<ListTile>(tile)).subtitle! as Text).data!;

/// The label a tile's own [ListTile] contributes when it is NOT excluded from
/// the semantics tree: its visible title and subtitle, newline-joined.
String _visibleTextNode(String title, String subtitle) => '$title\n$subtitle';

void main() {
  // The sheet subtitle dates itself with DateFormat.yMMMd(), which resolves
  // against Intl.defaultLocale (a process global) rather than the
  // MaterialApp.locale the harness passes. Pin it, and restore it afterwards
  // because the global leaks across tests in the same isolate.
  String? previousLocale;
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });
  tearDown(() => Intl.defaultLocale = previousLocale);

  group('chip field (#2515)', () {
    testWidgets('shows a chip per selected certification', (tester) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            certificationListNotifierProvider.overrideWith(
              (ref) => _MockCertListNotifier([
                _makeCert(id: 'a', name: 'Advanced Nitrox'),
                _makeCert(id: 'b', name: 'Deco Procedures'),
              ]),
            ),
            allCoursesProvider.overrideWith((ref) async => [_rescue]),
          ],
          child: CertificationMultiSelectField(
            courseId: 'this-course',
            selectedCertificationIds: const ['a', 'b'],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(find.widgetWithText(InputChip, 'Advanced Nitrox'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Deco Procedures'), findsOneWidget);
    });

    testWidgets('a chip delete drops only that certification', (tester) async {
      final changes = <List<String>>[];
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            certificationListNotifierProvider.overrideWith(
              (ref) => _MockCertListNotifier([
                _makeCert(id: 'a', name: 'Advanced Nitrox'),
                _makeCert(id: 'b', name: 'Deco Procedures'),
              ]),
            ),
            allCoursesProvider.overrideWith((ref) async => [_rescue]),
          ],
          child: CertificationMultiSelectField(
            courseId: 'this-course',
            selectedCertificationIds: const ['a', 'b'],
            onChanged: changes.add,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(InputChip, 'Advanced Nitrox'),
          matching: find.byIcon(Icons.clear),
        ),
      );
      await tester.pump();
      expect(changes.single, ['b']);
    });

    testWidgets('no selection shows the hint', (tester) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            certificationListNotifierProvider.overrideWith(
              (ref) => _MockCertListNotifier(const []),
            ),
            allCoursesProvider.overrideWith((ref) async => []),
          ],
          child: CertificationMultiSelectField(
            courseId: null,
            selectedCertificationIds: const [],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text('Tap to link to an earned certification'),
        findsOneWidget,
      );
    });
  });

  group('picker sheet', () {
    testWidgets('an empty wallet offers to add a certification', (
      tester,
    ) async {
      await _pumpSheet(tester, const []);
      expect(find.text('No certifications yet'), findsOneWidget);
      expect(find.text('Add Certification'), findsOneWidget);
    });

    testWidgets('an expired certification carries the Expired badge', (
      tester,
    ) async {
      await _pumpSheet(tester, [
        Certification(
          id: 'old',
          name: 'Old card',
          agency: 'padi',
          expiryDate: DateTime(2000),
          createdAt: _now,
          updatedAt: _now,
        ),
      ]);
      expect(find.text('Expired'), findsOneWidget);
    });

    testWidgets('a toggle reports the whole selection at once', (tester) async {
      final changes = <List<String>>[];
      await _pumpSheet(
        tester,
        [
          _makeCert(id: 'a', name: 'Advanced Nitrox'),
          _makeCert(id: 'b', name: 'Deco Procedures'),
        ],
        selected: const ['a'],
        onChanged: changes.add,
      );
      await tester.tap(find.text('Deco Procedures'));
      await tester.pump();
      expect(changes.single, ['a', 'b']);
    });

    testWidgets('a certification on another course says which (#2515)', (
      tester,
    ) async {
      await _pumpSheet(tester, [
        _makeCert(id: 'a', name: 'Rescue Diver', courseId: 'rescue'),
        _makeCert(id: 'b', name: 'Mine', courseId: 'this-course'),
      ]);
      expect(find.textContaining('Linked to: Rescue course'), findsOneWidget);
      expect(find.textContaining('Linked to: '), findsOneWidget);
    });

    testWidgets('a custom name keeps the certification in the subtitle', (
      tester,
    ) async {
      await _pumpSheet(tester, [
        _makeCert(
          name: 'Bill Ansell',
          level: CertificationLevel.diveMaster.name,
          issueDate: DateTime(2026, 8, 24),
        ),
      ]);

      expect(
        _subtitleOf(tester, find.byType(ListTile)),
        'PADI - Divemaster - Aug 24, 2026',
      );
    });

    testWidgets('a certification with no issue date omits the date', (
      tester,
    ) async {
      await _pumpSheet(tester, [
        _makeCert(
          name: 'Bill Ansell',
          level: CertificationLevel.diveMaster.name,
        ),
      ]);

      expect(_subtitleOf(tester, find.byType(ListTile)), 'PADI - Divemaster');
    });

    testWidgets('a multi-credential card lists every recognition in the row', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await _pumpSheet(tester, [
        _makeCert(
          name: '',
          agency: CertificationAgency.ffessm.name,
          level: CertificationLevel.ffessmN1.name,
          additionalCredentials: const [
            CertificationCredential(agency: 'cmas', level: 'cmas1StarDiver'),
          ],
        ),
      ]);

      final subtitle = _subtitleOf(tester, find.byType(ListTile));
      expect(subtitle, contains('FFESSM'));
      expect(subtitle, contains('CMAS'));
      expect(find.bySemanticsLabel(RegExp('CMAS')), findsWidgets);

      handle.dispose();
    });

    testWidgets('the accessibility label names the certification too', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await _pumpSheet(tester, [
        _makeCert(
          name: 'Bill Ansell',
          level: CertificationLevel.diveMaster.name,
        ),
      ]);

      expect(
        find.bySemanticsLabel('PADI Bill Ansell, Divemaster'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          _visibleTextNode('Bill Ansell', 'PADI - Divemaster'),
        ),
        findsNothing,
      );

      handle.dispose();
    });

    testWidgets('the tile stays activatable through the semantics label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final changes = <List<String>>[];

      await _pumpSheet(tester, [
        _makeCert(
          name: 'Bill Ansell',
          level: CertificationLevel.diveMaster.name,
        ),
      ], onChanged: changes.add);

      tester.semantics.performAction(
        find.semantics.byLabel('PADI Bill Ansell, Divemaster'),
        SemanticsAction.tap,
      );
      await tester.pump();

      expect(changes.single, ['c1']);

      handle.dispose();
    });

    testWidgets('a derived title does not repeat the level', (tester) async {
      final handle = tester.ensureSemantics();

      await _pumpSheet(tester, [
        _makeCert(name: '', level: CertificationLevel.diveMaster.name),
      ]);

      expect(_subtitleOf(tester, find.byType(ListTile)), 'PADI');
      expect(find.bySemanticsLabel('PADI Divemaster'), findsOneWidget);
      expect(
        find.bySemanticsLabel(_visibleTextNode('Divemaster', 'PADI')),
        findsNothing,
      );

      handle.dispose();
    });
  });
}
