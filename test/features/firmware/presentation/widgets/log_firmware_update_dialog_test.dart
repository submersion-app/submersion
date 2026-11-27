import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/firmware/data/firmware_update_recorder.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_recorder_provider.dart';
import 'package:submersion/features/firmware/presentation/widgets/log_firmware_update_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Logging a firmware update by hand (issue #5104).
void main() {
  late String? savedIntl;
  setUp(() {
    savedIntl = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedIntl);

  const item = EquipmentItem(
    id: 'dpv',
    name: 'Seal 2',
    type: EquipmentType.dpv,
  );

  Future<_FakeRecorder> open(WidgetTester tester, {String? suggested}) async {
    final recorder = _FakeRecorder();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          firmwareUpdateRecorderProvider.overrideWithValue(recorder),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLogFirmwareUpdateDialog(
                  context,
                  item: item,
                  suggestedVersion: suggested,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return recorder;
  }

  testWidgets('an empty version is refused', (tester) async {
    final recorder = await open(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the version'), findsOneWidget);
    expect(recorder.calls, isEmpty);
  });

  testWidgets('the suggested version is saved with today and the notes', (
    tester,
  ) async {
    final recorder = await open(tester, suggested: '2.4.0');
    expect(find.text('Log firmware update'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('firmware-log-notes')),
      'Updated on the boat',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final call = recorder.calls.single;
    expect(call.equipmentId, 'dpv');
    expect(call.version, '2.4.0');
    expect(call.notes, 'Updated on the boat');
    final today = DateTime.now();
    expect(
      DateTime(call.date.year, call.date.month, call.date.day),
      DateTime(today.year, today.month, today.day),
    );
    expect(find.text('Log firmware update'), findsNothing);
  });
}

typedef _Call = ({
  String equipmentId,
  String version,
  DateTime date,
  String notes,
});

class _FakeRecorder extends FirmwareUpdateRecorder {
  final List<_Call> calls = [];

  @override
  Future<void> logUpdate({
    required String equipmentId,
    required String version,
    required DateTime date,
    String notes = '',
  }) async {
    calls.add((
      equipmentId: equipmentId,
      version: version,
      date: date,
      notes: notes,
    ));
  }
}
