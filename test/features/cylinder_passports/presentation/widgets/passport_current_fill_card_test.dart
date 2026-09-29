import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_current_fill_card.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_nfc.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  const id = 'eq-1';
  const pid = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  const tank = EquipmentItem(
    id: id,
    name: 'Faber 12',
    type: EquipmentType.tank,
  );

  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  /// Logs a 32 percent fill through the card's own Log a fill sheet.
  Future<AppLocalizations> logFill(
    WidgetTester tester, {
    required NfcSupport support,
  }) async {
    final overrides = await getBaseOverrides(
      nfcTagService: FakeNfcTagService(
        supportValue: support,
        waitForCancel: true,
      ),
    );
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          cylinderFillRepositoryProvider.overrideWithValue(_CapturingRepo()),
          equipmentItemProvider(id).overrideWith((ref) async => tank),
          passportIdProvider(id).overrideWith((ref) async => pid),
          serviceClockStatusesProvider(
            id,
          ).overrideWith((ref) async => const []),
          serviceRecordsForEquipmentProvider(
            id,
          ).overrideWith((ref) async => const []),
          newestFillProvider(id).overrideWith((ref) async => null),
        ],
        child: const SingleChildScrollView(
          child: PassportCurrentFillCard(equipmentId: id, passportId: pid),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PassportCurrentFillCard)),
    );
    await tester.tap(find.text(l10n.passport_fill_log));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('logFill_o2')), '32');
    await tester.ensureVisible(find.text(l10n.forms_save));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.forms_save));
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('saving a fill with NFC on offers to write it to the tag', (
    tester,
  ) async {
    final l10n = await logFill(tester, support: NfcSupport.enabled);
    expect(find.text(l10n.passport_fill_writeToTagTitle), findsOneWidget);
    expect(find.textContaining('EAN32'), findsOneWidget);
  });

  testWidgets('saving a fill with NFC off offers nothing', (tester) async {
    final l10n = await logFill(tester, support: NfcSupport.disabled);
    expect(find.text(l10n.passport_fill_writeToTagTitle), findsNothing);
  });
}

class _CapturingRepo extends CylinderFillRepository {
  @override
  Future<CylinderFill> create(CylinderFill fill) async => fill;
}
