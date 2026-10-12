import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/router/nav_shortcut_pages.dart';
import 'package:submersion/features/connections/presentation/pages/connections_page.dart';
import 'package:submersion/features/gas_calculators/presentation/pages/gas_calculator_detail_page.dart';
import 'package:submersion/features/import_wizard/presentation/pages/universal_import_wizard_route.dart';
import 'package:submersion/features/insights/presentation/pages/insights_gas_page.dart';
import 'package:submersion/shared/widgets/nav/nav_shortcuts.dart';

void main() {
  test('every catalog shortcut has a page and nothing else does', () {
    expect(
      kNavShortcutPages.keys.toSet(),
      kNavShortcuts.map((s) => s.id).toSet(),
    );
  });

  test('no two shortcuts open the same page', () {
    // The gas calculators share a page type and differ by toolId; every other
    // shortcut opens a page type of its own, so a copy-pasted entry that
    // builds a neighbour's page shows up as a repeated type.
    final types = <Type, String>{};
    for (final entry in kNavShortcutPages.entries) {
      final page = entry.value(const {});
      if (page is GasCalculatorDetailPage) {
        expect(entry.key, 'gas-${page.toolId}');
        continue;
      }
      final other = types[page.runtimeType];
      expect(other, isNull, reason: '${entry.key} builds the page of $other');
      types[page.runtimeType] = entry.key;
    }
  });

  test('builders build the canonical page', () {
    final blender = kNavShortcutPages['gas-blender']!(const {});
    expect(blender, isA<GasCalculatorDetailPage>());
    expect((blender as GasCalculatorDetailPage).toolId, 'blender');
    expect(
      kNavShortcutPages['insights-gas']!(const {}),
      isA<InsightsGasPage>(),
    );
    expect(
      kNavShortcutPages['import-wizard']!(const {}),
      isA<UniversalImportWizardRoute>(),
    );
  });

  test('a page that reads its URL gets the alias query', () {
    final page =
        kNavShortcutPages['connections']!(const {'mode': 'graph'})
            as ConnectionsPage;
    expect(page.args.mode, 'graph');
  });
}
