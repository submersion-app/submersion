import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// A profile with the settings it resolves to: its own row, or the defaults
/// when it has none.
typedef DiverWithSettings = ({Diver diver, AppSettings settings});

/// Every profile on the device with its settings, read in parallel. The
/// list_divers tool and the units resource both build on this, so a diver's
/// units resolve the same way wherever an agent asks.
Future<List<DiverWithSettings>> diversWithSettings(
  DiverRepository divers,
  DiverSettingsRepository settings,
) async {
  final all = await divers.getAllDivers();
  final resolved = await Future.wait([
    for (final diver in all)
      settings
          .getSettingsForDiver(diver.id)
          .then((s) => s ?? const AppSettings()),
  ]);
  return [
    for (var i = 0; i < all.length; i++) (diver: all[i], settings: resolved[i]),
  ];
}
