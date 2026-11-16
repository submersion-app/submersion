import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_exposure_totals.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_trend_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// A dive computer's Equipment page puts the Dive computer section, and so
/// its download actions, directly under the item header, above the Details
/// card (issue #4622).
void main() {
  late String? savedIntlLocale;
  setUp(() {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedIntlLocale);

  Future<void> pumpPage(
    WidgetTester tester,
    EquipmentItem item, {
    bool computersFail = false,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 1600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          equipmentItemProvider(item.id).overrideWith((ref) async => item),
          equipmentDiveCountProvider(item.id).overrideWith((ref) async => 0),
          equipmentDiveTimeProvider(item.id).overrideWith((ref) async => 0),
          equipmentTripCountProvider(item.id).overrideWith((ref) async => 0),
          equipmentComponentsProvider(
            item.id,
          ).overrideWith((ref) async => const []),
          equipmentPartOfProvider(
            item.id,
          ).overrideWith((ref) async => const []),
          equipmentExposureTotalsProvider(
            item.id,
          ).overrideWith((ref) async => EquipmentExposureTotals.empty),
          equipmentConditionProvider(
            item.id,
          ).overrideWith((ref) async => const []),
          conditionTrendProvider((
            equipmentId: item.id,
            kind: null,
          )).overrideWith((ref) async => null),
          conditionTrendProvider((
            equipmentId: item.id,
            kind: ConditionTrendKind.scrubberMinutes,
          )).overrideWith((ref) async => null),
          childEquipmentProvider(item.id).overrideWith((ref) async => const []),
          observationsForEquipmentProvider(
            item.id,
          ).overrideWith((ref) async => const []),
          equipmentWorstClockProvider.overrideWith((ref) async => {}),
          serviceRecordNotifierProvider(
            item.id,
          ).overrideWith((ref) => _MockServiceRecordNotifier()),
          // Added by hand: the section offers to connect and download.
          computersForEquipmentProvider(item.id).overrideWith(
            (ref) async => computersFail
                ? throw StateError('no computers')
                : const <DiveComputer>[],
          ),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EquipmentDetailPage(equipmentId: item.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the dive computer section sits above the Details card', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const EquipmentItem(
        id: 'perdix',
        name: 'Perdix',
        type: EquipmentType.computer,
      ),
    );

    final connect = find.text('Connect and download');
    expect(connect, findsOneWidget);
    expect(
      tester.getTopLeft(connect).dy,
      lessThan(tester.getTopLeft(find.text('Details')).dy),
    );
  });

  testWidgets('other gear shows no dive computer section', (tester) async {
    await pumpPage(
      tester,
      const EquipmentItem(id: 'bcd', name: 'BCD', type: EquipmentType.bcd),
    );

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Connect and download'), findsNothing);
  });

  testWidgets('a section that fails to load leaves no gap above Details', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const EquipmentItem(
        id: 'perdix',
        name: 'Perdix',
        type: EquipmentType.computer,
      ),
      computersFail: true,
    );

    expect(find.text('Connect and download'), findsNothing);
    Finder cardOf(Finder text) =>
        find.ancestor(of: text, matching: find.byType(Card)).first;
    final headerBottom = tester
        .getBottomLeft(cardOf(find.text('Perdix').first))
        .dy;
    final detailsTop = tester.getTopLeft(cardOf(find.text('Details'))).dy;
    // The one gap every card on the page has, not two.
    expect(detailsTop - headerBottom, 24);
  });
}

class _MockServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  _MockServiceRecordNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
