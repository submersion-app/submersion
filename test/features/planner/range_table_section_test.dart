import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/range_table_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('range section renders the depth x time grid', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: const SingleChildScrollView(child: RangeTableSection()),
      ),
    );
    // Hidden with no plan.
    expect(find.text('Base'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(RangeTableSection)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 40, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();

    // Row and column headers share the "Base" label (2 axes).
    expect(find.text('Base'), findsNWidgets(2));
    // Default deltas produce +/-3 and +/-6 depth rows and +/-5/10 columns.
    expect(find.text('+3m'), findsOneWidget);
    expect(find.text('−6m'), findsOneWidget);
    expect(find.text('+10′'), findsOneWidget);
    // Cells carry TTS minute values.
    expect(find.textContaining('′'), findsWidgets);
  });
}
