import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/buddy_certification_l10n.dart';
import 'package:submersion/features/certifications/presentation/certification_level_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Buddy _buddy({
  CertificationLevel? level,
  CertificationAgency? agency,
  String? title,
}) {
  final now = DateTime(2026, 1, 1);
  return Buddy(
    id: 'b1',
    name: 'Alex',
    certificationLevel: level,
    certificationAgency: agency,
    certificationTitle: title,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final fr = lookupAppLocalizations(const Locale('fr'));

  group('buddyCertificationLineL10n', () {
    test('in English it matches the English certificationLine getter', () {
      final cases = [
        _buddy(),
        _buddy(agency: CertificationAgency.padi),
        _buddy(agency: CertificationAgency.other),
        _buddy(
          level: CertificationLevel.advancedOpenWater,
          agency: CertificationAgency.padi,
          title: 'Advanced Open Water',
        ),
        _buddy(
          level: CertificationLevel.diveMaster,
          agency: CertificationAgency.padi,
          title: 'Bill Ansell',
        ),
        _buddy(agency: CertificationAgency.padi, title: 'PADI Rescue Diver'),
        _buddy(level: CertificationLevel.openWater, title: 'Open Water'),
      ];
      for (final b in cases) {
        expect(buddyCertificationLineL10n(b, en), b.certificationLine);
      }
    });

    test('a derived (level) line is rendered through the active locale', () {
      final b = _buddy(
        level: CertificationLevel.advancedNitrox,
        agency: CertificationAgency.tdi,
      );
      // The level name comes from the locale; the agency acronym does not.
      expect(
        buddyCertificationLineL10n(b, fr),
        '${CertificationLevel.advancedNitrox.localizedName(fr)} · TDI',
      );
      expect(
        buddyCertificationLineL10n(b, en),
        '${CertificationLevel.advancedNitrox.localizedName(en)} · TDI',
      );
      // English still equals the plain getter.
      expect(buddyCertificationLineL10n(b, en), b.certificationLine);
    });

    test('a custom "Name on the card" is never translated', () {
      final b = _buddy(agency: CertificationAgency.padi, title: 'Bill Ansell');
      expect(buddyCertificationLineL10n(b, fr), 'Bill Ansell · PADI');
      expect(buddyCertificationLineL10n(b, en), 'Bill Ansell · PADI');
    });

    test('an agency spelled inside the custom title is not repeated', () {
      final b = _buddy(
        agency: CertificationAgency.padi,
        title: 'PADI - Rescue Diver',
      );
      expect(buddyCertificationLineL10n(b, fr), 'PADI - Rescue Diver');
    });

    test('no certification -> null in every locale', () {
      expect(buddyCertificationLineL10n(_buddy(), en), isNull);
      expect(buddyCertificationLineL10n(_buddy(), fr), isNull);
      expect(
        buddyCertificationLineL10n(
          _buddy(agency: CertificationAgency.other),
          fr,
        ),
        isNull,
      );
    });
  });
}
