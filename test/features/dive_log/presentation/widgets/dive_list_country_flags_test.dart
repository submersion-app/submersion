import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/country_flag.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Dive cards show the site's country flag, as site rows do (issue #5001):
/// the detailed card beside its location line, the compact card before a
/// title that names the site. The Dives switch governs both.
class _Detailed extends CardViewConfigNotifier {
  _Detailed() : super.withMode(ListViewMode.detailed);
}

class _Compact extends CardViewConfigNotifier {
  _Compact(DiveField title) : super.withMode(ListViewMode.compact) {
    state = CardViewConfig(
      mode: ListViewMode.compact,
      slots: [
        CardSlotConfig(slotId: 'title', field: title),
        const CardSlotConfig(slotId: 'date', field: DiveField.dateTime),
        const CardSlotConfig(slotId: 'stat1', field: DiveField.maxDepth),
        const CardSlotConfig(slotId: 'stat2', field: DiveField.runtime),
      ],
    );
  }
}

DiveSummary _summary({String? country = 'Belize', String? code = 'BZ'}) =>
    DiveSummary(
      id: 'd1',
      diveNumber: 142,
      dateTime: DateTime(2026, 3, 12, 9, 40),
      maxDepth: 38,
      runtime: const Duration(minutes: 42),
      siteName: 'Blue Hole',
      siteRegion: 'Lighthouse Reef',
      siteCountry: country,
      siteCountryCode: code,
      sortTimestamp: 0,
    );

Future<void> _pump(
  WidgetTester tester,
  ListViewMode mode, {
  DiveSummary? summary,
  DiveField title = DiveField.siteName,
  bool flags = true,
}) async {
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...await getBaseOverrides(),
        detailedCardConfigProvider.overrideWith((ref) => _Detailed()),
        compactCardConfigProvider.overrideWith((ref) => _Compact(title)),
        showDiveCountryFlagsProvider.overrideWithValue(flags),
      ],
      locale: const Locale('en'),
      child: DiveListItem(
        summary: summary ?? _summary(),
        diveNumber: 142,
        viewMode: mode,
        diveTypeLabelResolver: (id) => id,
        diveTypeShortLabelResolver: (id) => id,
        diveTypeListVisibilityPredicate: (_) => false,
        onTap: () {},
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('detailed card draws the flag beside the location', (
    tester,
  ) async {
    await _pump(tester, ListViewMode.detailed);
    expect(find.text('Lighthouse Reef, Belize'), findsOneWidget);
    expect(tester.widget<CountryFlag>(find.byType(CountryFlag)).code, 'BZ');
  });

  testWidgets('compact card draws the flag before a site-name title', (
    tester,
  ) async {
    await _pump(tester, ListViewMode.compact);
    expect(tester.widget<CountryFlag>(find.byType(CountryFlag)).code, 'BZ');
    expect(
      tester.getTopLeft(find.byType(CountryFlag)).dx,
      lessThan(tester.getTopLeft(find.text('Blue Hole')).dx),
    );
  });

  testWidgets('compact card draws no flag when the title is not the site', (
    tester,
  ) async {
    await _pump(tester, ListViewMode.compact, title: DiveField.maxDepth);
    expect(find.byType(CountryFlag), findsNothing);
  });

  testWidgets('a site with no recognised country draws no flag and no gap', (
    tester,
  ) async {
    await _pump(tester, ListViewMode.compact);
    final flagged = tester.getTopLeft(find.byType(CountryFlag)).dx;
    await _pump(
      tester,
      ListViewMode.compact,
      summary: _summary(country: 'Atlantis', code: null),
    );
    expect(find.byType(CountryFlag), findsNothing);
    expect(tester.getTopLeft(find.text('Blue Hole')).dx, flagged);
  });

  testWidgets('compact card draws no flag for a code with no country text', (
    tester,
  ) async {
    await _pump(
      tester,
      ListViewMode.compact,
      summary: _summary(country: null, code: 'BZ'),
    );
    expect(find.byType(CountryFlag), findsNothing);
  });

  for (final mode in [ListViewMode.detailed, ListViewMode.compact]) {
    testWidgets('the Dives switch off hides the ${mode.name} card flag', (
      tester,
    ) async {
      await _pump(tester, mode, flags: false);
      expect(find.byType(CountryFlag), findsNothing);
    });
  }

  testWidgets("compact card's label names the country with the flag", (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, ListViewMode.compact);
    expect(find.bySemanticsLabel(RegExp('Blue Hole, Belize')), findsOneWidget);
    handle.dispose();
  });

  testWidgets("compact card's label trims the country it names", (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      ListViewMode.compact,
      summary: _summary(country: ' Belize '),
    );
    expect(
      find.bySemanticsLabel(RegExp('Blue Hole, Belize(?! )')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets("compact card's label names the country once under a location "
      'title', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, ListViewMode.compact, title: DiveField.siteLocation);
    expect(find.text('Lighthouse Reef, Belize'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Belize')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Belize[\s\S]*Belize')),
      findsNothing,
      reason: 'the visible title already names the country',
    );
    handle.dispose();
  });

  testWidgets("compact card's label leaves the country out with flags off", (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, ListViewMode.compact, flags: false);
    expect(find.bySemanticsLabel(RegExp('Belize')), findsNothing);
    handle.dispose();
  });
}
