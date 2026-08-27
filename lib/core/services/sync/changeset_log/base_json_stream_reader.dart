import 'dart:convert';
import 'dart:typed_data';

/// Streaming, bounded-memory reader for a serialized sync base document.
///
/// The base is one JSON object: a handful of scalar header members plus two
/// "section" members (`data` and `deletions`) whose values are objects mapping
/// a table name to an array of row objects. This reader walks the byte stream
/// once and reports:
///  - [parse]'s `onScalar` for each top-level scalar member (key + raw value
///    bytes), and
///  - `onRow` for each element of each section's table arrays.
///
/// It never holds more than one row (or one scalar value) in memory, so a
/// multi-hundred-MB base imports in bounded memory. It does NOT parse JSON
/// values itself: it finds byte boundaries (respecting string/escape state and
/// brace/bracket nesting) and hands raw bytes to the caller, which decodes the
/// few rows it needs via `jsonDecode`.
///
/// The instance holds per-parse mutable state; do not run two [parse] calls on
/// one instance concurrently (the import drives passes sequentially).
class BaseJsonStreamReader {
  static const int _quote = 0x22; // "
  static const int _backslash = 0x5c; // \
  static const int _lbrace = 0x7b; // {
  static const int _rbrace = 0x7d; // }
  static const int _lbracket = 0x5b; // [
  static const int _rbracket = 0x5d; // ]
  static const int _colon = 0x3a; // :
  static const int _comma = 0x2c; // ,

  static bool _isWs(int c) => c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d;

  // --- per-parse state ---
  _S _state = _S.awaitTopOpen;
  String? _lastKey;
  String? _section;
  String? _table;

  final BytesBuilder _key = BytesBuilder(copy: false);
  bool _keyEscaped = false;

  final BytesBuilder _cap = BytesBuilder(copy: false);
  int _capDepth = 0;
  bool _capInString = false;
  bool _capEscaped = false;
  bool _capStarted = false;
  _Cap _capKind = _Cap.skip;

  bool Function(String section, String table) _want = (_, _) => true;

  void _reset() {
    _state = _S.awaitTopOpen;
    _lastKey = null;
    _section = null;
    _table = null;
    _key.clear();
    _keyEscaped = false;
    _cap.clear();
    _capDepth = 0;
    _capInString = false;
    _capEscaped = false;
    _capStarted = false;
    _capKind = _Cap.skip;
  }

  Future<void> parse(
    Stream<List<int>> bytes, {
    Future<void> Function(String key, Uint8List rawValue)? onScalar,
    bool Function(String section, String table)? wantRows,
    Future<void> Function(String section, String table, Uint8List rowBytes)?
    onRow,
  }) async {
    _reset();
    _want = wantRows ?? (_, _) => true;

    await for (final chunk in bytes) {
      for (final c in chunk) {
        var consumed = false;
        while (!consumed) {
          final r = _consume(c);
          consumed = r.consumed;
          final emit = r.emit;
          if (emit != null) {
            if (emit.kind == _Cap.scalar) {
              if (onScalar != null) await onScalar(emit.key!, emit.bytes);
            } else {
              if (onRow != null) {
                await onRow(emit.section!, emit.table!, emit.bytes);
              }
            }
          }
        }
      }
    }

    // Completeness guard: a well-formed base ends with the top-level object
    // closed (state == done). Any other end state means the stream was empty
    // or truncated. Throw so the caller fails the base closed (the reader's
    // per-peer catch leaves the cursor unadvanced; a mid-apply throw rolls back
    // the transaction) rather than silently applying a partial base. This is
    // defense-in-depth behind BasePartFileSink's checksums, which already
    // reject corruption when the manifest carries checksums but are absent on
    // legacy manifests.
    if (_state != _S.done) {
      throw const FormatException(
        'Base JSON ended before the top-level object closed '
        '(empty or truncated document)',
      );
    }
  }

  _Step _consume(int c) {
    switch (_state) {
      case _S.awaitTopOpen:
        if (_isWs(c)) return const _Step(true);
        if (c == _lbrace) _state = _S.topKeyOrClose;
        return const _Step(true);

      case _S.topKeyOrClose:
        if (_isWs(c) || c == _comma) return const _Step(true);
        if (c == _rbrace) {
          _state = _S.done;
          return const _Step(true);
        }
        if (c == _quote) {
          _key.clear();
          _keyEscaped = false;
          _state = _S.topKey;
        }
        return const _Step(true);

      case _S.topKey:
        return _readKey(c, then: _S.topColon);

      case _S.topColon:
        if (_isWs(c)) return const _Step(true);
        if (c == _colon) _state = _S.topValueStart;
        return const _Step(true);

      case _S.topValueStart:
        if (_isWs(c)) return const _Step(true);
        if (c == _lbrace) {
          _section = _lastKey;
          _state = _S.sectionKeyOrClose;
          return const _Step(true);
        }
        _beginCapture(_Cap.scalar);
        _state = _S.capture;
        return const _Step(false); // reprocess this char inside capture

      case _S.sectionKeyOrClose:
        if (_isWs(c) || c == _comma) return const _Step(true);
        if (c == _rbrace) {
          _section = null;
          _state = _S.topKeyOrClose;
          return const _Step(true);
        }
        if (c == _quote) {
          _key.clear();
          _keyEscaped = false;
          _state = _S.sectionKey;
        }
        return const _Step(true);

      case _S.sectionKey:
        return _readKey(c, then: _S.sectionColon, intoTable: true);

      case _S.sectionColon:
        if (_isWs(c)) return const _Step(true);
        if (c == _colon) _state = _S.sectionValueStart;
        return const _Step(true);

      case _S.sectionValueStart:
        if (_isWs(c)) return const _Step(true);
        if (c == _lbracket) {
          _state = _S.arrayElemOrClose;
          return const _Step(true);
        }
        // Unexpected non-array section value: skip it generically.
        _beginCapture(_Cap.skip);
        _state = _S.captureSection;
        return const _Step(false);

      case _S.arrayElemOrClose:
        if (_isWs(c) || c == _comma) return const _Step(true);
        if (c == _rbracket) {
          _table = null;
          _state = _S.sectionKeyOrClose;
          return const _Step(true);
        }
        _beginCapture(
          (_section != null && _table != null && _want(_section!, _table!))
              ? _Cap.row
              : _Cap.skip,
        );
        _state = _S.captureArray;
        return const _Step(false);

      case _S.arrayCommaOrClose:
        if (_isWs(c)) return const _Step(true);
        if (c == _comma) {
          _state = _S.arrayElemOrClose;
          return const _Step(true);
        }
        if (c == _rbracket) {
          _table = null;
          _state = _S.sectionKeyOrClose;
          return const _Step(true);
        }
        return const _Step(true);

      case _S.capture:
      case _S.captureArray:
      case _S.captureSection:
        return _captureByte(c);

      case _S.done:
        return const _Step(true);
    }
  }

