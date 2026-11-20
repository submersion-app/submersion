// Ships ONNX Runtime, the marine life engine on Android, Windows and Linux,
// as code assets: downloads the pinned official package for the target
// (lib/src/ort/ort_release.dart), checks it against its SHA-256, takes the
// libraries out of it and checks each of those too. Apple platforms (Core
// ML) and the web get nothing. Modelled on package:sqlite3's hook.
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
    final download = File.fromUri(shared.uri.resolve(archive.fileName));
    if (!await _matches(download, archive.sha256)) {
      await _fetch(archive.url, download);
      if (!await _matches(download, archive.sha256)) {
        download.deleteSync();
        throw BuildError(
          message:
              '${archive.url} does not match its pinned SHA-256 '
              '(${archive.sha256})',
        );
      }
    }

    // One folder per target: Android's ABIs share a library name.
    final dir = Directory.fromUri(shared.uri.resolve('$os-$arch/'))
      ..createSync(recursive: true);
    for (final library in archive.libraries) {
      final file = File.fromUri(dir.uri.resolve(library.entry.split('/').last));
      if (!await _matches(file, library.sha256)) {
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

Future<bool> _matches(File file, String sha256Hex) async =>
    file.existsSync() &&
    (await file.openRead().transform(sha256).first).toString() == sha256Hex;

/// Downloads [url] to [to], through a temporary file so an interrupted
/// download never looks finished.
Future<void> _fetch(String url, File to) async {
  final client = HttpClient();
  final tmp = File('${to.path}.part');
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw InfraError(
        message: 'downloading $url failed with HTTP ${response.statusCode}',
      );
    }
    await response.pipe(tmp.openWrite());
    tmp.renameSync(to.path);
  } finally {
    client.close();
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
    final tmp = File('${to.path}.part');
    await tmp.writeAsBytes(found.readBytes()!, flush: true);
    tmp.renameSync(to.path);
  } finally {
    await input.close();
  }
}
