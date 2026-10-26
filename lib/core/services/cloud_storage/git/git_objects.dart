import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';

/// Tree entry mode of a regular, non-executable file (octal 100644).
const int kGitModeFile = 0x81A4;

/// Tree entry mode of a subdirectory (octal 40000).
const int kGitModeTree = 0x4000;

/// One name in a Git tree.
final class GitTreeEntry {
  const GitTreeEntry({
    required this.name,
    required this.mode,
    required this.id,
  });

  final String name;
  final int mode;
  final GitObjectId id;

  bool get isTree => mode == kGitModeTree;

  @override
  String toString() => 'GitTreeEntry($name, ${mode.toRadixString(8)}, $id)';
}

/// Encodes a tree body. Entries are sorted the way Git sorts them: by the
/// UTF-8 bytes of the name, with a subtree's name compared as if it ended in
/// `/`. Any other order produces a tree Git considers malformed.
Uint8List encodeTree(Iterable<GitTreeEntry> entries) {
  final sorted = entries.toList()..sort(_compareTreeEntries);
  final out = BytesBuilder(copy: false);
  for (final e in sorted) {
    out.add(utf8.encode('${e.mode.toRadixString(8)} ${e.name}'));
    out.addByte(0);
    out.add(e.id.bytes);
  }
  return out.takeBytes();
}

int _compareTreeEntries(GitTreeEntry a, GitTreeEntry b) {
  final ka = utf8.encode(a.isTree ? '${a.name}/' : a.name);
  final kb = utf8.encode(b.isTree ? '${b.name}/' : b.name);
  final n = ka.length < kb.length ? ka.length : kb.length;
  for (var i = 0; i < n; i++) {
    if (ka[i] != kb[i]) return ka[i] - kb[i];
  }
  return ka.length - kb.length;
}

/// Decodes a tree body. Throws [FormatException] on malformed input.
List<GitTreeEntry> decodeTree(Uint8List body) {
  final entries = <GitTreeEntry>[];
  var i = 0;
  while (i < body.length) {
    final space = body.indexOf(0x20, i);
    if (space < 0) throw const FormatException('Tree entry has no mode');
    final mode = int.tryParse(ascii.decode(body.sublist(i, space)), radix: 8);
    if (mode == null) {
      throw const FormatException('Tree entry mode is not octal');
    }
    final nul = body.indexOf(0, space + 1);
    if (nul < 0 || nul + 21 > body.length) {
      throw const FormatException('Tree entry is truncated');
    }
    final name = utf8.decode(body.sublist(space + 1, nul));
    final id = GitObjectId(body.sublist(nul + 1, nul + 21));
    entries.add(GitTreeEntry(name: name, mode: mode, id: id));
    i = nul + 21;
  }
  return entries;
}

/// A commit whose author and committer are the same person and time, in UTC.
/// A decoded one written by another tool may differ: [committedAt] keeps the
/// committer's time.
final class GitCommit {
  const GitCommit({
    required this.tree,
    required this.parents,
    required this.authorName,
    required this.authorEmail,
    required this.when,
    required this.message,
    this.committedAt,
  });

  final GitObjectId tree;
  final List<GitObjectId> parents;
  final String authorName;
  final String authorEmail;
  final DateTime when;

  /// The message without its trailing newline.
  final String message;

  /// The committer's time, when decoded from a commit that has one.
  final DateTime? committedAt;

  /// When the commit was made on the branch. A rebase or cherry-pick keeps
  /// the original author time, so this prefers the committer's.
  DateTime get landedAt => committedAt ?? when;

  Uint8List encode() {
    final seconds = when.toUtc().millisecondsSinceEpoch ~/ 1000;
    final person = '${_identName(authorName)} <$authorEmail> $seconds +0000';
    final buffer = StringBuffer()..write('tree ${tree.hex}\n');
    for (final parent in parents) {
      buffer.write('parent ${parent.hex}\n');
    }
    buffer
      ..write('author $person\n')
      ..write('committer $person\n')
      ..write('\n')
      ..write('$message\n');
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static final RegExp _person = RegExp(r'^(.*) <([^>]*)> (\d+) [+-]\d{4}$');

  /// [name] as Git accepts it in an author line: angle brackets delimit the
  /// email, and a line break or other control character would end the
  /// header, so hosts that check pushed objects refuse either.
  static String _identName(String name) {
    final cleaned = name
        .replaceAll(RegExp('[<>]'), '')
        .replaceAll(RegExp(r'[\x00-\x1f\x7f\s]+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'Submersion' : cleaned;
  }

  /// Decodes a commit body. Throws [FormatException] when the tree or author
  /// header is missing or malformed. Extra headers (gpgsig, encoding) are
  /// ignored.
  static GitCommit decode(Uint8List body) {
    final text = utf8.decode(body, allowMalformed: true);
    final split = text.indexOf('\n\n');
    final headerText = split < 0 ? text : text.substring(0, split);
    var message = split < 0 ? '' : text.substring(split + 2);
    if (message.endsWith('\n')) {
      message = message.substring(0, message.length - 1);
    }
    GitObjectId? tree;
    final parents = <GitObjectId>[];
    RegExpMatch? author;
    RegExpMatch? committer;
    for (final line in headerText.split('\n')) {
      if (line.startsWith('tree ')) {
        tree = GitObjectId.fromHex(line.substring(5));
      } else if (line.startsWith('parent ')) {
        parents.add(GitObjectId.fromHex(line.substring(7)));
      } else if (line.startsWith('author ')) {
        author = _person.firstMatch(line.substring(7));
      } else if (line.startsWith('committer ')) {
        committer = _person.firstMatch(line.substring(10));
      }
    }
    if (tree == null) throw const FormatException('Commit has no tree');
    if (author == null) throw const FormatException('Commit has no author');
    return GitCommit(
      tree: tree,
      parents: List.unmodifiable(parents),
      authorName: author.group(1)!,
      authorEmail: author.group(2)!,
      when: DateTime.fromMillisecondsSinceEpoch(
        int.parse(author.group(3)!) * 1000,
        isUtc: true,
      ),
      message: message,
      committedAt: committer == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              int.parse(committer.group(3)!) * 1000,
              isUtc: true,
            ),
    );
  }
}
