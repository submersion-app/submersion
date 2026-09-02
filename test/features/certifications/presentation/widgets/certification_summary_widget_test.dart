import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_summary_widget.dart';

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
  CertificationAgency agency = CertificationAgency.padi,
}) {
  return Certification(
    id: 'c1',
    name: name,
    agency: agency,
    level: level,
    createdAt: _now,
    updatedAt: _now,
  );
}

Future<void> _pump(WidgetTester tester, Certification cert) async {
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        certificationListNotifierProvider.overrideWith(
          (ref) => _MockCertListNotifier([cert]),
        ),
      ],
      child: const CertificationSummaryWidget(),
    ),
  );
  await tester.pump();
}

/// The preview tile's two lines. Read off the [ListTile] rather than via
/// `find.text` because the leading avatar also renders the agency, so a bare
/// text match on "PADI" cannot tell the subtitle from the badge.
({String title, String subtitle}) _tileLines(WidgetTester tester) {
  final tile = tester.widget<ListTile>(find.byType(ListTile));
  return (
    title: (tile.title! as Text).data!,
    subtitle: (tile.subtitle! as Text).data!,
  );
}

void main() {
  group('recent certification preview', () {
    testWidgets('a custom name keeps the certification in the subtitle', (
      tester,
    ) async {
      // Issue #1265: the title is the custom name, so the subtitle is the only
      // place left for the level.
      await _pump(
        tester,
        _makeCert(name: 'Bill Ansell', level: CertificationLevel.diveMaster),
      );

      expect(_tileLines(tester), (
        title: 'Bill Ansell',
        subtitle: 'PADI - Divemaster',
      ));
    });

    testWidgets('a derived title does not repeat the level in the subtitle', (
      tester,
    ) async {
      await _pump(
        tester,
        _makeCert(name: '', level: CertificationLevel.diveMaster),
      );

      // The title already says "Divemaster"; the subtitle must not say it
      // again, which is the duplication the title helper exists to remove.
      expect(_tileLines(tester), (title: 'Divemaster', subtitle: 'PADI'));
    });

    testWidgets('a custom name with no level shows the agency alone', (
      tester,
    ) async {
      await _pump(tester, _makeCert(name: 'DAN Insurance'));

      expect(_tileLines(tester), (title: 'DAN Insurance', subtitle: 'PADI'));
    });
  });
}
