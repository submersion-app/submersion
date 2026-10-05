import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/conflict_field_catalogue.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('an unknown column falls back to a humanized label', () {
    final field = conflictFieldFor('dives', 'someFutureColumn');
    expect(field.label(l10n), 'Some Future Column');
    expect(field.kind, FieldKind.unknown);
  });

  test('bookkeeping and foreign keys are covered without an entry', () {
    expect(isConflictFieldCovered('dives', 'hlc'), isTrue);
    expect(isConflictFieldCovered('dives', 'siteId'), isTrue);
    expect(isConflictFieldCovered('dives', 'someFutureColumn'), isFalse);
  });
}
