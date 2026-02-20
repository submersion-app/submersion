import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/dive_computer_api.g.dart',
    swiftOut: 'ios/Classes/DiveComputerApi.g.swift',
    kotlinOut:
        'android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.submersion.libdivecomputer'),
    gobjectHeaderOut: 'linux/dive_computer_api.g.h',
    gobjectSourceOut: 'linux/dive_computer_api.g.cc',
    gobjectOptions: GObjectOptions(module: 'LibdivecomputerPlugin'),
    cppHeaderOut: 'windows/dive_computer_api.g.h',
    cppSourceOut: 'windows/dive_computer_api.g.cc',
    cppOptions: CppOptions(namespace: 'libdivecomputer_plugin'),
  ),
)
// === Enums ===
enum TransportType { ble, usb, serial, infrared }

// === Data Classes ===

class DeviceDescriptor {
  const DeviceDescriptor({
    required this.vendor,
    required this.product,
    required this.model,
    required this.transports,
  });
  final String vendor;
  final String product;
  final int model;
  final List<TransportType> transports;
}

class DiscoveredDevice {
  const DiscoveredDevice({
    required this.vendor,
    required this.product,
    required this.model,
    required this.address,
    this.name,
    required this.transport,
  });
  final String vendor;
  final String product;
  final int model;
  final String address;
  final String? name;
  final TransportType transport;
}

class ProfileSample {
  const ProfileSample({
    required this.timeSeconds,
    required this.depthMeters,
    this.temperatureCelsius,
    this.pressureBar,
    this.tankIndex,
    this.heartRate,
  });
  final int timeSeconds;
  final double depthMeters;
  final double? temperatureCelsius;
  final double? pressureBar;
  final int? tankIndex;
  final double? heartRate;
}

class GasMix {
  const GasMix({
    required this.index,
    required this.o2Percent,
    required this.hePercent,
  });
  final int index;
  final double o2Percent;
  final double hePercent;
}

class TankInfo {
  const TankInfo({
    required this.index,
    required this.gasMixIndex,
    this.volumeLiters,
    this.startPressureBar,
    this.endPressureBar,
  });
  final int index;
  final int gasMixIndex;
  final double? volumeLiters;
  final double? startPressureBar;
  final double? endPressureBar;
}

class DiveEvent {
  const DiveEvent({required this.timeSeconds, required this.type, this.data});
  final int timeSeconds;
  final String type;
  final Map<String, String>? data;
}

class ParsedDive {
  const ParsedDive({
    required this.fingerprint,
    required this.dateTimeEpoch,
    required this.maxDepthMeters,
    required this.avgDepthMeters,
    required this.durationSeconds,
    this.minTemperatureCelsius,
    this.maxTemperatureCelsius,
    required this.samples,
    required this.tanks,
    required this.gasMixes,
    required this.events,
    this.diveMode,
  });
  final String fingerprint;
  final int dateTimeEpoch;
  final double maxDepthMeters;
  final double avgDepthMeters;
  final int durationSeconds;
  final double? minTemperatureCelsius;
  final double? maxTemperatureCelsius;
  final List<ProfileSample> samples;
  final List<TankInfo> tanks;
  final List<GasMix> gasMixes;
  final List<DiveEvent> events;
  final String? diveMode;
}

class DownloadProgress {
  const DownloadProgress({
    required this.current,
    required this.total,
    required this.status,
  });
  final int current;
  final int total;
  final String status;
}

class DiveComputerError {
  const DiveComputerError({required this.code, required this.message});
  final String code;
  final String message;
}

// === Host API (Dart -> Native) ===

@HostApi()
abstract class DiveComputerHostApi {
  @async
  List<DeviceDescriptor> getDeviceDescriptors();

  @async
  void startDiscovery(TransportType transport);

  void stopDiscovery();

  @async
  void startDownload(DiscoveredDevice device);

  void cancelDownload();

  String getLibdivecomputerVersion();
}

// === Flutter API (Native -> Dart) ===

@FlutterApi()
abstract class DiveComputerFlutterApi {
  void onDeviceDiscovered(DiscoveredDevice device);
  void onDiscoveryComplete();
  void onDownloadProgress(DownloadProgress progress);
  void onDiveDownloaded(ParsedDive dive);
  void onDownloadComplete(int totalDives);
  void onError(DiveComputerError error);
}
