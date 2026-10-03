import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../../helpers/mock_providers.dart';

/// Holds one Refine group's draft the way the panel does, so a test can
/// drive the group's controls and read the draft back.
class GroupHarness {
  DiveFilterState draft;
  late ProviderContainer container;
  GroupHarness(this.draft);
}

typedef GroupBuilder =
    Widget Function(
      DiveFilterState draft,
      ValueChanged<DiveFilterState> onChanged,
    );

Future<GroupHarness> pumpGroup(
  WidgetTester tester,
  GroupBuilder build, {
  DiveFilterState initial = const DiveFilterState(),
  List<Override> overrides = const [],
  List<Override>? baseOverrides,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(440, 1600);
  addTearDown(tester.view.reset);
  final harness = GroupHarness(initial);
  final base = baseOverrides ?? await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...base, ...overrides].cast(),
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                harness.container = ProviderScope.containerOf(context);
                return build(
                  harness.draft,
                  (next) => setState(() => harness.draft = next),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}
