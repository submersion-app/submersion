import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/connections/presentation/info/connections_info.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const units = UnitFormatter(AppSettings());

  String label(DiveTerm term) => diveTermEntry(l10n, units, term).term;
  List<String> labels(InfoContent content) =>
      content.terms.map((e) => e.term).toList();

  test('hops are explained only around one entity, where they show', () {
    final around = connectionsInfo(l10n, units, showsHops: true);
    final map = connectionsInfo(l10n, units, showsHops: false);
    expect(labels(around), contains(label(DiveTerm.hops)));
    expect(labels(map), isNot(contains(label(DiveTerm.hops))));
    expect(labels(map), contains(label(DiveTerm.colourBy)));
    expect(labels(map), contains(label(DiveTerm.weightedEdges)));
  });

  test('the colour control is named as the panel names it', () {
    expect(label(DiveTerm.colourBy), l10n.connections_highlight_title);
  });
}
