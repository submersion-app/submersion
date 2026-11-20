// Ships ONNX Runtime, the marine life engine on Android, Windows and Linux,
// as code assets: downloads the pinned official package for the target
// (lib/src/ort/ort_release.dart), checks it against its SHA-256, takes the
// libraries out of it and checks each of those too. Apple platforms (Core
// ML) and the web get nothing. Modelled on package:sqlite3's hook.
import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';
import 'package:submersion_vision/src/ort/ort_release.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;
    final os = code.targetOS.name, arch = code.targetArchitecture.name;
    output.dependencies.add(
      input.packageRoot.resolve('lib/src/ort/ort_release.dart'),
    );
    final archive = ortArchiveFor(os, arch);
    if (archive == null) return;

    // Shared outputs survive between builds, so each package downloads once.
    final shared = Directory.fromUri(
      input.outputDirectoryShared.resolve('onnxruntime/'),
    )..createSync(recursive: true);
    for (final (library, file) in await ensureLibraries(
      archive,
      shared,
      '$os-$arch',
    )) {
      output.assets.code.add(
        CodeAsset(
          package: input.packageName,
          name: library.assetName,
          linkMode: DynamicLoadingBundled(),
          file: file.uri,
        ),
      );
    }
  });
}

/// Downloads [url] to [to].
typedef Fetch = Future<void> Function(String url, File to);

/// [archive]'s libraries in [shared]/[target] (one folder per target, since
/// Android's ABIs share a library name), each checked against its pin. A
/// library already there and matching is used as it is; the archive is
/// downloaded, checked and read only when one is missing or changed.
Future<List<(OrtLibrary, File)>> ensureLibraries(
  OrtArchive archive,
  Directory shared,
  String target, {
  Fetch fetch = fetchUrl,
}) async {
  final dir = Directory.fromUri(shared.uri.resolve('$target/'))
    ..createSync(recursive: true);
  final files = [
    for (final library in archive.libraries)
      (library, File.fromUri(dir.uri.resolve(library.entry.split('/').last))),
  ];
  final stale = [
    for (final (library, file) in files)
      if (!await _matches(file, library.sha256)) (library, file),
  ];
  if (stale.isEmpty) return files;

  final download = File.fromUri(shared.uri.resolve(archive.fileName));
  if (!await _matches(download, archive.sha256)) {
    // Fetched and checked in this process's own file, and moved into the
    // shared place only when it matches: another build at once (Android's
    // ABIs) may be reading an archive it has already checked there.
    final fetched = File('${download.path}.$pid.fetched');
    try {
      await fetch(archive.url, fetched);
      if (!await _matches(fetched, archive.sha256)) {
        throw BuildError(
          message:
              '${archive.url} does not match its pinned SHA-256 '
              '(${archive.sha256})',
        );
      }
      try {
        fetched.renameSync(download.path);
      } on FileSystemException {
        // Windows refuses to replace a file another build has open; that
        // build checked its copy first, so it is used as it is.
        if (!await _matches(download, archive.sha256)) rethrow;
      }
    } finally {
      if (fetched.existsSync()) fetched.deleteSync();
    }
  }
  for (final (library, file) in stale) {
    await _extract(download, library.entry, file);
    if (!await _matches(file, library.sha256)) {
      file.deleteSync();
      throw BuildError(
        message:
            '${library.entry} in ${archive.fileName} does not match its '
            'pinned SHA-256 (${library.sha256})',
      );
    }
  }
  return files;
}

Future<bool> _matches(File file, String sha256Hex) async =>
    file.existsSync() &&
    (await file.openRead().transform(sha256).first).toString() == sha256Hex;

/// Where [to] is written before it is complete: named for this process, so
/// two builds at once (Android's ABIs share one archive) never write,
/// rename or delete each other's file.
File partFile(File to) => File('${to.path}.$pid.part');

/// Downloads [url] to [to], through a temporary file so an interrupted
/// download never looks finished. A connection that stalls (nothing for
/// [idle]) fails the build as an infrastructure error, to be retried,
/// rather than hanging it.
Future<void> fetchUrl(
  String url,
  File to, {
  Duration idle = const Duration(minutes: 2),
}) async {
  final client = HttpClient()..connectionTimeout = idle;
  final tmp = partFile(to);
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close().timeout(idle);
    if (response.statusCode != HttpStatus.ok) {
      throw InfraError(
        message: 'downloading $url failed with HTTP ${response.statusCode}',
      );
    }
    // Chunk by chunk rather than addStream, so a stall leaves the file sink
    // healthy and closing it does not hide the timeout.
    final sink = tmp.openWrite();
    try {
      await for (final chunk in response.timeout(idle)) {
        sink.add(chunk);
      }
    } finally {
      await sink.close();
    }
    tmp.renameSync(to.path);
  } on TimeoutException {
    throw InfraError(message: 'downloading $url stalled for $idle');
  } finally {
    client.close(force: true);
    if (tmp.existsSync()) tmp.deleteSync();
  }
}

/// Writes the zip [archive]'s [entry] to [to].
Future<void> _extract(File archive, String entry, File to) async {
  final input = InputFileStream(archive.path);
  try {
    final zip = ZipDecoder().decodeStream(input);
    final found = zip.findFile(entry);
    if (found == null) {
      throw BuildError(message: '${archive.path} holds no $entry');
    }
    final tmp = partFile(to);
    await tmp.writeAsBytes(found.readBytes()!, flush: true);
    tmp.renameSync(to.path);
  } finally {
    await input.close();
  }
}
