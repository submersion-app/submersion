import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_schedule_dialogs.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final t0 = DateTime(2025, 1, 1);

  testWidgets('override dialog opens for a bare schedule + kind', (
    tester,
  ) async {
    final schedule = ServiceSchedule(
      id: 'sch1',
      equipmentId: 'e1',
      serviceKindId: 'general-service',
      createdAt: t0,
      updatedAt: t0,
    );
    final kind = ServiceKind(
      id: 'general-service',
      name: 'General service',
      createdAt: t0,
      updatedAt: t0,
    );

    await tester.pumpWidget(
      ProviderScope(
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

    // Dialog title includes the kind name.
    expect(find.textContaining('General service'), findsOneWidget);
  });

  group('default price (#829 review)', () {
    Future<void> openDialog(
      WidgetTester tester, {
      required ServiceSchedule schedule,
      required ServiceKind kind,
      void Function(ServiceSchedule)? onSaved,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 2400);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serviceScheduleRepositoryProvider.overrideWithValue(
              _RecordingScheduleRepository(onSaved),
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
    }

    ServiceSchedule bareSchedule() => ServiceSchedule(
      id: 'sch1',
      equipmentId: 'e1',
      serviceKindId: 'general-service',
      createdAt: t0,
      updatedAt: t0,
    );

    ServiceKind bareKind() => ServiceKind(
      id: 'general-service',
      name: 'General service',
      createdAt: t0,
      updatedAt: t0,
    );

    testWidgets('a negative default price is rejected on save', (tester) async {
      ServiceSchedule? saved;
      await openDialog(
        tester,
        schedule: bareSchedule(),
        kind: bareKind(),
        onSaved: (s) => saved = s,
      );

      await tester.enterText(
        find.byKey(const Key('service-schedule-default-cost')),
        '-5',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Rejected in place: the dialog stays open and nothing is written, so a
      // negative default cannot reach the record dialog's prefill.
      expect(saved, isNull);
      expect(find.textContaining('General service'), findsOneWidget);
    });

    testWidgets('a per-item currency can be set and cleared', (tester) async {
      ServiceSchedule? saved;
      await openDialog(
        tester,
        schedule: bareSchedule(),
        kind: bareKind(),
        onSaved: (s) => saved = s,
      );

      await tester.tap(
        find.byKey(const Key('service-schedule-default-currency')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('EUR').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved?.defaultCurrency, 'EUR');

      // And back to inherit, which is the case the review flagged: without a
      // null entry a chosen currency could never be undone.
      await openDialog(
        tester,
        schedule: bareSchedule().copyWith(defaultCurrency: 'EUR'),
        kind: bareKind(),
        onSaved: (s) => saved = s,
      );
      await tester.tap(
        find.byKey(const Key('service-schedule-default-currency')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use default currency').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved?.defaultCurrency, isNull);
    });
  });
}

/// Captures the schedule handed to updateSchedule so the tests can assert on
/// what would have been persisted without standing up a database.
class _RecordingScheduleRepository implements ServiceScheduleRepository {
  final void Function(ServiceSchedule)? onSaved;

  _RecordingScheduleRepository(this.onSaved);

  @override
  Future<void> updateSchedule(ServiceSchedule schedule) async {
    onSaved?.call(schedule);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
