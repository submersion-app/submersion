import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_importer.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';

/// An importer whose run ends when the test says, with the outcome it
/// says, or by throwing.
class _GatedImporter implements SiteCatalogueImporter {
  final gate = Completer<SiteCatalogueImportOutcome>();

  @override
  Future<SiteCatalogueImportOutcome> importIfChanged() => gate.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  (ProviderContainer, _GatedImporter) container() {
    final importer = _GatedImporter();
    final container = ProviderContainer(
      overrides: [siteCatalogueImporterProvider.overrideWithValue(importer)],
    );
    addTearDown(container.dispose);
    return (container, importer);
  }

  test('nothing is being imported until an import starts', () {
    final (c, _) = container();
    expect(c.read(siteCatalogueImportingProvider), isFalse);
  });

  test('true while the import runs, false once it has landed, and the '
      'catalogue\'s readers are told', () async {
    final (c, importer) = container();

    final run = c.read(siteCatalogueImportProvider)();
    expect(c.read(siteCatalogueImportingProvider), isTrue);

    importer.gate.complete(SiteCatalogueImportOutcome.imported);
    await run;

    expect(c.read(siteCatalogueImportingProvider), isFalse);
    expect(c.read(siteCatalogueRevisionProvider), 1);
  });

  test('false again when the import fails', () async {
    final (c, importer) = container();

    final run = c.read(siteCatalogueImportProvider)();
    importer.gate.completeError(StateError('could not read the asset'));

    await expectLater(run, throwsStateError);
    expect(c.read(siteCatalogueImportingProvider), isFalse);
  });
}
