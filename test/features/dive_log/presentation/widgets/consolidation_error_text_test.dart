import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/services/dive_consolidation_builder.dart';
import 'package:submersion/features/dive_log/presentation/widgets/run_dive_consolidation.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// `DiveConsolidationService.apply` surfaces an invalid selection in two
/// shapes, and both have to reach the diver as the reason they hit, not as
/// "Couldn't merge the dives":
///
/// - the service's own FK-level guard, `sameComputer: <id> shares <computer>`
/// - `DiveConsolidationBuilder.build`'s wrapper around the classification,
///   `build() requires a consolidatable selection; got
///   ConsolidationInvalid(sameComputer)`
///
/// The second one is what a same-computer re-download actually produces,
/// because `classify` checks serials before the service ever looks at the
/// computer FK.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  ArgumentError builderRejection(ConsolidationInvalidReason reason) =>
      ArgumentError(
        'build() requires a consolidatable selection; got '
        '${ConsolidationInvalid(reason)}',
      );

  test('the builder\'s same-computer rejection is explained', () {
    expect(
      consolidationErrorText(
        l10n,
        builderRejection(ConsolidationInvalidReason.sameComputer),
      ),
      l10n.diveLog_consolidate_error_sameComputer,
    );
  });

  test('the service\'s own same-computer guard is explained', () {
    expect(
      consolidationErrorText(
        l10n,
        ArgumentError('sameComputer: d2 shares computer-1'),
      ),
      l10n.diveLog_consolidate_error_sameComputer,
    );
  });

  test('the builder\'s non-overlapping rejection is explained', () {
    expect(
      consolidationErrorText(
        l10n,
        builderRejection(ConsolidationInvalidReason.notOverlapping),
      ),
      l10n.diveLog_consolidate_error_notOverlapping,
    );
  });

  test('reasons without dedicated copy fall back to the generic text', () {
    for (final reason in [
      ConsolidationInvalidReason.tooFewDives,
      ConsolidationInvalidReason.mixedDivers,
    ]) {
      expect(
        consolidationErrorText(l10n, builderRejection(reason)),
        l10n.diveLog_consolidate_error_generic,
        reason: reason.name,
      );
    }
  });

  test('a non-ArgumentError failure falls back to the generic text', () {
    expect(
      consolidationErrorText(l10n, StateError('dive deleted mid-flow')),
      l10n.diveLog_consolidate_error_generic,
    );
  });
}
