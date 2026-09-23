import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/status_colors.dart';
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

  testWidgets('full renders the status line above its full trigger line', (
    tester,
  ) async {
    // This density has no production caller yet, so nothing else would
    // notice it regressing.
    await tester.pumpWidget(
      wrap(
        ServiceStatusIndicator(
          clock: clock(),
          subjectId: 'reg',
          density: ServiceIndicatorDensity.full,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('General service overdue'), findsOneWidget);
    // The second line is the long joined trigger, the same wording the
    // service clocks card shows, not the short chip form.
    expect(find.textContaining('Overdue since'), findsOneWidget);
  });

  testWidgets('full carries the status line as one semantics label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        ServiceStatusIndicator(
          clock: clock(),
          subjectId: 'reg',
          density: ServiceIndicatorDensity.full,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('General service overdue')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('full applies a color override to both of its lines', (
    tester,
  ) async {
    // The detail header puts this on a solid status fill, where the default
    // grey of the trigger line would not read. The override is the fill's
    // own onContainer, and it must reach the second line too.
    await tester.pumpWidget(
      wrap(
        ServiceStatusIndicator(
          clock: clock(),
          subjectId: 'reg',
          density: ServiceIndicatorDensity.full,
          color: const Color(0xFF00FF00),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(
        text.style?.color,
        const Color(0xFF00FF00),
        reason: '"${text.data}" ignored the override',
      );
    }
  });

  testWidgets('full renders nothing for an ok clock', (tester) async {
    await tester.pumpWidget(
      wrap(
        ServiceStatusIndicator(
          clock: clock(severity: ServiceClockSeverity.ok),
          subjectId: 'reg',
          density: ServiceIndicatorDensity.full,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
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

  testWidgets('ServiceStatusIndicatorForAny reports the worst member clock', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ServiceStatusIndicatorForAny(equipmentIds: ['fins', 'reg']),
        map: {
          'fins': clock(
            ownerId: 'fins',
            ownerName: 'Jets',
            severity: ServiceClockSeverity.dueSoon,
            dueDate: DateTime(2026, 1, 13),
          ),
          'reg': clock(),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Cold water reg'),
      findsOneWidget,
      reason: 'the overdue member outranks the due-soon one',
    );
    expect(
      find.textContaining('Jets'),
      findsNothing,
      reason: 'only the worst member is reported, not every member',
    );
  });

  testWidgets('ServiceStatusIndicatorForAny renders nothing when all are ok', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ServiceStatusIndicatorForAny(equipmentIds: ['fins', 'reg']),
        map: {
          'fins': clock(
            ownerId: 'fins',
            ownerName: 'Jets',
            severity: ServiceClockSeverity.ok,
          ),
          'reg': clock(severity: ServiceClockSeverity.ok),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('ServiceStatusIndicatorForAny names the member that is due', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ServiceStatusIndicatorForAny(equipmentIds: ['fins', 'reg']),
        map: {'reg': clock()},
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Cold water reg'),
      findsOneWidget,
      reason:
          'a set tile names the item needing service, since the set itself '
          'is not the thing that is overdue',
    );
  });

  testWidgets('the dot fits a Chip avatar slot without forcing a size', (
    tester,
  ) async {
    // The planner and weight-rig chips put the indicator in `avatar`, which
    // lays its child out under tight constraints. A dot that demanded its
    // own size, or an empty box that did not, would overflow or throw.
    await tester.pumpWidget(
      wrap(
        const InputChip(
          avatar: ServiceStatusIndicatorFor(
            equipmentId: 'reg',
            density: ServiceIndicatorDensity.dot,
          ),
          label: Text('Cold water reg'),
        ),
        map: {'reg': clock()},
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Cold water reg'), findsOneWidget);
  });

  testWidgets('a Chip avatar with an ok clock still lays out', (tester) async {
    await tester.pumpWidget(
      wrap(
        const InputChip(
          avatar: ServiceStatusIndicatorFor(
            equipmentId: 'reg',
            density: ServiceIndicatorDensity.dot,
          ),
          label: Text('Cold water reg'),
        ),
        map: {'reg': clock(severity: ServiceClockSeverity.ok)},
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Cold water reg'), findsOneWidget);
  });

  testWidgets('a color override wins, for a status-filled surface', (
    tester,
  ) async {
    // The summary card fills itself with the status container colour, where
    // the accent would not read. Such a surface supplies the foreground its
    // own fill guarantees instead.
    await tester.pumpWidget(
      wrap(
        ServiceStatusIndicator(
          clock: clock(),
          subjectId: 'reg',
          color: const Color(0xFF00FF00),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(find.text('General service overdue'));
    expect(label.style?.color, const Color(0xFF00FF00));
  });

  testWidgets('without an override the severity accent is used', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(ServiceStatusIndicator(clock: clock(), subjectId: 'reg')),
    );
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(find.text('General service overdue'));
    expect(label.style?.color, StatusColors.light.alert.accent);
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
