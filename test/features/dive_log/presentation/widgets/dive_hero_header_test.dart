import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_hero_header.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  const units = UnitFormatter(AppSettings());
  final dive = Dive(
    id: 'd1',
    diveNumber: 7,
    name: 'Shark Point',
    dateTime: DateTime.utc(2026, 5, 1, 9),
    runtime: const Duration(minutes: 52),
    bottomTime: const Duration(minutes: 41, seconds: 30),
  );

  Future<void> pump(WidgetTester tester, DiveHeroHeader header) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diveTypesProvider.overrideWith(
            (ref) async => const <DiveTypeEntity>[],
          ),
        ],
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: Scaffold(body: header),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('falls back to the dive\'s own runtime and bottom time', (
    tester,
  ) async {
    await pump(tester, DiveHeroHeader(dive: dive, units: units));

    expect(find.text('#7'), findsOneWidget);
    expect(find.text('Shark Point'), findsOneWidget);
    expect(find.text('52 min'), findsOneWidget);
    expect(find.text('41 min'), findsOneWidget);
  });

  testWidgets('shows the stat values and title slot it is given', (
    tester,
  ) async {
    await pump(
      tester,
      DiveHeroHeader(
        dive: dive,
        units: units,
        runtimeText: '60 min',
        bottomTimeText: '45 min',
        belowTitle: const Text('2 findings'),
      ),
    );

    expect(find.text('60 min'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('52 min'), findsNothing);
    expect(find.text('2 findings'), findsOneWidget);
  });
}
