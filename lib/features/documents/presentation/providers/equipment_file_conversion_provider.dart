import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/compaction/database_compaction_monitor.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/documents/data/services/equipment_file_converter.dart';
import 'package:submersion/features/media/presentation/providers/media_bytes_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

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
        // Through the deletion coordinator, so an uploaded copy is queued
        // for removal from the media store with the row.
        unlink: (id) =>
            ref.read(mediaUnlinkServiceProvider).unlinkFromEquipment([id]),
      );
    });

/// Runs [EquipmentFileConverter] at launch and after each sync (issue
/// #3333), one run at a time. A call while one runs queues a single
/// follow-up (however many calls arrive), so rows a sync pulled after the
/// running pass read its list still get converted. Contains its own
/// failures, returning null: a conversion that could not run must not fail
/// the launch or the sync.
// no-tick: the value is a CLOSURE, not a query result.
final equipmentFileConversionProvider =
    Provider<Future<EquipmentFileConversionResult?> Function()>((ref) {
      Future<EquipmentFileConversionResult?>? inFlight;
      Future<EquipmentFileConversionResult?>? followUp;
      Future<EquipmentFileConversionResult?> runOnce() async {
        try {
          final converter = await ref.read(
            equipmentFileConverterFactoryProvider,
          )();
          final result = await converter.run();
          // Then the look at free space this run's callers (launch, sync)
          // want; three pragmas, so every run rather than only converting
          // ones, and the one place it is wired.
          await ref.read(databaseCompactionMonitorProvider)();
          return result;
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

      Future<EquipmentFileConversionResult?> start() => inFlight = runOnce();
      return () {
        final running = inFlight;
        if (running == null) return start();
        // Already queued: every later caller shares it.
        return followUp ??= running.then((_) {
          followUp = null;
          return start();
        });
      };
    });
