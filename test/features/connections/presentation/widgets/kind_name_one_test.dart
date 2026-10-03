import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('kindNameOne names each kind in the singular', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
      {for (final k in ConnectionKind.values) k: kindNameOne(l10n, k)},
      {
        ConnectionKind.buddy: 'Buddy',
        ConnectionKind.site: 'Site',
        ConnectionKind.trip: 'Trip',
        ConnectionKind.diveCenter: 'Dive center',
        ConnectionKind.equipment: 'Equipment',
        ConnectionKind.species: 'Species',
        ConnectionKind.tag: 'Tag',
        ConnectionKind.diveType: 'Dive type',
        ConnectionKind.diveComputer: 'Dive computer',
        ConnectionKind.course: 'Course',
      },
    );
  });
}
