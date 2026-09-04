import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

/// #1512: the certification tile dated its subtitle with `DateFormat.yMMMd()`,
/// so a diver on DD/MM/YYYY still read "Jun 15, 2023".
///
/// Both hosts pin `Locale('en')`. These assertions are numeric, but intl
/// renders digits in the locale's own numbering system, so an unpinned host
/// could produce Arabic-Indic digits on an `ar` machine.

/// The tile watches [settingsProvider]; the real notifier reaches for the
/// database, so stand in with a fixed [AppSettings].
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// `Override` is sealed and not re-exported, so the helper stays dynamic,
// matching `testApp`'s `overrides` parameter.
List<dynamic> _overridesFor(DateFormatPreference format) => [
  settingsProvider.overrideWith(
    (ref) => _TestSettingsNotifier(AppSettings(dateFormat: format)),
  ),
];

Certification _certification() => Certification(
  id: 'cert-1',
  diverId: 'diver-1',
  name: '',
  agency: CertificationAgency.padi,
  level: CertificationLevel.openWater,
  issueDate: DateTime(2023, 6, 15),
  createdAt: DateTime(2023, 6, 15),
  updatedAt: DateTime(2023, 6, 15),
);

void main() {
  group('CertificationListTile honours the diver date format', () {
    testWidgets('subtitle carries the day-first issue date', (tester) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: _overridesFor(DateFormatPreference.ddmmyyyy),
          child: CertificationListTile(certification: _certification()),
        ),
      );

      expect(
        find.textContaining('15/06/2023'),
        findsOneWidget,
        reason: 'the subtitle must follow Manage - Units, not the UI locale',
      );
      expect(find.textContaining('Jun 15, 2023'), findsNothing);
    });

    testWidgets('subtitle carries the ISO issue date', (tester) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: _overridesFor(DateFormatPreference.yyyymmdd),
          child: CertificationListTile(certification: _certification()),
        ),
      );

      expect(find.textContaining('2023-06-15'), findsOneWidget);
    });
  });
}
