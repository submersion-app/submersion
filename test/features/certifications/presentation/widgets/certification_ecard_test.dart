import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_card_photo.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier([super.initial = const AppSettings()]);

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A valid 1x1 transparent PNG, so the image decoder has real bytes.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
  'hKmMIQAAAABJRU5ErkJggg==',
);

final _now = DateTime(2026, 8, 9);

Certification _makeCert({
  String name = 'Open Water Diver',
  CertificationAgency agency = CertificationAgency.padi,
  CertificationLevel? level,
  String? cardNumber,
  DateTime? issueDate,
  DateTime? expiryDate,
  String? instructorName,
  Uint8List? photoFront,
  Uint8List? photoBack,
}) {
  return Certification(
    id: 'cert-1',
    name: name,
    agency: agency,
    level: level,
    cardNumber: cardNumber,
    issueDate: issueDate,
    expiryDate: expiryDate,
    instructorName: instructorName,
    photoFront: photoFront,
    photoBack: photoBack,
    createdAt: _now,
    updatedAt: _now,
  );
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required Certification certification,
  String diverName = 'Eric Griffin',
  bool showBack = false,
  double width = 320,
  DateFormatPreference dateFormat = DateFormatPreference.mmmDYYYY,
}) async {
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(AppSettings(dateFormat: dateFormat)),
        ),
      ],
      child: Center(
        child: SizedBox(
          width: width,
          child: CertificationEcard(
            certification: certification,
            diverName: diverName,
            showBack: showBack,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('CertificationEcard back face', () {
    testWidgets('renders the uploaded photo when photoBack is set', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        certification: _makeCert(photoBack: _onePixelPng),
        showBack: true,
      );

      expect(find.byType(CertificationCardPhoto), findsOneWidget);
    });

    testWidgets('renders the generated back when photoBack is null', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        certification: _makeCert(instructorName: 'Jane Doe'),
        showBack: true,
      );

      expect(find.byType(CertificationCardPhoto), findsNothing);
      expect(find.text('INSTRUCTOR'), findsOneWidget);
      expect(find.text('Jane Doe'), findsOneWidget);
    });
  });

  group('CertificationEcard front face', () {
    testWidgets('renders the uploaded photo when photoFront is set', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        certification: _makeCert(photoFront: _onePixelPng),
      );

      expect(find.byType(CertificationCardPhoto), findsOneWidget);
    });

    testWidgets('photo card repeats agency, name and diver in the strip', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        certification: _makeCert(
          photoFront: _onePixelPng,
          cardNumber: '1802G4921',
        ),
      );

      // Exact joined strings, not textContaining: the generated card renders
      // these same facts as separate Text widgets, so only a whole-line match
      // proves the info strip is what is on screen.
      expect(find.text('PADI  -  Open Water Diver'), findsOneWidget);
      expect(find.text('ERIC GRIFFIN  -  1802G4921'), findsOneWidget);
    });

    testWidgets('photo card strip omits a missing card number', (tester) async {
      await _pumpCard(
        tester,
        certification: _makeCert(photoFront: _onePixelPng),
      );

      // The detail line is the diver name alone, with no trailing separator.
      expect(find.text('ERIC GRIFFIN'), findsOneWidget);
      expect(find.textContaining('ERIC GRIFFIN  -  '), findsNothing);
    });

    testWidgets('photo card still shows the expired badge', (tester) async {
      await _pumpCard(
        tester,
        certification: _makeCert(
          photoFront: _onePixelPng,
          expiryDate: DateTime(2020, 1, 1),
        ),
      );

      // Assert the photo path is what rendered, so this cannot pass by way of
      // the generated card's own badge.
      expect(find.byType(CertificationCardPhoto), findsOneWidget);
      expect(find.text('EXPIRED'), findsOneWidget);
    });

    testWidgets('renders the generated front when photoFront is null', (
      tester,
    ) async {
      await _pumpCard(tester, certification: _makeCert());

      expect(find.byType(CertificationCardPhoto), findsNothing);
      expect(find.text('Open Water Diver'), findsOneWidget);
    });
  });

  group('CertificationEcard generated front field grid', () {
    testWidgets('shows labelled diver, card number, issue and expiry cells', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        certification: _makeCert(
          cardNumber: '1802G4921',
          issueDate: DateTime(2018, 3, 14),
          expiryDate: DateTime(2030, 3, 14),
        ),
      );

      expect(find.text('DIVER'), findsOneWidget);
      expect(find.text('ERIC GRIFFIN'), findsOneWidget);
      expect(find.text('CARD NO.'), findsOneWidget);
      expect(find.text('1802G4921'), findsOneWidget);
      expect(find.text('ISSUED'), findsOneWidget);
      expect(find.text('VALID UNTIL'), findsOneWidget);
    });

    // The printed card face keeps the compact month/year of the physical card
    // it imitates. There is no day to reorder, so the date preference has
    // nothing to change here -- only the spoken Semantics label below, which
    // has no width budget, carries the diver's full date.
    testWidgets('keeps the card face month/year under a day-first preference', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        dateFormat: DateFormatPreference.ddmmyyyy,
        certification: _makeCert(
          issueDate: DateTime(2018, 3, 14),
          expiryDate: DateTime(2030, 3, 14),
        ),
      );

      expect(find.text('Mar 2018'), findsOneWidget);
      expect(find.text('Mar 2030'), findsOneWidget);
      expect(find.text('14/03/2018'), findsNothing);
    });

    testWidgets('omits the expiry cell when the certification never expires', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        certification: _makeCert(issueDate: DateTime(2018, 3, 14)),
      );

      expect(find.text('ISSUED'), findsOneWidget);
      expect(find.text('VALID UNTIL'), findsNothing);
    });

    testWidgets('omits the card number cell when the card number is empty', (
      tester,
    ) async {
      await _pumpCard(tester, certification: _makeCert(cardNumber: ''));

      expect(find.text('DIVER'), findsOneWidget);
      expect(find.text('CARD NO.'), findsNothing);
    });

    testWidgets('omits the card number cell when the card number is null', (
      tester,
    ) async {
      await _pumpCard(tester, certification: _makeCert());

      expect(find.text('DIVER'), findsOneWidget);
      expect(find.text('CARD NO.'), findsNothing);
    });

    testWidgets('renders no Spacer, so the card centre is not left blank', (
      tester,
    ) async {
      await _pumpCard(tester, certification: _makeCert());

      expect(find.byType(Spacer), findsNothing);
    });

    testWidgets('shows a legacy derived name once, not duplicated', (
      tester,
    ) async {
      // Rows created before 2026-08 auto-filled name from agency + level, so
      // the stored name repeats what the structured fields already say.
      // certificationTitle collapses that to the level alone.
      await _pumpCard(
        tester,
        certification: _makeCert(
          name: 'PADI : Open Water',
          level: CertificationLevel.openWater,
        ),
      );

      expect(find.text('Open Water'), findsOneWidget);
      expect(find.text('PADI : Open Water'), findsNothing);
    });

    testWidgets('shows the level as a subtitle only under a custom name', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        certification: _makeCert(
          name: 'Cenote Guide Course',
          level: CertificationLevel.openWater,
        ),
      );

      expect(find.text('Cenote Guide Course'), findsOneWidget);
      expect(find.text('Open Water'), findsOneWidget);
    });

    testWidgets('does not overflow on a narrow card with every field filled', (
      tester,
    ) async {
      // The densest card the UI can produce: a long two-line name, a level,
      // and all four grid cells, on the narrowest phone width the wallet's
      // 0.85 viewportFraction yields. A RenderFlex overflow here surfaces as a
      // test failure via the exception the framework reports during layout.
      await _pumpCard(
        tester,
        width: 280,
        certification: _makeCert(
          name: 'Advanced Open Water Diver and Enriched Air Specialist',
          level: CertificationLevel.advancedOpenWater,
          cardNumber: '1802G4921',
          issueDate: DateTime(2018, 3, 14),
          expiryDate: DateTime(2030, 3, 14),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('VALID UNTIL'), findsOneWidget);
    });
  });

  group('CertificationEcard semantics label', () {
    testWidgets('speaks the issue date month-first for a month-first diver', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        dateFormat: DateFormatPreference.mmddyyyy,
        certification: _makeCert(issueDate: DateTime(2018, 3, 14)),
      );

      expect(_cardSemanticsLabel(tester), contains('issued 03/14/2018'));
    });

    testWidgets('speaks the issue date day-first for a day-first diver', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        dateFormat: DateFormatPreference.ddmmyyyy,
        certification: _makeCert(issueDate: DateTime(2018, 3, 14)),
      );

      expect(_cardSemanticsLabel(tester), contains('issued 14/03/2018'));
    });

    testWidgets('omits the issue date when the certification has none', (
      tester,
    ) async {
      await _pumpCard(tester, certification: _makeCert());

      expect(_cardSemanticsLabel(tester), isNot(contains('issued')));
    });
  });
}

/// The label on the [Semantics] wrapper [CertificationEcard] builds itself.
String _cardSemanticsLabel(WidgetTester tester) {
  final semantics = find
      .descendant(
        of: find.byType(CertificationEcard),
        matching: find.byType(Semantics),
      )
      .first;
  return tester.widget<Semantics>(semantics).properties.label ?? '';
}
