import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_mode_label.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() {
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  test('diveModeLabel returns the localized name for each mode', () {
    expect(diveModeLabel(l10n, DiveMode.oc), 'Open Circuit');
    expect(diveModeLabel(l10n, DiveMode.ccr), 'Closed Circuit Rebreather');
    expect(diveModeLabel(l10n, DiveMode.scr), 'Semi-Closed Rebreather');
    expect(diveModeLabel(l10n, DiveMode.gauge), 'Gauge');
  });
}
