import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/documents/data/services/equipment_file_converter.dart';
import 'package:submersion/features/media/presentation/providers/media_bytes_providers.dart';

/// Builds the converter; a seam for tests.
// no-tick: the value is a factory closure, not a query result.
final equipmentFileConverterFactoryProvider =
    Provider<Future<EquipmentFileConverter> Function()>((ref) {
      return () async => EquipmentFileConverter(
        readBytes: (item) async {
          final resolved = await ref.read(mediaBytesProvider(item).future);
          // Read once to copy into the library; not worth keeping in memory.
          ref.invalidate(mediaBytesProvider(item));
          return resolved.isUnavailable ? null : resolved.bytes;
        },
        prefs: await SharedPreferences.getInstance(),
      );
    });

/// Runs [EquipmentFileConverter] at launch and after each sync (issue
/// #3333), one run at a time: a call while one runs shares it instead of
/// reading the same files again. Contains its own failures, returning null:
/// a conversion that could not run must not fail the launch or the sync.
// no-tick: the value is a CLOSURE, not a query result.
final equipmentFileConversionProvider =
    Provider<Future<EquipmentFileConversionResult?> Function()>((ref) {
      Future<EquipmentFileConversionResult?>? inFlight;
      Future<EquipmentFileConversionResult?> runOnce() async {
        try {
          final converter = await ref.read(
            equipmentFileConverterFactoryProvider,
          )();
          return await converter.run();
        } on Object catch (e, stackTrace) {
          LoggerService.forClass(EquipmentFileConverter).warning(
            'Gear file conversion failed',
            error: e,
            stackTrace: stackTrace,
          );
          return null;
        } finally {
          inFlight = null;
        }
      }

      return () => inFlight ??= runOnce();
    });
