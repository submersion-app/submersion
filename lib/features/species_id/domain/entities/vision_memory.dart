import 'package:equatable/equatable.dart';

/// The app's memory at one moment, as the system accounts for it, for the
/// debug log's readout during a phone memory test. Sizes are in bytes. A
/// field the platform does not report is null: macOS has no per-app limit,
/// and older iOS versions report fewer ledgers.
class VisionMemory extends Equatable {
  const VisionMemory({
    required this.footprintBytes,
    this.footprintPeakBytes,
    this.availableBytes,
    this.neuralCountedBytes,
    this.neuralNotCountedBytes,
    this.neuralNotCountedPeakBytes,
    this.lowMemory,
  });

  /// The physical footprint: what iOS compares with the app's limit.
  final int footprintBytes;

  /// The highest footprint since the app started.
  final int? footprintPeakBytes;

  /// How much more the app may use before iOS stops it.
  final int? availableBytes;

  /// Neural Engine memory that counts toward the footprint.
  final int? neuralCountedBytes;

  /// Neural Engine memory kept out of the footprint, and its peak.
  final int? neuralNotCountedBytes;
  final int? neuralNotCountedPeakBytes;

  /// Whether the system reports itself low on memory (Android's
  /// `ActivityManager.MemoryInfo.lowMemory`); null where it says nothing.
  final bool? lowMemory;

  VisionMemory copyWith({
    int? footprintBytes,
    int? footprintPeakBytes,
    int? availableBytes,
    int? neuralCountedBytes,
    int? neuralNotCountedBytes,
    int? neuralNotCountedPeakBytes,
    bool? lowMemory,
  }) => VisionMemory(
    footprintBytes: footprintBytes ?? this.footprintBytes,
    footprintPeakBytes: footprintPeakBytes ?? this.footprintPeakBytes,
    availableBytes: availableBytes ?? this.availableBytes,
    neuralCountedBytes: neuralCountedBytes ?? this.neuralCountedBytes,
    neuralNotCountedBytes: neuralNotCountedBytes ?? this.neuralNotCountedBytes,
    neuralNotCountedPeakBytes:
        neuralNotCountedPeakBytes ?? this.neuralNotCountedPeakBytes,
    lowMemory: lowMemory ?? this.lowMemory,
  );

  @override
  List<Object?> get props => [
    footprintBytes,
    footprintPeakBytes,
    availableBytes,
    neuralCountedBytes,
    neuralNotCountedBytes,
    neuralNotCountedPeakBytes,
    lowMemory,
  ];
}
