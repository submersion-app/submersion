import Foundation

/// Stands in for the one Flutter type VisionPipeline.swift uses, so the
/// pipeline compiles into this command-line tool unchanged.
final class FlutterStandardTypedData {
  let data: Data

  init(bytes: Data) { data = bytes }

  init(float32: Data) { data = float32 }
}
