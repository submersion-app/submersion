import 'package:submersion/features/universal_import/data/parsers/dl7/dl7_document.dart';

/// Scans DAN DL7 text into segments.
///
/// Tolerates CR, CRLF, and LF line endings (the 2006 spec mandates bare CR;
/// real exporters disagree), a UTF-8 BOM, single-line and multi-line ZAR
/// blocks, and unknown segments (ZXL demographics), which are skipped.
class Dl7Reader {
  const Dl7Reader();

  Dl7Document read(String content) {
    final warnings = <String>[];
    var fsh = const <String>[];
    var zrh = const <String>[];
    final zarLines = <String>[];
    final dives = <Dl7DiveRecord>[];

    List<String>? currentZdh;
    List<List<String>>? currentZdpRows;
    var inZdp = false;
    var inZar = false;

    void closeDive(List<String> zdtFields) {
      if (currentZdh == null) {
        warnings.add('ZDT segment without a preceding ZDH; ignored');
        return;
      }
      dives.add(
        Dl7DiveRecord(
          zdhFields: currentZdh!,
          zdpRows: currentZdpRows ?? const [],
          zdtFields: zdtFields,
        ),
      );
      currentZdh = null;
      currentZdpRows = null;
    }

    final stripped = content.startsWith('﻿') ? content.substring(1) : content;
    final lines = stripped.split(RegExp(r'\r\n|\r|\n'));

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (inZar) {
        if (line.trim() == '}') {
          inZar = false;
        } else {
          zarLines.add(line);
        }
        continue;
      }
      if (inZdp) {
        if (line.startsWith('ZDP}')) {
          inZdp = false;
        } else if (line.startsWith('|')) {
          // Drop the leading empty token so spec column N = index N-1.
          currentZdpRows?.add(line.split('|').sublist(1));
        }
        continue;
      }
      if (line.isEmpty) continue;

      if (line.startsWith('ZAR{')) {
        final rest = line.substring('ZAR{'.length);
        if (rest.endsWith('}')) {
          final inner = rest.substring(0, rest.length - 1);
          if (inner.isNotEmpty) zarLines.add(inner);
        } else {
          if (rest.isNotEmpty) zarLines.add(rest);
          inZar = true;
        }
      } else if (line.startsWith('ZDP{')) {
        if (currentZdh == null) {
          warnings.add('ZDP block without a preceding ZDH; ignored');
        } else {
          currentZdpRows ??= [];
          inZdp = true;
        }
      } else if (line.startsWith('FSH|')) {
        fsh = line.split('|');
      } else if (line.startsWith('ZRH|')) {
        zrh = line.split('|');
      } else if (line.startsWith('ZDH|')) {
        if (currentZdh != null) {
          warnings.add('ZDH without closing ZDT for the previous dive');
          closeDive(const []);
        }
        currentZdh = line.split('|');
        currentZdpRows = [];
      } else if (line.startsWith('ZDT|')) {
        closeDive(line.split('|'));
      }
      // Unknown segments (ZPD, ZPA, ZDD, ZSR, ...) are skipped by design.
    }

    if (currentZdh != null) {
      warnings.add("File ended before the last dive's ZDT segment");
      closeDive(const []);
    }

    return Dl7Document(
      fshFields: fsh,
      zrhFields: zrh,
      zarContent: zarLines.join('\n'),
      dives: dives,
      readerWarnings: warnings,
    );
  }
}
