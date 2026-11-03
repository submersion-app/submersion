/// The code point of zero in each digit set a keyboard here may type:
/// Arabic-Indic, Eastern Arabic-Indic (Persian, Urdu) and full-width (a
/// CJK input method). ASCII digits need no mapping.
const _digitZeros = [0x0660, 0x06F0, 0xFF10];

/// [digits] with every digit set a keyboard here may type folded to ASCII.
String asciiDigits(String digits) => String.fromCharCodes(
  digits.runes.map((r) {
    for (final zero in _digitZeros) {
      if (r >= zero && r <= zero + 9) return 0x30 + r - zero;
    }
    return r;
  }),
);
