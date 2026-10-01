import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_share_sheet.dart';

void main() {
  test('names the image after the certification, in its own case', () {
    expect(
      certificationImageFileName('PADI Open Water Diver', 'card'),
      'certification_PADI_Open_Water_Diver_card.png',
    );
    expect(
      certificationImageFileName('SSI Nitrox', 'certificate'),
      'certification_SSI_Nitrox_certificate.png',
    );
  });

  test('keeps a title in any script', () {
    expect(
      certificationImageFileName('CMAS Plongeur ★★ Élite', 'card'),
      'certification_CMAS_Plongeur_Élite_card.png',
    );
    expect(
      certificationImageFileName('潜水员 一星', 'card'),
      'certification_潜水员_一星_card.png',
    );
  });

  test('drops a title with nothing usable in it', () {
    expect(certificationImageFileName('', 'card'), 'certification_card.png');
  });
}
