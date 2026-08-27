import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/services/certification_card_renderer.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _now = DateTime(2026, 8, 9);

Certification _cert({DateTime? issueDate}) => Certification(
  id: 'cert-1',
  name: 'Open Water Diver',
  agency: CertificationAgency.padi,
  cardNumber: '1802G4921',
  issueDate: issueDate,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  // Canvas rasterization needs the engine bindings; these are plain tests, so
  // nothing else initializes them.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<Uint8List> card() async {
    final bytes = await CertificationCardRenderer.generateCardImage(
      certification: _cert(issueDate: DateTime(2018, 3, 14)),
      diverName: 'Eric Griffin',
      l10n: l10n,
    );
    expect(bytes, isNotNull);
    return bytes!;
  }

  Future<Uint8List> certificate(DateFormatPreference dateFormat) async {
    final bytes = await CertificationCardRenderer.generateCertificateImage(
      certification: _cert(issueDate: DateTime(2018, 3, 14)),
      diverName: 'Eric Griffin',
      l10n: l10n,
      dateFormat: dateFormat,
    );
    expect(bytes, isNotNull);
    return bytes!;
  }

  group('CertificationCardRenderer.formatDate', () {
    test('orders month first for a month-first diver', () {
      expect(
        CertificationCardRenderer.formatDate(
          DateTime(2018, 3, 14),
          DateFormatPreference.mmddyyyy,
        ),
        '03/14/2018',
      );
    });

    test('orders day first for a day-first diver', () {
      expect(
        CertificationCardRenderer.formatDate(
          DateTime(2018, 3, 14),
          DateFormatPreference.ddmmyyyy,
        ),
        '14/03/2018',
      );
    });

    test('orders day first for the spelled day-first preference', () {
      expect(
        CertificationCardRenderer.formatDate(
          DateTime(2018, 3, 14),
          DateFormatPreference.dMMMYYYY,
        ),
        '14 Mar 2018',
      );
    });
  });

  group('CertificationCardRenderer card image', () {
    // The card image deliberately stays month/year, mirroring the physical
    // card it imitates -- there is no day to reorder, so it takes no date
    // preference. Only the certificate image below prints a full date.
    test('is deterministic', () async {
      expect(await card(), equals(await card()));
    });

    test('renders without an issue date', () async {
      final bytes = await CertificationCardRenderer.generateCardImage(
        certification: _cert(),
        diverName: 'Eric Griffin',
        l10n: l10n,
      );

      expect(bytes, isNotNull);
    });
  });

  group('CertificationCardRenderer certificate image', () {
    test('is deterministic for a given date preference', () async {
      expect(
        await certificate(DateFormatPreference.mmmDYYYY),
        equals(await certificate(DateFormatPreference.mmmDYYYY)),
      );
    });

    test('changes with the diver date preference', () async {
      expect(
        await certificate(DateFormatPreference.dMMMYYYY),
        isNot(equals(await certificate(DateFormatPreference.mmmDYYYY))),
      );
    });
  });
}
