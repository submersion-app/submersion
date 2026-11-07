import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/export/shared/export_text_spool.dart';

/// The spools a streamed export (issue #4249) parks its sections in until
/// the text ahead of them is written.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('export_spool_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  for (final (name, store) in [
    ('in memory', () => ExportSpoolStore.memory()),
    ('in files', () => ExportSpoolStore.inDirectory(dir)),
  ]) {
    group('spools $name', () {
      test('give back what was written, in order', () async {
        final spools = store();
        final spool = spools.create()
          ..write('<a>')
          ..write('Mañana Reef ü ')
          ..write('</a>');
        await spool.flush();
        final out = MemoryTextSink();

        await spool.copyTo(out);

        expect(out.toString(), '<a>Mañana Reef ü </a>');
        await spools.dispose();
      });

      test('start empty and stay so for empty writes', () async {
        final spools = store();
        final spool = spools.create();
        expect(spool.isEmpty, isTrue);
        spool.write('');
        expect(spool.isEmpty, isTrue);
        spool.write('x');
        expect(spool.isEmpty, isFalse);
        await spools.dispose();
      });

      test('keep apart from each other', () async {
        final spools = store();
        final first = spools.create()..write('one');
        final second = spools.create()..write('two');
        final out = MemoryTextSink();

        await second.copyTo(out);
        await first.copyTo(out);

        expect(out.toString(), 'twoone');
        await spools.dispose();
      });
    });
  }

  test('a file spool larger than one read comes back whole', () async {
    final spools = ExportSpoolStore.inDirectory(dir);
    final spool = spools.create();
    // Multi-byte characters across many reads, so a character split
    // between two reads would show.
    final piece = 'ü€😀' * 1000;
    for (var i = 0; i < 100; i++) {
      spool.write(piece);
    }
    final out = MemoryTextSink();

    await spool.copyTo(out);

    expect(out.toString(), piece * 100);
    await spools.dispose();
  });

  test('disposing a file store removes its files', () async {
    final spools = ExportSpoolStore.inDirectory(dir);
    spools.create().write('left over');
    await spools.create().flush();

    await spools.dispose();

    expect(dir.listSync(), isEmpty);
  });

  test('a file sink writes UTF-8 to its file', () async {
    final file = File(p.join(dir.path, 'out.xml'));
    final sink = FileTextSink(file)..write('<a>ü</a>');

    await sink.close();

    expect(file.readAsStringSync(), '<a>ü</a>');
  });

  test('an export work directory is new and empty', () async {
    final first = await createExportWorkDirectory();
    final second = await createExportWorkDirectory();
    addTearDown(() async {
      await first.delete(recursive: true);
      await second.delete(recursive: true);
    });

    expect(first.path, isNot(second.path));
    expect(first.listSync(), isEmpty);
  });
}
