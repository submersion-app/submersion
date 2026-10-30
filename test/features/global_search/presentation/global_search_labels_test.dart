import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/global_search/presentation/global_search_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const units = UnitFormatter(AppSettings());

  String title(GlobalSearchHit hit) => globalSearchHitTitle(hit, l10n, units);

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
