import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

/// Reads a diver's portrait for the PDF front matter.
typedef DiverPhotoLoader = Future<Uint8List?> Function(String? photoPath);

/// Best-effort read of the portrait at [photoPath].
///
/// Returns null for an absent path or an unreadable file rather than
/// throwing: a logbook export must not fail because a portrait was moved or
/// deleted, and the front matter falls back to its placeholder frame.
Future<Uint8List?> loadDiverPhotoFromDisk(String? photoPath) async {
  if (photoPath == null || photoPath.isEmpty) return null;
  try {
    final file = File(photoPath);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}

/// The portrait of [diver] for the PDF front matter: their profile photo
/// bytes ([Diver.photo], what the app's avatars show), or else the file at
/// their legacy [Diver.photoPath] read through [loadFromPath].
///
/// The bytes supersede the path, and a diver given a photo in the app may
/// have no path at all, so reading only the path printed the placeholder
/// frame for them (#4458).
Future<Uint8List?> diverPortrait(
  Diver? diver,
  DiverPhotoLoader loadFromPath,
) async => diver?.photo ?? await loadFromPath(diver?.photoPath);

/// The loader every PDF export entry point reads the portrait through.
///
/// A provider rather than a bare function call for two reasons. It keeps the
/// three entry points (settings export, dive-list bulk export, single-dive
/// export) on one implementation, which is what they diverged on: the bulk
/// and single-dive routes passed `diver` but no `diverPhoto`, so the diver
/// page silently fell back to its placeholder on every path except settings.
/// It also gives widget tests a seam, which they need: a real `dart:io` await
/// never completes inside `testWidgets`' FakeAsync zone.
final diverPhotoLoaderProvider = Provider<DiverPhotoLoader>(
  (ref) => loadDiverPhotoFromDisk,
);
