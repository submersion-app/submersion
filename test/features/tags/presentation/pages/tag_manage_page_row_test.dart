import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/pages/tag_manage_page.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// How a Manage Tags row lays out its facts (issue #3746): the chip owns the
/// title line, and where the tag is offered and how often it is used sit
/// below it as two labelled lines.

// The test font draws every glyph a full em wide, so this is as long as a
// name can be and still fit a 360 dp row beside the edit button. Before
// #3746 the usage text took the row's whole width and left it nothing.
const _longName = 'Wreck training';

final _stat = TagStatistic(
  tag: Tag(
    id: 'tag1',
    diverId: 'diver1',
    name: _longName,
    colorHex: '#F97316',
    scopes: const {TagScope.dives, TagScope.sites, TagScope.equipment},
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  ),
  counts: const {
    TagScope.dives: 1058,
    TagScope.sites: 12,
    TagScope.equipment: 3,
  },
);

Widget _page() => ProviderScope(
  overrides: [
    tagStatisticsProvider.overrideWith((ref) => Future.value([_stat])),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
  ],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: TagManagePage(),
  ),
);

/// Sizes the test view to a phone, putting the default back afterwards.
void _usePhoneWidth(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('labels where the tag is offered and how often it is used', (
    tester,
  ) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    expect(find.text('For: Dives · Sites · Equipment'), findsOneWidget);
    expect(
      find.text('Used on: 1058 dives, 12 sites, 3 equipment items'),
      findsOneWidget,
    );
  });

  testWidgets('the usage line sits below the chip, not beside it', (
    tester,
  ) async {
    _usePhoneWidth(tester);
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    final chip = tester.getRect(find.byType(TagChip));
    final scopes = tester.getRect(find.textContaining('For: '));
    final usage = tester.getRect(find.textContaining('Used on: '));

    expect(scopes.top, greaterThanOrEqualTo(chip.bottom));
    expect(usage.top, greaterThanOrEqualTo(scopes.bottom));
  });

  testWidgets('a long tag name stays whole beside a long usage line', (
    tester,
  ) async {
    _usePhoneWidth(tester);
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    final name = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byType(TagChip), matching: find.text(_longName)),
    );
    expect(name.didExceedMaxLines, isFalse);
  });

  testWidgets('the edit button is the only control at the trailing edge', (
    tester,
  ) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    final row = tester.widget<ListTile>(find.byType(ListTile));
    expect(row.trailing, isA<IconButton>());
  });
}
