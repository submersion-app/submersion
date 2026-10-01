import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// A settings notifier whose load the test finishes by hand.
///
/// Until [finishLoad], [state] holds [initial] and
/// [SettingsNotifier.settingsLoaded] is pending, exactly as the real
/// [SettingsNotifier] behaves while it reads a diver's row. [initial] is the
/// `const AppSettings()` placeholder at startup, or the previous diver's
/// settings during the reload a diver switch starts (issue #2564).
///
/// [initialLoad] is pending as well when [switching] is false (startup), and
/// already complete when it is true (the first load finished long ago).
class DeferredSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  DeferredSettingsNotifier({
    AppSettings initial = const AppSettings(),
    this.switching = false,
  }) : super(initial);

  final bool switching;
  final _load = Completer<void>();

  @override
  Future<void> get initialLoad =>
      switching ? Future<void>.value() : _load.future;

  @override
  Future<void> get settingsLoaded => _load.future;

  void finishLoad(AppSettings stored) {
    state = stored;
    _load.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
