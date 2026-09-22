import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The one place the app decides how a service clock looks. A null or ok
/// clock must render nothing at all, so a caller can pass a raw map lookup
/// without filtering first, and no density may rest the signal on colour
/// alone.
void main() {
  final t0 = DateTime(2025, 1, 1);
  final now = DateTime(2026, 1, 1);

  RollupClock clock({
    String ownerId = 'reg',
    String ownerName = 'Cold water reg',
    ServiceClockSeverity severity = ServiceClockSeverity.overdue,
    DateTime? dueDate,
  }) => (
    ownerId: ownerId,
    ownerName: ownerName,
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's1',
        equipmentId: ownerId,
        serviceKindId: 'k1',
        createdAt: t0,
        updatedAt: t0,
      ),
      kind: ServiceKind(
        id: 'k1',
        name: 'General service',
        defaultIntervalDays: 365,
        isBuiltIn: true,
        createdAt: t0,
        updatedAt: t0,
      ),
      anchor: t0,
      dueDate: dueDate ?? DateTime(2025, 6, 1),
      severity: severity,
      now: now,
    ),
  );

  Widget wrap(Widget child, {Map<String, RollupClock> map = const {}}) =>
      ProviderScope(
        overrides: [
          equipmentRollupClockProvider.overrideWith((ref) async => map),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  testWidgets('renders nothing for a null clock', (tester) async {
    await tester.pumpWidget(
      wrap(const ServiceStatusIndicator(clock: null, subjectId: 'reg')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('renders nothing for an ok clock', (tester) async {
    await tester.pumpWidget(
      wrap(
        ServiceStatusIndicator(
          clock: clock(severity: ServiceClockSeverity.ok),
          subjectId: 'reg',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('compact names the kind alone when the subject owns the clock', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(ServiceStatusIndicator(clock: clock(), subjectId: 'reg')),
    );
    await tester.pumpAndSettle();
    expect(find.text('General service overdue'), findsOneWidget);
  });

  testWidgets('compact names the owning part when the clock rolls up', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ServiceStatusIndicator(
          clock: clock(ownerId: 'hose', ownerName: 'Necklace hose'),
          subjectId: 'reg',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Necklace hose'),
      findsOneWidget,
      reason: 'a rolled-up clock must say which part is overdue',
    );
  });

  testWidgets('a due-soon clock reads with its relative trigger', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ServiceStatusIndicator(
          clock: clock(
            severity: ServiceClockSeverity.dueSoon,
            dueDate: DateTime(2026, 1, 13),
          ),
          subjectId: 'reg',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('General service due in 12d'), findsOneWidget);
  });

  testWidgets('the dot density draws no text but carries a semantics label', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ServiceStatusIndicator(
          clock: clock(),
          subjectId: 'reg',
          density: ServiceIndicatorDensity.dot,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
    expect(
      find.bySemanticsLabel('General service overdue'),
      findsOneWidget,
      reason: 'colour alone must never carry the signal',
    );
  });

  testWidgets('ServiceStatusIndicatorFor looks the clock up by id', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ServiceStatusIndicatorFor(equipmentId: 'reg'),
        map: {'reg': clock()},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('General service overdue'), findsOneWidget);
  });

  testWidgets('ServiceStatusIndicatorFor renders nothing when disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ServiceStatusIndicatorFor(equipmentId: 'reg', enabled: false),
        map: {'reg': clock()},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
  });
}
