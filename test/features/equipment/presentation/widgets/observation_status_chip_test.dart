import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/observation_status_chip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final reg = EquipmentItem(
    id: 'reg',
    name: 'Reg',
    type: EquipmentType.regulator,
    createdAt: DateTime.utc(2026),
  );
  final dive = Dive(id: 'd1', dateTime: DateTime.utc(2026));

  EquipmentObservation obs(ObservationStatus status, {String item = 'reg'}) =>
      EquipmentObservation(
        id: 'o-${status.name}-$item',
        equipmentId: item,
        diveId: 'd1',
        observedAt: DateTime.utc(2026),
        status: status,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

  Future<void> pump(
    WidgetTester tester,
    List<EquipmentObservation> observations, {
    bool readOnly = false,
    String? operationReason,
    Future<void> Function(Future<bool> Function() operation)? runAsOperation,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          observationsForDiveProvider(
            'd1',
          ).overrideWith((ref) async => observations),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ObservationStatusChip(
              equipment: reg,
              dive: dive,
              readOnly: readOnly,
              operationReason: operationReason,
              runAsOperation:
                  runAsOperation ?? (operation) async => operation(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no observation shows the check-in affordance', (tester) async {
    await pump(tester, const []);
    expect(find.byIcon(Icons.add_task), findsOneWidget);
    expect(find.byTooltip('Check in'), findsOneWidget);
  });

  testWidgets('all OK shows a check', (tester) async {
    await pump(tester, [obs(ObservationStatus.ok)]);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('any issue shows a warning', (tester) async {
    await pump(tester, [
      obs(ObservationStatus.ok),
      obs(ObservationStatus.issue),
    ]);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
  });

  testWidgets('read-only, a state is announced as text, not as a button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, [obs(ObservationStatus.ok)], readOnly: true);
    expect(
      tester.getSemantics(find.byType(ObservationStatusChip)),
      isSemantics(label: 'Checked OK', isButton: false),
    );
    expect(find.bySemanticsLabel('Checked OK'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('read-only with nothing checked offers no check-in to a screen '
      'reader', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const [], readOnly: true);
    expect(find.byIcon(Icons.add_task), findsOneWidget);
    final node = tester.getSemantics(find.byIcon(Icons.add_task));
    expect(node, isNot(isSemantics(tooltip: 'Check in')));
    expect(node, isNot(isSemantics(isButton: true)));
    handle.dispose();
  });

  testWidgets('another item\'s issue does not count', (tester) async {
    await pump(tester, [obs(ObservationStatus.issue, item: 'fins')]);
    expect(find.byIcon(Icons.add_task), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsNothing);
  });

  testWidgets('with a reason the chip opens nothing and says why, keeping '
      'its colour', (tester) async {
    await pump(tester, [
      obs(ObservationStatus.issue),
    ], operationReason: 'Unlock to use this');

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull);
    expect(button.disabledColor, isNotNull);
    expect(find.byTooltip('Unlock to use this'), findsOneWidget);
    // The reason is the button's one tooltip; the state is still read out.
    expect(button.tooltip, 'Unlock to use this');
    expect(find.bySemanticsLabel(RegExp('Issue')), findsOneWidget);
  });

  testWidgets('with no reason a tap runs as the page\'s operation', (
    tester,
  ) async {
    final ran = <Future<bool> Function()>[];
    await pump(
      tester,
      const [],
      runAsOperation: (operation) async => ran.add(operation),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(ran, hasLength(1));
  });

  // A check-in is the gear's own record: the dive the sitting holds is
  // unchanged, so the page has nothing to read again (issue #4527).
  testWidgets('a check-in run as an operation answers that the dive is '
      'unchanged', (tester) async {
    Future<bool>? pending;
    await pump(
      tester,
      const [],
      runAsOperation: (operation) async => pending = operation(),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();

    expect(await pending, isFalse);
  });
}
