import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A dive's runtime and bottom time in UDDF (issue #4181).
///
/// UDDF's `<diveduration>` is the total dive time, so it carries the runtime.
/// UDDF has no element for a bottom time; both Submersion writers add a
/// `<bottomtime>` beside it, which other apps ignore.
abstract final class UddfDiveDurations {
  /// Writes [dive]'s durations inside its `<informationafterdive>`.
  ///
  /// The duration is the runtime the app shows, so a dive whose runtime is
  /// only known from its entry and exit or its samples still says how long it
  /// took. A dive with only a bottom time writes no duration: a bottom time
  /// is not a runtime (issue #3304).
  static void write(XmlBuilder builder, Dive dive) {
    if (dive.measuredRuntime case final runtime?) {
      builder.element('diveduration', nest: runtime.inSeconds.toString());
    }
    if (dive.bottomTime case final bottomTime?) {
      builder.element('bottomtime', nest: bottomTime.inSeconds.toString());
    }
  }

  /// Reads the durations [write] wrote from [afterDive], the dive's
  /// `<informationafterdive>`.
  ///
  /// Submersion's full backups from before the fix put the runtime in a
  /// `<runtime>` element and the bottom time in `<diveduration>`, so a file
  /// with a `<runtime>` reads its runtime from there. In such a file from
  /// Submersion, a `<diveduration>` that differs is that old bottom time; an
  /// equal one says nothing the runtime does not, and the profile derives the
  /// bottom time as it does for any other file.
  static ({Duration? runtime, Duration? bottomTime}) read(
    XmlElement afterDive,
  ) {
    Duration? seconds(String name) {
      final value = UddfImportParsers.parseUddfInt(
        UddfImportParsers.getElementText(afterDive, name),
      );
      return value == null ? null : Duration(seconds: value);
    }

    final duration = seconds('diveduration');
    final legacyRuntime = seconds('runtime');
    final legacyBottomTime =
        legacyRuntime != null &&
            duration != null &&
            duration != legacyRuntime &&
            UddfImportParsers.writtenBySubmersion(afterDive)
        ? duration
        : null;

    return (
      runtime: legacyRuntime ?? duration,
      bottomTime: seconds('bottomtime') ?? legacyBottomTime,
    );
  }
}
