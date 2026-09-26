import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/max_width_fraction.dart';

import '../../../../helpers/mock_providers.dart';

/// A rollup badge names the due part, and a part's name can be long. The
/// tile's trailing column must not take the row from the title, which used to
/// wrap one letter per line (issue #1981).
void main() {
  final t0 = DateTime(2025, 1, 1);
  const title = 'Regulator Assembley - Apeks & DGX Long Hose';
  const partName =
      '2nd Stage / Necklace / DGX Gears Xtra / XTRA Doubles Reg Package / '
      '409181';
  const reg = EquipmentItem(
    id: 'reg',
    name: title,
    type: EquipmentType.regulator,
  );

  RollupClock rollup(ServiceClockSeverity severity) => (
    ownerId: 'second-stage',
    ownerName: partName,
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's1',
        equipmentId: 'second-stage',
        serviceKindId: 'reg-service',
        createdAt: t0,
        updatedAt: t0,
      ),
      kind: ServiceKind(
        id: 'reg-service',
        name: 'Regulator service',
        defaultIntervalDays: 365,
        isBuiltIn: false,
        createdAt: t0,
        updatedAt: t0,
      ),
      anchor: t0,
      dueDate: DateTime(2026, 1, 1),
      severity: severity,
      now: DateTime(2026, 7, 1),
    ),
  );

  Widget wrap(Map<String, RollupClock> map, {EquipmentItem item = reg}) =>
      ProviderScope(
        overrides: [
          equipmentRollupClockProvider.overrideWith((ref) async => map),
          equipmentComponentsIndexProvider.overrideWith(
            (ref) async => ComponentsIndex.empty,
          ),
          activeEquipmentProvider.overrideWith((ref) async => [item]),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: EquipmentListTile(item: item)),
          ),
        ),
      );

  Future<void> pumpAt(
    WidgetTester tester,
    double width,
    ServiceClockSeverity severity,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap({'reg': rollup(severity)}));
    await tester.pumpAndSettle();
  }

  for (final width in [375.0, 560.0]) {
    for (final severity in [
      ServiceClockSeverity.overdue,
      ServiceClockSeverity.dueSoon,
    ]) {
      testWidgets('a long part name leaves the title its room '
          '(${severity.name}, ${width.toInt()}px)', (tester) async {
        await pumpAt(tester, width, severity);

        final tileWidth = tester.getSize(find.byType(ListTile)).width;
        final titleWidth = tester.getSize(find.text(title)).width;
        final statusWidth = tester
            .getSize(find.textContaining('Regulator service'))
            .width;

        // Before the fix the status took the row (a debug build asserted
        // that trailing consumed the tile) and the title got a sliver.
        expect(tester.takeException(), isNull);
        expect(statusWidth, lessThanOrEqualTo(tileWidth / 3));
        expect(titleWidth, greaterThan(statusWidth));
      });
    }
  }

  testWidgets('the capped badge still announces the whole status', (
    tester,
  ) async {
    await pumpAt(tester, 375, ServiceClockSeverity.overdue);
    // RegExp form: the ListTile merges its children's labels into one node.
    expect(
      find.bySemanticsLabel(
        RegExp(RegExp.escape('$partName: Regulator service overdue')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a short trailing keeps its natural width', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(560, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const {}));
    await tester.pumpAndSettle();

    // The cap is a ceiling, not a reservation: the type label alone
    // shrink-wraps and the title keeps the rest.
    final trailingWidth = tester.getSize(find.byType(MaxWidthFraction)).width;
    final tileWidth = tester.getSize(find.byType(ListTile)).width;
    expect(trailingWidth, tester.getSize(find.text('Regulator')).width);
    expect(trailingWidth, lessThan(tileWidth / 3));
  });

  group('every capped label stays on one line', () {
    // At this width the cap is narrower than the type label itself, so an
    // unbounded Text would wrap and overflow the tile's trailing height.
    Future<void> expectSingleLines(WidgetTester tester, Widget app) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(240, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final labels = find.descendant(
        of: find.byType(MaxWidthFraction),
        matching: find.byType(Text),
      );
      expect(labels, findsWidgets);
      for (final label in labels.evaluate()) {
        // One line of bodySmall or labelSmall is 16 px in the test font.
        expect(
          tester.getSize(find.byWidget(label.widget)).height,
          lessThan(24),
        );
      }
    }

    testWidgets('type label and service status', (tester) async {
      await expectSingleLines(
        tester,
        wrap({'reg': rollup(ServiceClockSeverity.overdue)}),
      );
    });

    testWidgets('type label and equipment status', (tester) async {
      await expectSingleLines(
        tester,
        wrap(
          const {},
          item: reg.copyWith(status: EquipmentStatus.needsService),
        ),
      );
    });
  });
}
