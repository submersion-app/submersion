import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Stub that avoids the 5-second timer in the real [UpdateStatusNotifier].
class StubUpdateStatusNotifier extends StateNotifier<UpdateStatus>
    implements UpdateStatusNotifier {
  StubUpdateStatusNotifier() : super(const UpToDate());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stub that avoids platform channel dependencies.
class StubDownloadNotifier extends StateNotifier<DownloadState>
    implements DownloadNotifier {
  StubDownloadNotifier() : super(const DownloadState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stub settings notifier, so a shell test can set the toggles MainScaffold
/// reads without touching the database.
class StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  StubSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
