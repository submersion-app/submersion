import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/auto_connect_settings_provider.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/auto_connect_global_switch.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_auto_download_card.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Records `update` calls instead of writing through a repository.
class _RecordingDiveComputerNotifier
    extends StateNotifier<AsyncValue<List<DiveComputer>>>
    implements DiveComputerNotifier {
  _RecordingDiveComputerNotifier()
    : super(const AsyncValue.data(<DiveComputer>[]));

  final List<DiveComputer> updates = [];

  @override
  Future<void> update(DiveComputer computer) async {
    updates.add(computer);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _host(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
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

    expect(notifier.updates, hasLength(1));
    expect(notifier.updates.single.id, 'dc-1');
    expect(notifier.updates.single.autoDownloadDisabled, isTrue);
  });
}
