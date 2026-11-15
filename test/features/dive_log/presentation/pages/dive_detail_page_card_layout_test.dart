import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' as riverpod show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/responsive_section_pair.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

typedef Override = riverpod.Override;

/// How paired cards share their row on the dive detail page (issue #4583):
/// both columns end level, and the card after a pair can move up beside it.
/// The pairing rules themselves are in dive_detail_page_paired_sections_test.

/// Mock SettingsNotifier that doesn't access the database.
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppSettings _settingsWithVisibleSections(List<DiveDetailSectionId> visible) =>
    AppSettings(
      diveDetailSections: [
        for (final id in DiveDetailSectionId.values)
          DiveDetailSectionConfig(id: id, visible: visible.contains(id)),
      ],
    );

Widget _buildTestWidget({
  required Dive dive,
  required AppSettings settings,
  List<Override> extraOverrides = const [],
}) => ProviderScope(
  overrides: [
    diveProvider(dive.id).overrideWith((ref) async => dive),
    diveDataSourcesProvider(
      dive.id,
    ).overrideWith((ref) async => <DiveDataSource>[]),
    settingsProvider.overrideWith((ref) => _MockSettingsNotifier(settings)),
    ...extraOverrides,
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: DiveDetailPage(diveId: dive.id),
  ),
);

/// Bumped to make the buddies read reload, as a dependency changing does.
class _Trigger extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final _trigger = NotifierProvider<_Trigger, int>(_Trigger.new);

List<Override> _renderOverrides(
  String diveId,
  SharedPreferences prefs, {
  List<BuddyWithRole> buddies = const [],
  Future<void> Function()? reloadGate,
}) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  buddiesForDiveProvider(diveId).overrideWith((ref) async {
    if (ref.watch(_trigger) > 0) await reloadGate?.call();
    return buddies;
  }),
  diveSightingsProvider(diveId).overrideWith((ref) async => <Sighting>[]),
  buddySignaturesForDiveProvider(
    diveId,
  ).overrideWith((ref) async => <Signature>[]),
  surfaceIntervalProvider(diveId).overrideWith((ref) async => null),
  tankPressuresProvider(
    diveId,
  ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
];

final _buddy = BuddyWithRole(
  buddy: Buddy(
    id: 'b1',
    name: 'Alice',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  roles: [DiveRole.builtInBuddy()],
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Buddies + Signatures', () {
    // A reload driven by a dependency keeps the last answer: the dive has
    // buddies. Read as "still loading", the pair would come apart into two
    // full-width cards and form again once the read lands.
    testWidgets('the pair holds together while the buddies reload', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = Dive(
        id: 'buddies-reload',
        dateTime: DateTime(2026, 3, 15, 10, 0),
      );
      final reload = Completer<void>();
      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: _settingsWithVisibleSections([
            DiveDetailSectionId.buddies,
            DiveDetailSectionId.signatures,
          ]),
          extraOverrides: _renderOverrides(
            dive.id,
            prefs,
            buddies: [_buddy],
            reloadGate: () => reload.future,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ResponsiveSectionPair), findsOneWidget);

      ProviderScope.containerOf(
        tester.element(find.byType(DiveDetailPage)),
      ).read(_trigger.notifier).bump();
      await tester.pump();

      expect(find.byType(ResponsiveSectionPair), findsOneWidget);

      reload.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
    });

    // Issue #4583: the shorter card left blank space under it before the
    // next card; now both columns end level.
    testWidgets('the two cards end level (wide pane)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = Dive(
        id: 'buddies-level',
        dateTime: DateTime(2026, 3, 15, 10, 0),
      );
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.buddies,
        DiveDetailSectionId.signatures,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: _renderOverrides(dive.id, prefs, buddies: [_buddy]),
        ),
      );
      await tester.pumpAndSettle();

      final pair = find.byType(ResponsiveSectionPair);
      final middle = tester.getCenter(pair).dx;
      final bottoms = <bool, double>{};
      for (final card
          in find
              .descendant(of: pair, matching: find.byType(Card))
              .evaluate()) {
        final box = card.renderObject! as RenderBox;
        final rect = box.localToGlobal(Offset.zero) & box.size;
        final left = rect.center.dx < middle;
        bottoms[left] = math.max(bottoms[left] ?? 0, rect.bottom);
      }
      expect(bottoms.keys, containsAll([true, false]));
      expect(bottoms[true], bottoms[false]);
    });

    // Issue #4583: the card straight after a pair is laid out with it, so it
    // can move up under the shorter half; a full-width one never is.
    for (final (next, slots) in [
      (DiveDetailSectionId.notes, true),
      (DiveDetailSectionId.media, false),
    ]) {
      testWidgets(
        '${next.name} after the pair ${slots ? 'is' : 'is not'} laid out '
        'with it',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1000, 3000));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final dive = Dive(
            id: 'buddies-slot-${next.name}',
            dateTime: DateTime(2026, 3, 15, 10, 0),
            notes: 'Calm water and good visibility.',
          );
          final settings = _settingsWithVisibleSections([
            DiveDetailSectionId.buddies,
            DiveDetailSectionId.signatures,
            next,
          ]);

          await tester.pumpWidget(
            _buildTestWidget(
              dive: dive,
              settings: settings,
              extraOverrides: _renderOverrides(
                dive.id,
                prefs,
                buddies: [_buddy],
              ),
            ),
          );
          await tester.pumpAndSettle();

          final pair = find.byType(ResponsiveSectionPair);
          expect(pair, findsOneWidget);
          final inPair = find.descendant(
            of: pair,
            matching: find.byKey(ValueKey('diveSection_${next.name}')),
          );
          expect(inPair, slots ? findsOneWidget : findsNothing);
        },
      );
    }
  });
}
