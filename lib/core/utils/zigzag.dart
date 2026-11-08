/// Zigzag integer decoding (0, 1, 2, 3, ... back to 0, -1, 1, -2, ...) in
/// arithmetic that means the same on the VM and compiled to JavaScript.
///
/// The usual bit trick does not: in JavaScript `>>`, `^` and `&` work on the
/// low 32 bits of a double and return them unsigned, so `(z >> 1) ^ -(z & 1)`
/// decodes -6 as 4294967290 there (#4194, #4245).
library;

/// The signed value [zigzag] encodes. [zigzag] must not be negative.
int zigzagDecode(int zigzag) =>
    zigzag.isEven ? zigzag ~/ 2 : -(zigzag ~/ 2) - 1;
