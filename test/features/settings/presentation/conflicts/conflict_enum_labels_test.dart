import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('labels a stored enum name with the app label', () {
    expect(entryMethodLabeler(l10n, 'boat'), l10n.enum_entryMethod_boat);
    expect(visibilityLabeler(l10n, 'good'), l10n.enum_visibility_good);
    expect(waterTypeLabeler(l10n, 'salt'), l10n.enum_waterType_salt);
    expect(
      currentStrengthLabeler(l10n, 'strong'),
      l10n.enum_currentStrength_strong,
    );
  });

  test('returns null for a value this build does not know', () {
    expect(entryMethodLabeler(l10n, 'jetpack'), isNull);
    expect(entryMethodLabeler(l10n, ''), isNull);
  });

  test('storedAs maps an enum stored by code rather than by name', () {
    final labeler = enumLabeler<_Mode>(
      _Mode.values,
      (l, m) => m.name.toUpperCase(),
      storedAs: (m) => m.code,
    );
    expect(labeler(l10n, 'oc'), 'OPEN');
    expect(labeler(l10n, 'open'), isNull);
  });
}

enum _Mode {
  open('oc');

  const _Mode(this.code);
  final String code;
}
