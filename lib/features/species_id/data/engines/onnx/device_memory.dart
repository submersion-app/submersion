import 'dart:io';

import 'package:submersion/features/species_id/domain/entities/vision_memory.dart';

/// The least memory a Windows or Linux PC needs to run marine life
/// identification: 8 GB machines, with the same 6.5 GiB cut-off as iPhone. A
/// device reports a little less than it is sold with, and a 6 GB one can
/// never report more than 6 GiB.
const int pcMinimumMemoryBytes = 6979321856; // 6.5 GiB

/// The least memory an Android phone or tablet needs: 8 GB, as on iPhone. A
/// 6 GB phone (the maintainer's Pixel 6a) was measured and failed: Android
/// stopped the app twice with the models loaded (piece 3, section 5 of
/// docs/design/specs/2026-11-19-marine-life-identification-3-other-platforms-design.md,
/// and docs/design/findings/2026-11-17-marine-life-phone-memory.md).
const int androidMinimumMemoryBytes = 6979321856; // 6.5 GiB

/// The device's memory, for the floor and the debug log's readout.
abstract interface class DeviceMemory {
  /// All the memory the device reports, or null when it cannot be read.
  Future<int?> totalBytes();

  /// The app's memory now.
  Future<VisionMemory> reading();
}

/// `MemTotal` of `/proc/meminfo`, in bytes.
int? parseMemTotal(String procMeminfo) => _kb(procMeminfo, 'MemTotal');

/// `MemAvailable` of `/proc/meminfo`, in bytes.
int? parseMemAvailable(String procMeminfo) => _kb(procMeminfo, 'MemAvailable');

/// The resident set (`VmRSS`) and its peak (`VmHWM`) of `/proc/self/status`,
/// in bytes.
({int? rss, int? hwm}) parseProcStatus(String procStatus) =>
    (rss: _kb(procStatus, 'VmRSS'), hwm: _kb(procStatus, 'VmHWM'));

int? _kb(String text, String key) {
  final match = RegExp(
    '^$key:\\s+(\\d+)\\s*kB',
    multiLine: true,
  ).firstMatch(text);
  final kb = match == null ? null : int.tryParse(match.group(1)!);
  return kb == null ? null : kb * 1024;
}

/// Android and Linux: `/proc`. On Android [systemState] (the frames
/// channel's device state) gives what the system can still free and whether
/// it reports itself low on memory.
class ProcDeviceMemory implements DeviceMemory {
  ProcDeviceMemory({
    Future<String> Function(String path)? read,
    Future<({bool lowMemory, int availableBytes})> Function()? systemState,
  }) : _read = read ?? ((path) => File(path).readAsString()),
       _systemState = systemState;

  final Future<String> Function(String path) _read;
  final Future<({bool lowMemory, int availableBytes})> Function()? _systemState;

  @override
  Future<int?> totalBytes() async {
    final meminfo = await _readOrNull('/proc/meminfo');
    return meminfo == null ? null : parseMemTotal(meminfo);
  }

  @override
  Future<VisionMemory> reading() async {
    final status = parseProcStatus(
      await _readOrNull('/proc/self/status') ?? '',
    );
    final system = await _systemState?.call();
    final meminfo = system == null ? await _readOrNull('/proc/meminfo') : null;
    return VisionMemory(
      footprintBytes: status.rss ?? 0,
      footprintPeakBytes: status.hwm,
      availableBytes:
          system?.availableBytes ??
          (meminfo == null ? null : parseMemAvailable(meminfo)),
      availableIsDeviceWide: true,
      lowMemory: system?.lowMemory,
    );
  }

  /// [path]'s text, or null where the system will not let it be read.
  Future<String?> _readOrNull(String path) async {
    try {
      return await _read(path);
    } on FileSystemException {
      return null;
    }
  }
}
