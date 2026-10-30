import 'dart:math';
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';

GitException _corrupt(String what) => GitException(
  'The server sent a corrupt pack ($what).',
  code: GitErrorCode.unexpected,
);

enum _Stage { sourceSize, targetSize, command, copyArgs, insert }

/// Applies a Git delta that arrives in pieces, for a base or result too
/// large to hold: copies are read from [_base] a piece at a time, and the
/// result goes to a writer made by [_create] once the delta's header gives
/// its size. The same checks as `applyGitDelta`, each a [GitException].
final class GitDeltaStream {
  GitDeltaStream(this._base, this._create);

  /// The most a copy reads from the base at once.
  static const int _copyPiece = 1024 * 1024;

  final GitObjectReader _base;
  final GitObjectWriter Function(GitObjectType type, int size) _create;
  GitObjectWriter? _out;

  _Stage _stage = _Stage.sourceSize;
  int _varint = 0;
  int _shift = 0;
  int _targetSize = 0;
  int _written = 0;

  // The copy command being read: its byte, the next argument bit to look
  // at, and the offset and size gathered so far.
  int _cmd = 0;
  int _arg = 0;
  int _copyOffset = 0;
  int _copySize = 0;
  int _insertLeft = 0;

  void add(Uint8List chunk) {
    var i = 0;
    while (i < chunk.length) {
      switch (_stage) {
        case _Stage.sourceSize:
        case _Stage.targetSize:
          if (_readVarint(chunk[i++])) _endVarint();
        case _Stage.command:
          final cmd = chunk[i++];
          if (cmd & 0x80 != 0) {
            _cmd = cmd;
            _arg = 0;
            _copyOffset = 0;
            _copySize = 0;
            _stage = _Stage.copyArgs;
            _copyIfReady();
          } else if (cmd != 0) {
            if (_written + cmd > _targetSize) {
              throw _corrupt('insert out of range');
            }
            _insertLeft = cmd;
            _stage = _Stage.insert;
          } else {
            throw _corrupt('reserved delta opcode');
          }
        case _Stage.copyArgs:
          final b = chunk[i++];
          if (_arg < 4) {
            _copyOffset |= b << (8 * _arg);
          } else {
            _copySize |= b << (8 * (_arg - 4));
          }
          _arg++;
          _copyIfReady();
        case _Stage.insert:
          final n = min(_insertLeft, chunk.length - i);
          _write(Uint8List.sublistView(chunk, i, i + n));
          i += n;
          _insertLeft -= n;
          if (_insertLeft == 0) _stage = _Stage.command;
      }
    }
  }

  /// Adds one byte of a size varint; true when it was the last.
  bool _readVarint(int b) {
    _varint |= (b & 0x7f) << _shift;
    _shift += 7;
    return b & 0x80 == 0;
  }

  void _endVarint() {
    final value = _varint;
    _varint = 0;
    _shift = 0;
    if (_stage == _Stage.sourceSize) {
      if (value != _base.length) throw _corrupt('delta base size mismatch');
      _stage = _Stage.targetSize;
    } else {
      _targetSize = value;
      _out = _create(_base.type, value);
      _stage = _Stage.command;
    }
  }

  /// Skips argument bits the command does not set; runs the copy once none
  /// are left.
  void _copyIfReady() {
    while (_arg < 7 && _cmd & _argBit(_arg) == 0) {
      _arg++;
    }
    if (_arg < 7) return;
    final size = _copySize == 0 ? 0x10000 : _copySize;
    if (_copyOffset + size > _base.length || _written + size > _targetSize) {
      throw _corrupt('copy out of range');
    }
    var done = 0;
    while (done < size) {
      final piece = _base.readSync(
        _copyOffset + done,
        min(_copyPiece, size - done),
      );
      if (piece.isEmpty) throw _corrupt('copy out of range');
      _write(piece);
      done += piece.length;
    }
    _stage = _Stage.command;
  }

  /// Bits 0 to 3 of a copy command flag offset bytes, 4 to 6 size bytes.
  static int _argBit(int arg) => arg < 4 ? 1 << arg : 0x10 << (arg - 4);

  void _write(Uint8List bytes) {
    _written += bytes.length;
    _out!.add(bytes);
  }

  /// Stores the result and returns its id.
  Future<GitObjectId> close() async {
    final out = _out;
    if (out == null || _stage != _Stage.command) {
      throw _corrupt('truncated delta');
    }
    if (_written != _targetSize) throw _corrupt('delta result size mismatch');
    return out.close();
  }

  /// Drops a result not yet closed.
  Future<void> abort() async => _out?.abort();
}
