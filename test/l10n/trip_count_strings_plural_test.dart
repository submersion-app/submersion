import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Found alongside #2878: these trips strings were plain `{count} dives`
/// templates rather than plurals, so a one-day trip read "(1 days)", a trip
/// with one dive read "1 dives" on the trips list, and the dive scan offered
/// to "Add 1 Dives". Every locale now picks its own form for a count of one.
///
/// Each case is (one, three) for every shipped locale.
typedef _Cases = Map<String, (String, String)>;

void main() {
  Future<AppLocalizations> load(String languageCode) =>
      AppLocalizations.delegate.load(Locale(languageCode));

  final codes = AppLocalizations.supportedLocales
      .map((l) => l.languageCode)
      .toSet();

  void check(
    String key,
    String Function(AppLocalizations l10n, int count) render,
    _Cases expected,
  ) {
    group(key, () {
      test('covers every shipped locale', () {
        expect(expected.keys.toSet(), codes);
      });
      for (final MapEntry(key: code, value: (one, three)) in expected.entries) {
        test('$code agrees with its own count', () async {
          final l10n = await load(code);

          expect(render(l10n, 1), one);
          expect(render(l10n, 3), three);
        });
      }
    });
  }

  check('trips_detail_durationDays', (l, n) => l.trips_detail_durationDays(n), {
    'en': ('1 day', '3 days'),
    'ar': ('يوم واحد', '3 أيام'),
    'de': ('1 Tag', '3 Tage'),
    'es': ('1 día', '3 días'),
    'fr': ('1 jour', '3 jours'),
    'he': ('יום אחד', '3 ימים'),
    'hu': ('1 nap', '3 nap'),
    'it': ('1 giorno', '3 giorni'),
    'nl': ('1 dag', '3 dagen'),
    'pt': ('1 dia', '3 dias'),
    'zh': ('1 天', '3 天'),
  });

  const linkedPhotos = {
    'en': ('Linked 1 photo', 'Linked 3 photos'),
    'ar': ('تم ربط صورة واحدة', 'تم ربط 3 صور'),
    'de': ('1 Foto verknüpft', '3 Fotos verknüpft'),
    'es': ('Se vinculó 1 foto', 'Se vincularon 3 fotos'),
    'fr': ('1 photo associée', '3 photos associées'),
    'he': ('קושרה תמונה אחת', 'קושרו 3 תמונות'),
    'hu': ('1 fotó csatolva', '3 fotó csatolva'),
    'it': ('Collegata 1 foto', 'Collegate 3 foto'),
    'nl': ('1 foto gekoppeld', "3 foto's gekoppeld"),
    'pt': ('1 foto vinculada', '3 fotos vinculadas'),
    'zh': ('已关联 1 照片', '已关联 3 照片'),
  };
  check(
    'trips_detail_scan_linkedPhotos',
    (l, n) => l.trips_detail_scan_linkedPhotos(n),
    linkedPhotos,
  );
  check(
    'trips_gallery_linkedPhotos',
    (l, n) => l.trips_gallery_linkedPhotos(n),
    linkedPhotos,
  );

  check('trips_diveScan_addButton', (l, n) => l.trips_diveScan_addButton(n), {
    'en': ('Add 1 Dive', 'Add 3 Dives'),
    'ar': ('إضافة غوصة واحدة', 'إضافة 3 غوصات'),
    'de': ('1 Tauchgang hinzufügen', '3 Tauchgänge hinzufügen'),
    'es': ('Agregar 1 inmersión', 'Agregar 3 inmersiones'),
    'fr': ('Ajouter 1 plongée', 'Ajouter 3 plongées'),
    'he': ('הוסף צלילה אחת', 'הוסף 3 צלילות'),
    'hu': ('1 merülés hozzáadása', '3 merülés hozzáadása'),
    'it': ('Aggiungi 1 immersione', 'Aggiungi 3 immersioni'),
    'nl': ('1 duik toevoegen', '3 duiken toevoegen'),
    'pt': ('Adicionar 1 mergulho', 'Adicionar 3 mergulhos'),
    'zh': ('添加 1 潜水', '添加 3 潜水'),
  });

  check('trips_diveScan_added', (l, n) => l.trips_diveScan_added(n), {
    'en': ('Added 1 dive to trip', 'Added 3 dives to trip'),
    'ar': ('تمت إضافة غوصة واحدة إلى الرحلة', 'تمت إضافة 3 غوصات إلى الرحلة'),
    'de': (
      '1 Tauchgang zur Reise hinzugefügt',
      '3 Tauchgänge zur Reise hinzugefügt',
    ),
    'es': (
      'Se agregó 1 inmersión al viaje',
      'Se agregaron 3 inmersiones al viaje',
    ),
    'fr': ('1 plongée ajoutée au voyage', '3 plongées ajoutées au voyage'),
    'he': ('נוספה צלילה אחת לטיול', 'נוספו 3 צלילות לטיול'),
    'hu': ('1 merülés hozzáadva az úthoz', '3 merülés hozzáadva az úthoz'),
    'it': (
      '1 immersione aggiunta al viaggio',
      '3 immersioni aggiunte al viaggio',
    ),
    'nl': ('1 duik toegevoegd aan reis', '3 duiken toegevoegd aan reis'),
    'pt': (
      '1 mergulho adicionado à viagem',
      '3 mergulhos adicionados à viagem',
    ),
    'zh': ('已将 1 次潜水添加到旅行', '已将 3 次潜水添加到旅行'),
  });

  check('trips_diveScan_subtitle', (l, n) => l.trips_diveScan_subtitle(n), {
    'en': ('1 dive found in date range', '3 dives found in date range'),
    'ar': (
      'تم العثور على غوصة واحدة في نطاق التاريخ',
      'تم العثور على 3 غوصات في نطاق التاريخ',
    ),
    'de': (
      '1 Tauchgang im Datumsbereich gefunden',
      '3 Tauchgänge im Datumsbereich gefunden',
    ),
    'es': (
      '1 inmersión encontrada en el rango de fechas',
      '3 inmersiones encontradas en el rango de fechas',
    ),
    'fr': (
      '1 plongée trouvée dans la plage de dates',
      '3 plongées trouvées dans la plage de dates',
    ),
    'he': ('נמצאה צלילה אחת בטווח התאריכים', 'נמצאו 3 צלילות בטווח התאריכים'),
    'hu': (
      '1 merülés található a dátumtartományban',
      '3 merülés található a dátumtartományban',
    ),
    'it': (
      "1 immersione trovata nell'intervallo di date",
      "3 immersioni trovate nell'intervallo di date",
    ),
    'nl': (
      '1 duik gevonden in het datumbereik',
      '3 duiken gevonden in het datumbereik',
    ),
    'pt': (
      '1 mergulho encontrado no intervalo de datas',
      '3 mergulhos encontrados no intervalo de datas',
    ),
    'zh': ('在日期范围内找到 1 次潜水', '在日期范围内找到 3 次潜水'),
  });

  check('trips_list_tile_diveCount', (l, n) => l.trips_list_tile_diveCount(n), {
    'en': ('1 dive', '3 dives'),
    'ar': ('غوصة واحدة', '3 غوصات'),
    'de': ('1 Tauchgang', '3 Tauchgänge'),
    'es': ('1 inmersión', '3 inmersiones'),
    'fr': ('1 plongée', '3 plongées'),
    'he': ('צלילה אחת', '3 צלילות'),
    'hu': ('1 merülés', '3 merülés'),
    'it': ('1 immersione', '3 immersioni'),
    'nl': ('1 duik', '3 duiken'),
    'pt': ('1 mergulho', '3 mergulhos'),
    'zh': ('1 次潜水', '3 次潜水'),
  });

  check(
    'trips_photos_moreIndicator_semanticLabel',
    (l, n) => l.trips_photos_moreIndicator_semanticLabel(n),
    {
      'en': ('1 more photo', '3 more photos'),
      'ar': ('صورة إضافية واحدة', '3 صور إضافية'),
      'de': ('1 weiteres Foto', '3 weitere Fotos'),
      'es': ('1 foto más', '3 fotos más'),
      'fr': ('1 photo supplémentaire', '3 photos supplémentaires'),
      'he': ('עוד תמונה אחת', 'עוד 3 תמונות'),
      'hu': ('1 további fotó', '3 további fotó'),
      'it': ("Un'altra foto", 'Altre 3 foto'),
      'nl': ('1 meer foto', "3 meer foto's"),
      'pt': ('1 foto a mais', '3 fotos a mais'),
      'zh': ('1 更多照片', '3 更多照片'),
    },
  );
}
