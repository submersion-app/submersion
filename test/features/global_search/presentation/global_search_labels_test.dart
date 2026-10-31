import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/certification_entry_display.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/global_search/presentation/global_search_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const units = UnitFormatter(AppSettings());

  String title(GlobalSearchHit hit) => globalSearchHitTitle(hit, l10n, units);

  test('every kind has a heading and an icon of its own', () {
    final labels = {
      for (final kind in GlobalSearchKind.values)
        globalSearchKindLabel(l10n, kind),
    };
    final icons = {
      for (final kind in GlobalSearchKind.values) globalSearchKindIcon(kind),
    };
    expect(labels, hasLength(GlobalSearchKind.values.length));
    expect(icons, hasLength(GlobalSearchKind.values.length));
  });

  group('subtitle', () {
    String? subtitle(GlobalSearchHit hit) =>
        globalSearchHitSubtitle(hit, l10n, units);

    test('a dive shows its date and depth, in the diver\'s units', () {
      final date = DateTime.utc(2024, 3, 14);
      expect(
        subtitle(
          GlobalSearchHit(
            kind: GlobalSearchKind.dives,
            id: 'd1',
            title: 'Salt Pier',
            date: date,
            depthMeters: 18,
          ),
        ),
        '${units.formatMonthDayWithYear(date)} \u00b7 '
        '${units.formatDepth(18)}',
      );
    });

    test('a row titled by its date does not repeat it', () {
      expect(
        subtitle(
          GlobalSearchHit(
            kind: GlobalSearchKind.gpsTracks,
            id: 'g1',
            date: DateTime.utc(2024, 3, 14),
          ),
        ),
        isNull,
      );
    });

    test('details are joined', () {
      expect(
        subtitle(
          const GlobalSearchHit(
            kind: GlobalSearchKind.sites,
            id: 's1',
            title: 'Salt Pier',
            details: ['Kralendijk', 'Bonaire'],
          ),
        ),
        'Kralendijk \u00b7 Bonaire',
      );
    });

    test('a certification names its agency, not the stored id', () {
      expect(
        subtitle(
          const GlobalSearchHit(
            kind: GlobalSearchKind.certifications,
            id: 'z1',
            title: 'Rescue Diver',
            details: ['padi', 'CARD-7'],
          ),
        ),
        '${CertificationCatalog.builtInOnly.agency('padi').localizedName(l10n)}'
        ' \u00b7 CARD-7',
      );
    });
  });

  test('a record with no name leads with its date', () {
    final date = DateTime.utc(2024, 3, 14);
    expect(
      title(
        GlobalSearchHit(kind: GlobalSearchKind.gpsTracks, id: 'g1', date: date),
      ),
      units.formatMonthDayWithYear(date),
    );
  });

  test('an untitled document goes by its type', () {
    expect(
      title(
        const GlobalSearchHit(
          kind: GlobalSearchKind.documents,
          id: 'm1',
          type: 'permit',
        ),
      ),
      l10n.documents_type_permit,
    );
  });

  test('a dive leads with its number', () {
    expect(
      title(
        const GlobalSearchHit(
          kind: GlobalSearchKind.dives,
          id: 'd1',
          title: 'Salt Pier',
          number: 42,
        ),
      ),
      '#42 \u00b7 Salt Pier',
    );
  });

  test('a built-in species shows in the language of the diver', () {
    final de = lookupAppLocalizations(const Locale('de'));
    expect(
      globalSearchHitTitle(
        const GlobalSearchHit(
          kind: GlobalSearchKind.species,
          id: 'sp_whale_shark',
          title: 'Whale Shark',
        ),
        de,
        units,
      ),
      de.species_whale_shark_name,
    );
  });
}