  _Step _readKey(int c, {required _S then, bool intoTable = false}) {
    if (_keyEscaped) {
      _key.addByte(c);
      _keyEscaped = false;
      return const _Step(true);
    }
    if (c == _backslash) {
      _key.addByte(c);
      _keyEscaped = true;
      return const _Step(true);
    }
    if (c == _quote) {
      final name = utf8.decode(_key.takeBytes());
      if (intoTable) {
        _table = name;
      } else {
        _lastKey = name;
      }
      _state = then;
      return const _Step(true);
    }
    _key.addByte(c);
    return const _Step(true);
  }

  void _beginCapture(_Cap kind) {
    _cap.clear();
    _capDepth = 0;
    _capInString = false;
    _capEscaped = false;
    _capStarted = false;
    _capKind = kind;
  }

  _Step _captureByte(int c) {
    if (_capInString) {
      _cap.addByte(c);
      if (_capEscaped) {
        _capEscaped = false;
      } else if (c == _backslash) {
        _capEscaped = true;
      } else if (c == _quote) {
        _capInString = false;
        if (_capDepth == 0) return _finishCapture(consume: true);
      }
      return const _Step(true);
    }
    if (c == _quote) {
      _capStarted = true;
      _capInString = true;
      _cap.addByte(c);
      return const _Step(true);
    }
    if (c == _lbrace || c == _lbracket) {
      _capStarted = true;
      _capDepth++;
      _cap.addByte(c);
      return const _Step(true);
    }
    if (c == _rbrace || c == _rbracket) {
      if (_capDepth == 0) {
        // This closing delimiter belongs to the parent: a primitive value
        // ended just before it. Finish and reprocess the delimiter.
        return _finishCapture(consume: false);
      }
      _capDepth--;
      _cap.addByte(c);
      if (_capDepth == 0) return _finishCapture(consume: true);
      return const _Step(true);
    }
    if (c == _comma && _capDepth == 0) {
      // Primitive value ended at a separator; consume the comma.
      return _finishCapture(consume: true);
    }
    if (_isWs(c)) {
      if (_capDepth == 0 && _capStarted) {
        // Whitespace after a primitive ends it; the following delimiter is
        // handled by the parent state.
        return _finishCapture(consume: true);
      }
      return const _Step(true); // leading/interior structural whitespace
    }
    _capStarted = true;
    _cap.addByte(c);
    return const _Step(true);
  }

  _Step _finishCapture({required bool consume}) {
    final kind = _capKind;
    final bytes = (kind == _Cap.skip) ? null : _cap.takeBytes();
    if (kind == _Cap.skip) _cap.clear();

    // Transition to the parent state.
    if (_state == _S.capture) {
      _state = _S.topKeyOrClose;
    } else if (_state == _S.captureArray) {
      _state = _S.arrayCommaOrClose;
    } else {
      _state = _S.sectionKeyOrClose;
    }

    _Emit? emit;
    if (bytes != null) {
      if (kind == _Cap.scalar) {
        emit = _Emit.scalar(_lastKey ?? '', bytes);
      } else if (kind == _Cap.row && _section != null && _table != null) {
        emit = _Emit.row(_section!, _table!, bytes);
      }
    }
    return _Step(consume, emit: emit);
  }
}

enum _Cap { scalar, row, skip }

enum _S {
  awaitTopOpen,
  topKeyOrClose,
  topKey,
  topColon,
  topValueStart,
  sectionKeyOrClose,
  sectionKey,
  sectionColon,
  sectionValueStart,
  arrayElemOrClose,
  arrayCommaOrClose,
  capture,
  captureArray,
  captureSection,
  done,
}

class _Step {
  const _Step(this.consumed, {this.emit});
  final bool consumed;
  final _Emit? emit;
}

class _Emit {
  _Emit.scalar(this.key, this.bytes)
    : section = null,
      table = null,
      kind = _Cap.scalar;
  _Emit.row(this.section, this.table, this.bytes) : key = null, kind = _Cap.row;
  final _Cap kind;
  final String? key;
  final String? section;
  final String? table;
  final Uint8List bytes;
}
