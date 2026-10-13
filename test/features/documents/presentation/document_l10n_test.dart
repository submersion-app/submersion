import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('every type and owner kind has a label and an icon', () {
    for (final t in DocumentType.values) {
      expect(documentTypeLabel(l10n, t), isNotEmpty);
      expect(documentTypeIcon(t), isNotNull);
    }
    for (final k in DocumentOwnerKind.values) {
      expect(documentOwnerKindLabel(l10n, k), isNotEmpty);
    }
    expect(
      documentTypeLabel(l10n, DocumentType.medicalClearance),
      'Medical clearance',
    );
    expect(
      documentOwnerKindLabel(l10n, DocumentOwnerKind.diveCenter),
      'Dive centers',
    );
  });

  test('an empty or blank title shows the type name', () {
    Document doc(String title) => Document(
      id: 'x',
      diverId: 'd',
      owner: const DocumentOwner.personal(),
      type: DocumentType.permit,
      title: title,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(documentDisplayTitle(l10n, doc('')), 'Permit');
    expect(documentDisplayTitle(l10n, doc('  ')), 'Permit');
    expect(documentDisplayTitle(l10n, doc('Marine park')), 'Marine park');
  });

  test('a certification card is titled by its certification', () {
    final card = Document(
      id: 'x',
      diverId: 'd',
      owner: const DocumentOwner(DocumentOwnerKind.certification, 'c1'),
      type: DocumentType.certificationCard,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(
      documentDisplayTitle(l10n, card, ownerLabel: 'Advanced Nitrox'),
      'Advanced Nitrox',
    );
    // No certification name to hand: the type name, as before.
    expect(documentDisplayTitle(l10n, card), 'Certification card');
    expect(
      documentDisplayTitle(l10n, card, ownerLabel: ' '),
      'Certification card',
    );
    // Any other document keeps its own title.
    final permit = card.copyWith(
      type: DocumentType.permit,
      title: 'Marine park',
      owner: const DocumentOwner(DocumentOwnerKind.trip, 't1'),
    );
    expect(
      documentDisplayTitle(l10n, permit, ownerLabel: 'Bonaire'),
      'Marine park',
    );
  });
}
