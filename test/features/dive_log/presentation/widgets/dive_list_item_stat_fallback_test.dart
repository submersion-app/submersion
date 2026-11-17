import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Holds a fixed card config without touching a repository.
class _FixedCardConfigNotifier extends CardViewConfigNotifier {
  _FixedCardConfigNotifier(CardViewConfig config)
    : super.withMode(ListViewMode.compact) {
    state = config;
  }
}

void main() {
  // A saved compact config with no stat2 slot falls back to the runtime, as
  // the default config does (issue #4640).
  testWidgets('a compact config with no stat2 slot shows the runtime', (
    tester,
  ) async {
    const config = CardViewConfig(
      mode: ListViewMode.compact,
      slots: [
        CardSlotConfig(slotId: 'title', field: DiveField.siteName),
        CardSlotConfig(slotId: 'date', field: DiveField.dateTime),
        CardSlotConfig(slotId: 'stat1', field: DiveField.maxDepth),
      ],
    );

    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          compactCardConfigProvider.overrideWith(
            (ref) => _FixedCardConfigNotifier(config),
          ),
        ],
        child: DiveListItem(
          summary: DiveSummary(
            id: 'dive-1',
            dateTime: DateTime(2026, 3, 15),
            bottomTime: const Duration(minutes: 37),
            runtime: const Duration(minutes: 52),
            sortTimestamp: 0,
          ),
          diveNumber: 1,
          viewMode: ListViewMode.compact,
          diveTypeLabelResolver: (id) => id,
          diveTypeShortLabelResolver: (id) => id,
          diveTypeListVisibilityPredicate: (_) => true,
        ),
      ),
    );

    expect(find.textContaining('52'), findsOneWidget);
    expect(find.textContaining('37'), findsNothing);
  });
}
