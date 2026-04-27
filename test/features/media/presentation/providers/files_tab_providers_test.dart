import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';

ExtractedFile _ef(String path) => ExtractedFile(
  sourcePath: path,
  file: File(path),
  metadata: const MediaSourceMetadata(mimeType: 'image/jpeg'),
);

void main() {
  test('default state: no files, autoMatchByDate=true, not extracting', () {
    final container = ProviderContainer();
    final state = container.read(filesTabNotifierProvider);
    expect(state.files, isEmpty);
    expect(state.autoMatchByDate, isTrue);
    expect(state.isExtracting, isFalse);
    expect(state.extractedCount, 0);
    expect(state.totalToExtract, 0);
    expect(state.match, MatchedSelection.empty());
    container.dispose();
  });

  test('toggleAutoMatch flips the flag', () {
    final container = ProviderContainer();
    final notifier = container.read(filesTabNotifierProvider.notifier);
    notifier.toggleAutoMatch();
    expect(container.read(filesTabNotifierProvider).autoMatchByDate, isFalse);
    notifier.toggleAutoMatch();
    expect(container.read(filesTabNotifierProvider).autoMatchByDate, isTrue);
    container.dispose();
  });

  test('clear resets to initial state', () {
    final container = ProviderContainer();
    final notifier = container.read(filesTabNotifierProvider.notifier);
    notifier.setFiles([
      _ef('/a.jpg'),
    ], match: const MatchedSelection(matched: {}, unmatched: []));
    notifier.clear();
    final state = container.read(filesTabNotifierProvider);
    expect(state.files, isEmpty);
    expect(state.autoMatchByDate, isTrue); // reset to default
    container.dispose();
  });

  test('setFiles updates files and match', () {
    final container = ProviderContainer();
    final notifier = container.read(filesTabNotifierProvider.notifier);
    final files = [_ef('/a.jpg'), _ef('/b.jpg')];
    final match = MatchedSelection(matched: {'d1': files}, unmatched: const []);
    notifier.setFiles(files, match: match);
    final state = container.read(filesTabNotifierProvider);
    expect(state.files, files);
    expect(state.match, match);
    container.dispose();
  });

  test('setExtractionProgress reflects done/total', () {
    final container = ProviderContainer();
    final notifier = container.read(filesTabNotifierProvider.notifier);
    notifier.setExtractionProgress(done: 3, total: 10);
    final state = container.read(filesTabNotifierProvider);
    expect(state.extractedCount, 3);
    expect(state.totalToExtract, 10);
    expect(state.isExtracting, isTrue);
    notifier.setExtractionProgress(done: 10, total: 10);
    final done = container.read(filesTabNotifierProvider);
    expect(done.isExtracting, isFalse); // done == total
    container.dispose();
  });

  test('removeFile filters by sourcePath', () {
    final container = ProviderContainer();
    final notifier = container.read(filesTabNotifierProvider.notifier);
    final a = _ef('/a.jpg');
    final b = _ef('/b.jpg');
    notifier.setFiles([
      a,
      b,
    ], match: const MatchedSelection(matched: {}, unmatched: []));
    notifier.removeFile('/a.jpg');
    final state = container.read(filesTabNotifierProvider);
    expect(state.files, [b]);
    container.dispose();
  });
}
