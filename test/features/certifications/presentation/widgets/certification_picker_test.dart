import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_picker.dart';

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
  CertificationLevel? level,
  DateTime? issueDate,
  CertificationAgency agency = CertificationAgency.padi,
}) {
  return Certification(
    id: 'c1',
    name: name,
    agency: agency,
    level: level,
    issueDate: issueDate,
    createdAt: _now,
    updatedAt: _now,
  );
}

/// The collapsed picker field, which shows the current selection.
Future<void> _pumpField(WidgetTester tester, Certification? selected) async {
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        certificationListNotifierProvider.overrideWith(
          (ref) => _MockCertListNotifier(const []),
        ),
      ],
      child: CertificationPicker(
        selectedCertification: selected,
        onCertificationSelected: (_) {},
      ),
    ),
  );
  await tester.pump();
}

/// The sheet body directly, rather than through showModalBottomSheet: it is a
/// public widget, so rendering it avoids driving a modal route just to read
/// two lines of text off a tile.
Future<void> _pumpSheet(WidgetTester tester, List<Certification> certs) async {
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        certificationListNotifierProvider.overrideWith(
          (ref) => _MockCertListNotifier(certs),
        ),
      ],
      child: CertificationPickerSheet(
        scrollController: ScrollController(),
        selectedCertification: null,
        onCertificationSelected: (_) {},
      ),
    ),
  );
  await tester.pump();
}

String _subtitleOf(WidgetTester tester, Finder tile) =>
    ((tester.widget<ListTile>(tile)).subtitle! as Text).data!;

/// The label a tile's own [ListTile] contributes when it is NOT excluded from
/// the semantics tree: its visible title and subtitle, newline-joined.
///
/// Asserting this is absent is what distinguishes a label that stands in for
/// the tile from one that merely sits alongside it. Only the rendered tree
/// shows the difference, so a check on the [Semantics] widget cannot see it.
String _visibleTextNode(String title, String subtitle) => '$title\n$subtitle';

void main() {
  // The sheet subtitle dates itself with DateFormat.yMMMd(), which resolves
  // against Intl.defaultLocale (a process global) rather than the
  // MaterialApp.locale the harness passes. Pin it so the "Aug 24, 2026"
  // assertion states its real dependency, and restore it afterwards because
  // the global leaks across tests in the same isolate.
  String? previousLocale;
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });
  tearDown(() => Intl.defaultLocale = previousLocale);

  group('collapsed picker field', () {
    testWidgets('a custom name keeps the certification in the subtitle', (
      tester,
    ) async {
      // Issue #1265: the title is the custom name, so the subtitle is the only
      // place left for the level.
      await _pumpField(
        tester,
        _makeCert(name: 'Bill Ansell', level: CertificationLevel.diveMaster),
      );

      expect(find.text('Bill Ansell'), findsOneWidget);
      expect(_subtitleOf(tester, find.byType(ListTile)), 'PADI - Divemaster');
    });

    testWidgets('a derived title does not repeat the level', (tester) async {
      await _pumpField(
        tester,
        _makeCert(name: '', level: CertificationLevel.diveMaster),
      );

      expect(find.text('Divemaster'), findsOneWidget);
      expect(_subtitleOf(tester, find.byType(ListTile)), 'PADI');
    });
  });

  group('picker sheet', () {
    testWidgets('a custom name keeps the certification in the subtitle', (
      tester,
    ) async {
      await _pumpSheet(tester, [
        _makeCert(
          name: 'Bill Ansell',
          level: CertificationLevel.diveMaster,
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
        _makeCert(name: 'Bill Ansell', level: CertificationLevel.diveMaster),
      ]);

      expect(_subtitleOf(tester, find.byType(ListTile)), 'PADI - Divemaster');
    });

    testWidgets('the accessibility label names the certification too', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await _pumpSheet(tester, [
        _makeCert(name: 'Bill Ansell', level: CertificationLevel.diveMaster),
      ]);

      // A screen reader must hear the level even when a custom name owns the
      // title, since the title alone no longer carries it.
      expect(
        find.bySemanticsLabel('PADI Bill Ansell, Divemaster'),
        findsOneWidget,
      );
      // And exactly once: without excludeSemantics the tile keeps a second
      // node carrying its visible text, so the row is announced twice.
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
      Certification? picked;

      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            certificationListNotifierProvider.overrideWith(
              (ref) => _MockCertListNotifier([
                _makeCert(
                  name: 'Bill Ansell',
                  level: CertificationLevel.diveMaster,
                ),
              ]),
            ),
          ],
          child: CertificationPickerSheet(
            scrollController: ScrollController(),
            selectedCertification: null,
            onCertificationSelected: (cert) => picked = cert,
          ),
        ),
      );
      await tester.pump();

      // Excluding the subtree drops the ListTile's own tap action, so the
      // wrapper must carry one or the row becomes unreachable by a screen
      // reader even though it still looks tappable.
      tester.semantics.performAction(
        find.semantics.byLabel('PADI Bill Ansell, Divemaster'),
        SemanticsAction.tap,
      );
      await tester.pump();

      expect(picked?.name, 'Bill Ansell');

      handle.dispose();
    });

    testWidgets('a derived title does not repeat the level', (tester) async {
      final handle = tester.ensureSemantics();

      await _pumpSheet(tester, [
        _makeCert(name: '', level: CertificationLevel.diveMaster),
      ]);

      expect(_subtitleOf(tester, find.byType(ListTile)), 'PADI');
      // The title is already the level, so the label says it once, not twice.
      expect(find.bySemanticsLabel('PADI Divemaster'), findsOneWidget);
      expect(
        find.bySemanticsLabel(_visibleTextNode('Divemaster', 'PADI')),
        findsNothing,
      );

      handle.dispose();
    });
  });
}
