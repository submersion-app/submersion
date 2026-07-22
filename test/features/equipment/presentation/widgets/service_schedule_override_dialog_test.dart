import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
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
}
