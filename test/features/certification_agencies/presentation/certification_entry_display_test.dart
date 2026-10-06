import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_agency.dart';
import 'package:submersion/features/certification_agencies/presentation/certification_entry_display.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/l10n/arb/app_localizations_fr.dart';

const _uuid = '2b1f7c3e-9d8a-4c55-8e21-0f6a1b2c3d4e';

void main() {
  final en = AppLocalizationsEn();
  final c = CertificationCatalog.builtInOnly;

  test('built-ins use their localized names', () {
    expect(c.agency('other').localizedName(en), 'Other');
    expect(c.agency('other').localizedName(AppLocalizationsFr()), 'Autre');
    expect(c.level('openWater').localizedName(en), 'Open Water');
  });

  test('a custom name is shown verbatim in every locale', () {
    final custom = CertificationCatalog(
      agencies: [
        CustomCertificationAgency(
          id: _uuid,
          diverId: 'a',
          name: 'Club X',
          colorArgb: 0xFF3B82F6,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );
    expect(custom.agency(_uuid).localizedName(AppLocalizationsFr()), 'Club X');
  });

  test('a UUID fallback reads as unknown, a slug fallback as itself', () {
    expect(c.agency(_uuid).localizedName(en), 'Unknown agency');
    expect(c.agency('newAgency').localizedName(en), 'newAgency');
    expect(c.level(_uuid).localizedName(en), 'Unknown certification');
    expect(c.level('futureLevel').localizedName(en), 'futureLevel');
  });
}
