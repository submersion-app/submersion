import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/auto_connect_settings_provider.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/auto_connect_global_switch.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/clock_sync_global_switch.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_auto_download_card.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Records opt-out writes instead of writing through a repository.
class _RecordingDiveComputerNotifier
    extends StateNotifier<AsyncValue<List<DiveComputer>>>
    implements DiveComputerNotifier {
  _RecordingDiveComputerNotifier()
    : super(const AsyncValue.data(<DiveComputer>[]));

  final List<({String id, bool disabled})> optOuts = [];

  @override
  Future<void> setAutoDownloadDisabled(String id, bool disabled) async {
    optOuts.add((id: id, disabled: disabled));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _host(
  Widget child, {
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('AutoConnectGlobalSwitch turns the device-local setting off '
      '(issue #3361)', (tester) async {
    await tester.pumpWidget(_host(const AutoConnectGlobalSwitch()));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AutoConnectGlobalSwitch)),
    );
    expect(container.read(autoConnectKnownComputersProvider), isTrue);

    await tester.tap(
      find.byKey(const ValueKey('auto_connect_known_computers_switch')),
    );
    await tester.pump();

    expect(container.read(autoConnectKnownComputersProvider), isFalse);
  });

  testWidgets('the switch is announced by its title, as a SwitchListTile '
      'is (issue #4005)', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(const AutoConnectGlobalSwitch()));

    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('auto_connect_known_computers_switch')),
      ),
      isSemantics(label: 'Auto-connect known computers', isToggled: true),
    );
    semantics.dispose();
  });

  testWidgets('a long title wraps on a phone instead of being cut off '
      '(issue #4005)', (tester) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        const Column(
          children: [ClockSyncGlobalSwitch(), AutoConnectGlobalSwitch()],
        ),
        locale: const Locale('fr'),
      ),
    );

    for (final title in [
      "Synchroniser l'horloge des ordinateurs de plongée",
      'Connexion automatique aux ordinateurs connus',
    ]) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
      expect(paragraph.didExceedMaxLines, isFalse, reason: title);
    }
  });

  testWidgets('DiveComputerAutoDownloadCard saves the per-computer opt-out '
      '(issue #3361)', (tester) async {
    final notifier = _RecordingDiveComputerNotifier();
    final computer = DiveComputer(
      id: 'dc-1',
      name: 'Perdix 2',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      _host(
        DiveComputerAutoDownloadCard(computer: computer),
        overrides: [
          diveComputerNotifierProvider.overrideWith((ref) => notifier),
        ],
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('dive_computer_auto_download_disabled')),
    );
    await tester.pump();

    // Only the opt-out: a whole-row write from this card's copy of the
    // computer would put back whatever changed on the record since.
    expect(notifier.optOuts, [(id: 'dc-1', disabled: true)]);
  });
}
