import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

/// The detailed dive card's title wraps instead of ellipsizing, matching the
/// trip and equipment cards, so a long site name is always fully visible.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The detailed tile reads its slot config through a provider chain that
/// reaches SharedPreferences, so the config is pinned to the default here.
class _TestCardConfigNotifier extends CardViewConfigNotifier {
  _TestCardConfigNotifier() : super.withMode(ListViewMode.detailed);
}

const _longSiteName =
    'Centeen SCUBA park and quarry training platform on the north shore';

void main() {
  testWidgets('wraps a long title onto more lines instead of ellipsizing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(353, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          detailedCardConfigProvider.overrideWith(
            (ref) => _TestCardConfigNotifier(),
          ),
        ],
        child: DiveListTile(
          diveId: 'd1',
          diveNumber: 125,
          dateTime: DateTime(2025, 7, 19, 12, 24),
          siteName: _longSiteName,
          siteLocation: 'Ontario, Canada',
          maxDepth: 10.6,
          duration: const Duration(minutes: 28),
          isFavorite: true,
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final title = tester.renderObject<RenderParagraph>(
      find.text(_longSiteName),
    );
    final lineHeight = title.text.style!.fontSize!;
    expect(
      title.didExceedMaxLines,
      isFalse,
      reason: 'an ellipsized title hides the rest of the site name',
    );
    expect(
      title.size.height,
      greaterThan(lineHeight * 2),
      reason: 'the full name only fits on a narrow card by wrapping',
    );
  });
}
