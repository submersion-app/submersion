import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_card_photo.dart';
import 'package:submersion/features/courses/presentation/widgets/course_certification_thumbnail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

/// A valid 1x1 PNG, so the image decoder has real bytes.
final _front = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
  'hKmMIQAAAABJRU5ErkJggg==',
);

/// A different 1x1 PNG, so a test can tell which side was shown.
final _back = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mM4IScHAAK2AQUK'
  'W6YGAAAAAElFTkSuQmCC',
);

/// The course page's earned certification rows show each card (#3383).
void main() {
  final now = DateTime(2026, 9, 1);
  Certification cert({Uint8List? front, Uint8List? back}) => Certification(
    id: 'c1',
    name: 'Open Water Diver',
    agency: 'padi',
    photoFront: front,
    photoBack: back,
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pump(WidgetTester tester, Certification certification) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: Scaffold(
          body: Center(
            child: CourseCertificationThumbnail(
              certification: certification,
              agencyName: 'PADI Worldwide',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Size thumbnailSize(WidgetTester tester) =>
      tester.getSize(find.byType(CourseCertificationThumbnail));

  testWidgets('shows the front photo at card proportions', (tester) async {
    await pump(tester, cert(front: _front, back: _back));

    final photo = tester.widget<CertificationCardPhoto>(
      find.byType(CertificationCardPhoto),
    );
    expect(photo.bytes, _front);
    expect(photo.showShadow, isFalse);
    expect(photo.radius, lessThan(CertificationCardPhoto.borderRadius));
    expect(thumbnailSize(tester), const Size(72, 45));
  });

  testWidgets('shows the back photo when it is the only one', (tester) async {
    await pump(tester, cert(back: _back));

    final photo = tester.widget<CertificationCardPhoto>(
      find.byType(CertificationCardPhoto),
    );
    expect(photo.bytes, _back);
  });

  testWidgets('falls back to the agency badge at the same size', (
    tester,
  ) async {
    await pump(tester, cert());

    expect(find.byType(CertificationCardPhoto), findsNothing);
    expect(find.text('PADI'), findsOneWidget);
    expect(thumbnailSize(tester), const Size(72, 45));
  });

  testWidgets('keeps a short agency name whole on the badge', (tester) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: Scaffold(
          body: CourseCertificationThumbnail(
            certification: cert(),
            agencyName: 'SSI',
          ),
        ),
      ),
    );

    expect(find.text('SSI'), findsOneWidget);
  });

  testWidgets('is hidden from screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, cert());

    expect(find.bySemanticsLabel('PADI'), findsNothing);
    handle.dispose();
  });
}
