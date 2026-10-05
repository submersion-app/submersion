import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_header_status.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// A purchase whose write fails, as a locked or full database would.
class _FailingPurchaseRepository extends EquipmentRepository {
  @override
  Future<void> markEquipmentPurchased(String id, {DateTime? today}) =>
      Future.error(StateError('database locked'));
}

EquipmentItem _item(EquipmentStatus status, {bool isActive = true}) =>
    EquipmentItem(
      id: 'x',
      name: 'x',
      type: EquipmentType.regulator,
      status: status,
      isActive: isActive,
    );

/// The detail header's status line (#2025): an inactive item's real status,
/// and the purchase action for wishlist gear.
void main() {
  group('headerStatusOf', () {
    test('active gear gets no chip', () {
      expect(headerStatusOf(_item(EquipmentStatus.active)), isNull);
    });

    test('inactive gear names its own status', () {
      for (final s in [
        EquipmentStatus.sold,
        EquipmentStatus.lost,
        EquipmentStatus.wanted,
      ]) {
        expect(headerStatusOf(_item(s, isActive: false)), s, reason: '$s');
      }
    });

    test('wanted gear is named even with isActive left true', () {
      // An import that defaults isActive must still offer the purchase.
      expect(
        headerStatusOf(_item(EquipmentStatus.wanted)),
        EquipmentStatus.wanted,
      );
    });

    test('a legacy inactive row reads as retired', () {
      expect(
        headerStatusOf(_item(EquipmentStatus.needsService, isActive: false)),
        EquipmentStatus.retired,
      );
    });
  });

  group('EquipmentHeaderStatus', () {
    late EquipmentRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = EquipmentRepository();
    });

    tearDown(tearDownTestDatabase);

    Future<void> pump(
      WidgetTester tester,
      EquipmentItem item, {
      EquipmentRepository? repo,
    }) async {
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            equipmentRepositoryProvider.overrideWithValue(repo ?? repository),
          ].cast(),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: EquipmentHeaderStatus(item: item)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sold gear shows Sold, not Retired', (tester) async {
      await pump(tester, _item(EquipmentStatus.sold, isActive: false));

      expect(find.text('Sold'), findsOneWidget);
      expect(find.text('Retired'), findsNothing);
      expect(find.text('Mark as purchased'), findsNothing);
    });

    testWidgets('wanted gear shows its chip and buys in one tap', (
      tester,
    ) async {
      final created = await repository.createEquipment(
        const EquipmentItem(
          id: '',
          name: 'Dream Reg',
          type: EquipmentType.regulator,
          status: EquipmentStatus.wanted,
          isActive: false,
        ),
      );
      await pump(tester, created);
      expect(find.text('Wanted'), findsOneWidget);

      await tester.tap(find.text('Mark as purchased'));
      await tester.pumpAndSettle();

      final stored = await repository.getEquipmentById(created.id);
      expect(stored!.status, EquipmentStatus.active);
      expect(stored.isActive, isTrue);
      expect(stored.purchaseDate, isNotNull);
      expect(find.text('Moved to your active gear'), findsOneWidget);
    });

    testWidgets('a failed purchase says so instead of failing silently', (
      tester,
    ) async {
      await pump(
        tester,
        _item(EquipmentStatus.wanted, isActive: false),
        repo: _FailingPurchaseRepository(),
      );

      await tester.tap(find.text('Mark as purchased'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('database locked'), findsOneWidget);
      expect(find.text('Moved to your active gear'), findsNothing);
    });

    testWidgets('active gear renders nothing', (tester) async {
      await pump(tester, _item(EquipmentStatus.active));

      expect(find.byType(Chip), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
