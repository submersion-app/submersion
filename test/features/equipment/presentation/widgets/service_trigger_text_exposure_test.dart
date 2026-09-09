import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_trigger_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<String> format(
    WidgetTester tester, {
    required Map<ExposureUnit, ClockUsage> usageByUnit,
  }) async {
    late String result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            result = formatServiceTriggerText(
              context,
              units: const UnitFormatter(AppSettings()),
              now: DateTime(2026, 7, 16),
              usageByUnit: usageByUnit,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('count units render whole numbers', (tester) async {
    final text = await format(
      tester,
      usageByUnit: const {
        ExposureUnit.coldDives: ClockUsage(interval: 50, since: 12),
      },
    );
    expect(text, '38 of 50 cold dives left');
  });

  testWidgets('hour units render one decimal and clamp at zero', (
    tester,
  ) async {
    final text = await format(
      tester,
      usageByUnit: const {
        ExposureUnit.saltHours: ClockUsage(interval: 200, since: 210.25),
      },
    );
    expect(text, '0.0 of 200.0 salt-water hours left');
  });

  testWidgets('legacy dives and map units join in unit order', (tester) async {
    final text = await format(
      tester,
      usageByUnit: const {
        ExposureUnit.deepCycles: ClockUsage(interval: 20, since: 5),
        ExposureUnit.dives: ClockUsage(interval: 100, since: 40),
      },
    );
    expect(text, '60 of 100 dives left · 15 of 20 deep dives left');
  });
}
