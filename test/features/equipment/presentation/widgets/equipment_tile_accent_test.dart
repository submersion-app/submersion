import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The list-icon accent toggle tints the equipment tile's leading avatar --
/// but must never mask the overdue-service status colour.
void main() {
  final t0 = DateTime(2025, 1, 1);

  DueClock worstClock(EquipmentItem item, ServiceClockSeverity severity) => (
    item: item,
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's1',
        equipmentId: item.id,
        serviceKindId: 'hydro',
        createdAt: t0,
        updatedAt: t0,
      ),
      kind: ServiceKind(
        id: 'hydro',
        name: 'Hydrostatic test',
        defaultIntervalDays: 1825,
        isBuiltIn: true,
        createdAt: t0,
        updatedAt: t0,
      ),
      anchor: t0,
      dueDate: DateTime(2026, 1, 1),
      severity: severity,
      now: DateTime(2026, 7, 1),
    ),
  );

  final theme = ThemeData(
    brightness: Brightness.light,
    extensions: const <ThemeExtension<dynamic>>[FeatureAccentColors.light],
  );

  Widget wrap(
    Widget child, {
    Map<String, DueClock> worst = const {},
    bool accentsOn = false,
  }) {
    return ProviderScope(
      overrides: [
        equipmentWorstClockProvider.overrideWith((ref) async => worst),
        settingsProvider.overrideWith(
          (ref) =>
              _StubSettingsNotifier(AppSettings(accentListIcons: accentsOn)),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  const item = EquipmentItem(id: 'e1', name: 'AL80', type: EquipmentType.tank);

  testWidgets('avatar takes the equipment accent when the toggle is on', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const EquipmentListTile(item: item), accentsOn: true),
    );
    await tester.pumpAndSettle();

    final accent = FeatureAccentColors.light.of('equipment')!;
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor, accent.withValues(alpha: 0.15));

    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(CircleAvatar),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.color, accent);
  });

  testWidgets('avatar keeps its theme colors when the toggle is off', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const EquipmentListTile(item: item)));
    await tester.pumpAndSettle();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor, theme.colorScheme.tertiaryContainer);
  });

  testWidgets('overdue status colour wins over the accent', (tester) async {
    await tester.pumpWidget(
      wrap(
        const EquipmentListTile(item: item),
        worst: {'e1': worstClock(item, ServiceClockSeverity.overdue)},
        accentsOn: true,
      ),
    );
    await tester.pumpAndSettle();

    // The overdue signal must survive: tinting it with the feature accent
    // would hide a service warning behind a cosmetic preference.
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor, theme.colorScheme.errorContainer);

    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(CircleAvatar),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.color, theme.colorScheme.onErrorContainer);
  });
}

class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
