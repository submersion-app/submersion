import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Media and document tags on Manage Tags (#1970) in every locale. Each new
/// string names media or documents in the locale's own word, so a key left
/// in English (gen-l10n falls back to it silently) fails here.
/// arb_parity_test only checks that the key exists.
void main() {
  /// The word, or stem, each locale uses for media.
  const mediaWord = {
    'ar': 'وسائط',
    'de': 'medi',
    'es': 'multimedia',
    'fr': 'média',
    'he': 'מדיה',
    'hu': 'médi',
    'it': 'media',
    'nl': 'media',
    'pt': 'mídia',
    'zh': '媒体',
  };

  /// The word, or stem, each locale uses for documents.
  const documentWord = {
    'ar': 'مستند',
    'de': 'dokument',
    'es': 'documento',
    'fr': 'document',
    'he': 'מסמ',
    'hu': 'dokument',
    'it': 'document',
    'nl': 'document',
    'pt': 'documento',
    'zh': '文档',
  };

  List<String> mediaStrings(AppLocalizations l) => [
    l.tags_manage_scope_media,
    l.tags_manage_useForMedia,
    l.tags_manage_scopeRequired,
    l.tags_manage_mediaCount(5),
    l.tags_manage_narrowDialog_media(5),
    l.tags_manage_deleteMessage_media('X', 5),
    l.tags_manage_bulkDeleteMessage_media(5),
    l.tags_manage_mergeAffected_media(5),
  ];

  List<String> documentStrings(AppLocalizations l) => [
    l.tags_manage_scope_documents,
    l.tags_manage_useForDocuments,
    l.tags_manage_scopeRequired,
    l.tags_manage_documentCount(5),
    l.tags_manage_narrowDialog_documents(5),
    l.tags_manage_deleteMessage_documents('X', 5),
    l.tags_manage_bulkDeleteMessage_documents(5),
    l.tags_manage_mergeAffected_documents(5),
  ];

  List<String> missing(List<String> strings, String word) => [
    for (final s in strings)
      if (!s.toLowerCase().contains(word)) s,
  ];

  for (final code in mediaWord.keys) {
    test('$code names media and documents in every scope string', () {
      final l = lookupAppLocalizations(Locale(code));
      expect(missing(mediaStrings(l), mediaWord[code]!), isEmpty);
      expect(missing(documentStrings(l), documentWord[code]!), isEmpty);
    });
  }

  test('Arabic counts media items and documents in every plural category', () {
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(ar.tags_manage_mediaCount(1), 'عنصر وسائط واحد');
    expect(ar.tags_manage_mediaCount(2), 'عنصرا وسائط');
    expect(ar.tags_manage_mediaCount(3), '3 عناصر وسائط');
    expect(ar.tags_manage_mediaCount(11), '11 عنصر وسائط');
    expect(ar.tags_manage_documentCount(1), 'مستند واحد');
    expect(ar.tags_manage_documentCount(2), 'مستندان');
    expect(ar.tags_manage_documentCount(3), '3 مستندات');
    expect(ar.tags_manage_documentCount(11), '11 مستندًا');
  });

  test('the shared bulk tag strings name no kind of item (#1970 review)', () {
    // Shared by the media and equipment bulk editors, so none may say
    // "equipment" in any locale.
    const equipmentWord = {
      'ar': 'معد',
      'de': 'ausrüst',
      'en': 'equipment',
      'es': 'equipo',
      'fr': 'équipement',
      'he': 'ציוד',
      'hu': 'felszerel',
      'it': 'attrezzatur',
      'nl': 'uitrust',
      'pt': 'equipament',
      'zh': '装备',
    };
    for (final MapEntry(key: code, value: word) in equipmentWord.entries) {
      final l = lookupAppLocalizations(Locale(code));
      final strings = [
        l.tags_bulk_title(3),
        l.tags_bulk_onAll(3),
        l.tags_bulk_onSome(1, 3),
        l.tags_bulk_adding(3),
        l.tags_bulk_removing,
        l.tags_bulk_applied(3),
        l.tags_bulk_tagsLabel,
        l.tags_bulk_confirmTitle,
        l.tags_bulk_undo,
        l.tags_bulk_undoFailed,
        l.tags_bulk_failed('x'),
      ];
      expect(
        [
          for (final s in strings)
            if (s.toLowerCase().contains(word)) s,
        ],
        isEmpty,
        reason: code,
      );
    }
  });
}
