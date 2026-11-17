import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/record_list_chevron.dart';

import '../../../../helpers/record_chevron_expectations.dart';
import '../../../../helpers/test_app.dart';

/// The tile watches [settingsProvider]; the real notifier reaches for the
/// database, so stand in with a fixed [AppSettings].
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Certification _certification({DateTime? expiryDate}) => Certification(
  id: 'cert-1',
  diverId: 'diver-1',
  name: '',
  agency: CertificationAgency.padi.name,
  level: CertificationLevel.openWater.name,
  issueDate: DateTime(2023, 6, 15),
  expiryDate: expiryDate,
  createdAt: DateTime(2023, 6, 15),
  updatedAt: DateTime(2023, 6, 15),
);

/// The chevron sits one card padding from the edge in every list, and an
/// expiry badge no longer takes its place (#4639).
void main() {
  Future<void> pump(WidgetTester tester, Certification certification) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: CertificationListTile(certification: certification),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a current certification ends with the chevron', (tester) async {
    await pump(tester, _certification());

    expectChevronAtEndPadding(
      tester,
      bounds: recordCardBounds(tester),
      padding: kRecordCardDetailedPadding,
    );
  });

  testWidgets('an expired certification keeps its badge and the chevron', (
    tester,
  ) async {
    await pump(tester, _certification(expiryDate: DateTime(2000)));

    expect(find.text('Expired'), findsOneWidget);
    expectChevronAtEndPadding(
      tester,
      bounds: recordCardBounds(tester),
      padding: kRecordCardDetailedPadding,
    );
    expect(
      tester.getRect(find.text('Expired')).right,
      lessThan(tester.getRect(find.byType(RecordListChevron)).left),
      reason: 'the badge ends before the chevron',
    );
  });
}
