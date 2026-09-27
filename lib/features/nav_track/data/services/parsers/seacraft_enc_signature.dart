/// The UTF-8 byte order mark as decoded text (U+FEFF), written as an
/// escape because the literal character is invisible in source. Mirrors
/// FormatDetector's own constant: some exports of this CSV carry one.
const _bom = '\u{FEFF}';

/// Header names (trimmed, lower-cased) that must all be present for a CSV
/// to be recognised as a Seacraft ENC / ENC3 / ENC3-PRO navigation console
/// log.
const _kRequiredHeaders = {'date', 'time', 'pos3dx', 'pos3dy', 'pos3dz'};

/// True when [headers] look like a Seacraft ENC navigation console log.
///
/// The recording carries no coordinates of its own -- Pos3Dx/Pos3Dy/Pos3Dz
/// are metres relative to the log's own start -- so this signature is the
/// only way to tell the file apart from an ordinary dive-log or GPS-track
/// CSV before parsing it. All five required headers must be present;
/// extra or reordered columns are fine, since a later firmware may append
/// channels this app does not yet read.
bool looksLikeSeacraftEnc(List<String> headers) {
  if (headers.isEmpty) return false;
  final normalized = <String>{};
  for (var i = 0; i < headers.length; i++) {
    var h = headers[i].trim().toLowerCase();
    if (i == 0 && h.startsWith(_bom)) {
      h = h.substring(_bom.length);
    }
    normalized.add(h);
  }
  return _kRequiredHeaders.every(normalized.contains);
}
