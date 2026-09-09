import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_schedule_dialogs.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _RecordingScheduleRepository implements ServiceScheduleRepository {
  final void Function(ServiceSchedule) onSaved;
  _RecordingScheduleRepository(this.onSaved);

  @override
  Future<void> updateSchedule(ServiceSchedule schedule) async =>
      onSaved(schedule);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  final t0 = DateTime(2025, 1, 1);

  testWidgets('the dialog shows kind defaults as hints and saves overrides', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 3000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    ServiceSchedule? saved;
    final schedule = ServiceSchedule(
      id: 'sch1',
      equipmentId: 'e1',
      serviceKindId: 'regulator-service',
      createdAt: t0,
      updatedAt: t0,
    );
    final kind = ServiceKind(
      id: 'regulator-service',
      name: 'Regulator service',
      exposureIntervals: const {ExposureUnit.coldDives: 50},
      createdAt: t0,
      updatedAt: t0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceScheduleRepositoryProvider.overrideWithValue(
            _RecordingScheduleRepository((s) => saved = s),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showScheduleOverrideDialog(
                    context,
                    ref,
                    schedule: schedule,
                    kind: kind,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Interval (cold dives)'), findsOneWidget);
    expect(find.text('Default: 50'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('service-schedule-exposure-coldDives')),
      '25',
    );
    await tester.enterText(
      find.byKey(const Key('service-schedule-exposure-saltHours')),
      '150.5',
    );
    // A count unit takes whole numbers only; a fraction reads as no trigger.
    await tester.enterText(
      find.byKey(const Key('service-schedule-exposure-deepCycles')),
      '2.5',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.exposureIntervals, {
      ExposureUnit.coldDives: 25.0,
      ExposureUnit.saltHours: 150.5,
    });
  });
}
