import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_withdrawal.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';

import '../../../../helpers/fake_site_catalogue.dart';

void main() {
  test('answers the withdrawal the catalogue lists for an id', () async {
    const withdrawal = CatalogueWithdrawal(
      id: 'research_my_x',
      reason: CatalogueWithdrawalReason.position,
      date: '2026-12-01',
    );
    final catalogue = FakeSiteCatalogue()
      ..withdrawals = {'research_my_x': withdrawal};
    final container = ProviderContainer(
      overrides: [siteCatalogueProvider.overrideWithValue(catalogue)],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(catalogueWithdrawalProvider('research_my_x').future),
      withdrawal,
    );
    expect(
      await container.read(catalogueWithdrawalProvider('osm_node_1').future),
      isNull,
    );
  });
}
